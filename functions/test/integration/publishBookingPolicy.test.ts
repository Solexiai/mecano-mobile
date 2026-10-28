// PAY-12 (2026-10-27) — publication des conditions de réservation finales :
// validation serveur, version obligatoire au changement de texte, audit.
import { db } from '../../src/lib/admin';
import { publishBookingPolicy } from '../../src/functions/publishBookingPolicy';
import { adminPilotSetup } from '../../src/functions/adminPilotSetup';
import { getBookingPolicy } from '../../src/lib/bookingServer';
import { TRIAL_POLICY_VERSION } from '../../src/config/trialBookingPolicy';

const call = (data: unknown, uid = 'policy_staff', roles = ['admin']) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const content = (text: string) => ({ fr: text, en: `${text} (en)` });
function draft(version = '2026-11-01-1', text = 'Texte final relu.') {
  return {
    version,
    approval_reference: 'Relecture juridique du 2026-11-01',
    setup_enabled: true,
    cancellation_text: content(`Annulation : ${text}`),
    payment_text: content(`Paiement : ${text}`),
    documents: {
      booking: { version: `${version}-reservation`, url: 'https://movi-k.com/fr/legal/cancellation', content: content(text) },
      terms: { version: `${version}-cgu`, url: 'https://movi-k.com/fr/legal/terms', content: content(text) },
      privacy: { version: `${version}-vie-privee`, url: 'https://movi-k.com/fr/legal/privacy', content: content(text) },
    },
  };
}

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const c of ['system_config', 'audit_logs']) await db.recursiveDelete(db.collection(c));
});

test('admins only', async () => {
  await expect(publishBookingPolicy.run(call({ action: 'get' }, 'someone', ['customer'])))
    .rejects.toMatchObject({ code: 'permission-denied' });
  await expect(publishBookingPolicy.run(call({ action: 'publish', policy: draft() }, 'driver_1', ['driver'])))
    .rejects.toMatchObject({ code: 'permission-denied' });
});

test('get : rien de publié -> point de départ = version d\'essai, marquée comme telle', async () => {
  const state = (await publishBookingPolicy.run(call({ action: 'get' }))) as any;
  expect(state.published).toBeNull();
  expect(state.starter).toMatchObject({ version: TRIAL_POLICY_VERSION, trial: true });
  expect(state.starter.documents.booking.content.fr).toContain("VERSION D'ESSAI");
});

test('preview et publish refusent un projet incomplet, sans rien écrire', async () => {
  const incomplete = { ...draft(), documents: { ...draft().documents, privacy: undefined } };
  await expect(publishBookingPolicy.run(call({ action: 'preview', policy: incomplete })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(publishBookingPolicy.run(call({ action: 'publish', policy: { ...draft(), version: 'mauvaise version !' } })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  const http = draft(); http.documents.terms.url = 'http://movi-k.com/fr/legal/terms';
  await expect(publishBookingPolicy.run(call({ action: 'publish', policy: http })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  expect(await getBookingPolicy()).toBeNull();
});

test('publish : politique finale valide, jamais marquée essai, journalisée, puis essai refusé par-dessus', async () => {
  await adminPilotSetup.run(call({ action: 'publishTrialTerms' }));
  expect((await getBookingPolicy())!.version).toBe(TRIAL_POLICY_VERSION);

  const preview = (await publishBookingPolicy.run(call({ action: 'preview', policy: draft() }))) as any;
  expect(preview).toMatchObject({ valid: true, version: '2026-11-01-1' });

  const result = await publishBookingPolicy.run(call({ action: 'publish', policy: draft() }));
  expect(result).toMatchObject({ success: true, version: '2026-11-01-1', unchanged: false, contract_hash: preview.contract_hash });

  const policy = await getBookingPolicy();
  expect(policy).toMatchObject({ version: '2026-11-01-1', approved: true, schema_version: 2, setup_enabled: true });
  const raw = (await db.doc('system_config/booking_policy').get()).data()!;
  expect(raw.trial).toBe(false);
  expect(raw.published_by_user_id).toBe('policy_staff');
  expect(raw.published_at).toBeTruthy();

  const state = (await publishBookingPolicy.run(call({ action: 'get' }))) as any;
  expect(state.published).toMatchObject({ version: '2026-11-01-1', trial: false });

  // La version d'essai ne remplace jamais des conditions approuvées.
  await expect(adminPilotSetup.run(call({ action: 'publishTrialTerms' })))
    .rejects.toMatchObject({ code: 'failed-precondition' });

  const audits = await db.collection('audit_logs').where('action', '==', 'booking_policy_published').get();
  expect(audits.size).toBe(1);
  expect(audits.docs[0].data().metadata).toMatchObject({
    version: '2026-11-01-1', previousVersion: TRIAL_POLICY_VERSION, previousWasTrial: true,
  });
});

test('un texte modifié exige une nouvelle version ; un texte identique ne republie rien', async () => {
  await publishBookingPolicy.run(call({ action: 'publish', policy: draft() }));
  await expect(publishBookingPolicy.run(call({ action: 'publish', policy: draft('2026-11-01-1', 'Texte changé.') })))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await getBookingPolicy())!.documents.booking.content.fr).toBe('Texte final relu.');

  expect(await publishBookingPolicy.run(call({ action: 'publish', policy: draft() })))
    .toMatchObject({ success: true, unchanged: true });

  expect(await publishBookingPolicy.run(call({ action: 'publish', policy: draft('2026-11-02-1', 'Texte changé.') })))
    .toMatchObject({ success: true, version: '2026-11-02-1', unchanged: false });
  expect((await getBookingPolicy())!.documents.booking.content.fr).toBe('Texte changé.');
  const audits = await db.collection('audit_logs').where('action', '==', 'booking_policy_published').get();
  expect(audits.size).toBe(2);
});
