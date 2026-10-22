jest.mock('../../src/lib/bookingServer', () => ({ getBookingPolicy: jest.fn() }));
jest.mock('../../src/lib/runtimeFlags', () => ({
  RuntimeFlagKeys: { ACCEPT_NEW_DELIVERY_REQUESTS: 'booking', PAYMENTS_ENABLED: 'payment' },
  resolveRuntimeFlag: jest.fn(),
  isPilotUser: jest.fn(),
}));
import { getPublicBookingConfiguration } from '../../src/lib/bookingAvailability';
import { getBookingPolicy } from '../../src/lib/bookingServer';
import { isPilotUser, resolveRuntimeFlag } from '../../src/lib/runtimeFlags';

describe('read-only booking availability', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    (isPilotUser as jest.Mock).mockResolvedValue(false);
  });
  test.each([[true,true],[false,true],[true,false],[false,false]])(
    'independent booking=%s payment=%s', async (booking, payment) => {
      (getBookingPolicy as jest.Mock).mockResolvedValue({ approved: true, version: 'TEST' });
      (resolveRuntimeFlag as jest.Mock).mockImplementation((key) => Promise.resolve({
        enabled: key === 'booking' ? booking : payment, reason: 'document_found_valid',
      }));
      expect(await getPublicBookingConfiguration()).toEqual({
        policy: { approved: true, version: 'TEST' },
        availability: { booking_enabled: booking, payment_enabled: payment, technical_error: false },
      });
      expect(resolveRuntimeFlag).toHaveBeenCalledTimes(2);
    });
  test('a pilot account sees booking and payment open while the switches stay closed', async () => {
    (getBookingPolicy as jest.Mock).mockResolvedValue({ approved: true, version: 'TEST' });
    (resolveRuntimeFlag as jest.Mock).mockResolvedValue({ enabled: false, reason: 'document_found_valid' });
    (isPilotUser as jest.Mock).mockImplementation(async (uid) => uid === 'pilot');
    expect((await getPublicBookingConfiguration('pilot')).availability)
      .toEqual({ booking_enabled: true, payment_enabled: true, technical_error: false });
    expect((await getPublicBookingConfiguration('other')).availability)
      .toEqual({ booking_enabled: false, payment_enabled: false, technical_error: false });
  });
  test('missing policy is not a transport error', async () => {
    (getBookingPolicy as jest.Mock).mockResolvedValue(null);
    (resolveRuntimeFlag as jest.Mock).mockResolvedValue({ enabled: false, reason: 'document_missing' });
    expect((await getPublicBookingConfiguration()).availability.technical_error).toBe(false);
  });
  test('Firestore failure remains distinguishable and fail closed', async () => {
    (getBookingPolicy as jest.Mock).mockResolvedValue(null);
    (resolveRuntimeFlag as jest.Mock).mockResolvedValue({ enabled: false, reason: 'firestore_error' });
    expect((await getPublicBookingConfiguration()).availability).toEqual({
      booking_enabled: false, payment_enabled: false, technical_error: true,
    });
  });
  test('policy read failure is not converted into service closure', async () => {
    (getBookingPolicy as jest.Mock).mockRejectedValue(new Error('simulated'));
    (resolveRuntimeFlag as jest.Mock).mockResolvedValue({ enabled: false, reason: 'document_missing' });
    await expect(getPublicBookingConfiguration()).rejects.toThrow('simulated');
  });
});
