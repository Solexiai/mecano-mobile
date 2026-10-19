const records: Record<string, Array<Record<string, unknown>>> = {
  users: [{roles:['customer']}],
  driver_profiles: [{status:'pending_review'}, {status:'documents_required'}, {status:'approved'}],
  delivery_requests: [{status:'searching_driver'}, {status:'offered'}, {status:'assigned'}, {status:'completed'}],
  disputes: ['opened','under_review','won','lost','reversed','closed'].map(status=>({status})),
  payments: [],
};
function query(name: string, match: (x: Record<string, unknown>) => boolean = () => true): any {
  return {
    where: (key: string, op: string, value: any) => query(name, x => match(x) && (op === 'in' ? value.includes(x[key]) : op === 'array-contains' ? (x[key] as any[]).includes(value) : x[key] === value)),
    count: () => ({get: async () => ({data: () => ({count: records[name].filter(match).length})})}),
    get: async () => ({docs: records[name].filter(match).map(x => ({data: () => x}))}),
  };
}
jest.mock('firebase-functions/v2/https', () => ({onCall: (handler: unknown) => handler}));
jest.mock('../../src/lib/admin', () => ({db: {collection: (name: string) => query(name)}}));
jest.mock('../../src/lib/auth', () => ({requireSignedIn: jest.fn(() => ({uid:'test'})), requireAnalystOrAbove: jest.fn()}));
import {getAdminDashboardMetrics} from '../../src/functions/getAdminDashboardMetrics';
import {requireAnalystOrAbove} from '../../src/lib/auth';
const invoke = () => (getAdminDashboardMetrics as any)({});
test('separates driver queues and counts only missions awaiting assignment', async () => {
  const data = await invoke();
  expect(data.pendingReviewDrivers).toBe(1);
  expect(data.documentsRequiredDrivers).toBe(1);
  expect(data.unassignedMissions).toBe(2);
  expect(data.pendingDrivers).toBe(2);
  expect(data.activeMissions).toBe(3);
});
test('terminal disputes are excluded from the open count', async () => {
  expect((await invoke()).openDisputes).toBe(2);
});
test('keeps the staff authorization gate', async () => {
  (requireAnalystOrAbove as jest.Mock).mockImplementationOnce(() => {throw new Error('denied');});
  await expect(invoke()).rejects.toThrow('denied');
});
