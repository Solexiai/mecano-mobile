import { createHash, randomUUID } from 'crypto';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { admin, db } from '../lib/admin';
import { requireSignedIn } from '../lib/auth';
import { analyzeWithOpenAi } from '../lib/openAiPhotoAnalyzer';
import { assertPhotoBytes, assertPhotoDraft, checkPhotoQuota, MAX_PHOTO_BYTES,
  parsePhotoRequest, photoAnalysisConfig, PhotoAnalysisError, PHOTO_ANALYSIS_VERSION } from '../lib/photoAnalysis';

const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
export async function handleAnalyzeBookingPhoto(request: CallableRequest): Promise<Record<string, unknown>> {
  const { uid } = requireSignedIn(request);
  const now = Date.now(), day = new Date(now).toISOString().slice(0,10);
  const userRef = db.doc(`photo_analysis_usage/${createHash('sha256').update(uid).digest('hex')}`);
  const globalRef = db.doc(`photo_analysis_usage/global_${day}`);
  const token = randomUUID();
  let claimed = false;
  try {
    const input = parsePhotoRequest(uid, request.data);
    const config = photoAnalysisConfig((await db.doc('system_config/photo_analysis').get()).data(), uid);
    const apiKey = OPENAI_API_KEY.value();
    if (!apiKey) throw new PhotoAnalysisError('failed-precondition');
    const draftRef = db.doc(`booking_drafts/${uid}`);
    assertPhotoDraft(uid, input, (await draftRef.get()).data(), now);
    const bucket = admin.storage().bucket();
    const file = bucket.file(input.photoPath);
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size);
    if (metadata.contentType !== 'image/jpeg' || !Number.isSafeInteger(size) || size < 3 ||
        size > MAX_PHOTO_BYTES || !metadata.generation) throw new PhotoAnalysisError('invalid-argument');
    // Pin the immutable image generation checked above; never fetch a client URL.
    const [bytes] = await bucket.file(input.photoPath, {generation:metadata.generation})
      .download({start:0,end:MAX_PHOTO_BYTES});
    assertPhotoBytes(bytes);
    await db.runTransaction(async tx => {
      const [draft, user, global] = await Promise.all([tx.get(draftRef),tx.get(userRef),tx.get(globalRef)]);
      assertPhotoDraft(uid, input, draft.data(), Date.now());
      const u = user.data() ?? {}, g = global.data() ?? {};
      const today = {...u,count:u.day === day ? u.count : 0};
      checkPhotoQuota(today, g, config, Date.now());
      tx.set(userRef, {day,count:(today.count ?? 0)+1,busyUntil:Date.now()+90000,token});
      tx.set(globalRef, {day,count:(g.count ?? 0)+1});
    });
    claimed = true;
    const suggestion = await analyzeWithOpenAi({bytes,locale:input.locale,model:config.model,apiKey});
    // A replaced or expired draft cannot receive a late response.
    assertPhotoDraft(uid, input, (await draftRef.get()).data(), Date.now());
    return {suggestion,photoPath:input.photoPath,version:PHOTO_ANALYSIS_VERSION,
      requiresConfirmation:true,measurementsVerified:false,quoteAuthorized:false};
  } catch (e) {
    if (e instanceof PhotoAnalysisError) throw new HttpsError(e.code,'Photo analysis unavailable.');
    throw new HttpsError('unavailable','Photo analysis unavailable.');
  } finally {
    if (claimed) {
      // Failure still consumes the reserved attempt; no free retry loop.
      try {
        await db.runTransaction(async tx => {
          const current = (await tx.get(userRef)).data();
          if (current?.token === token) tx.update(userRef,{busyUntil:0,token:null});
        });
      } catch (_) { /* Lease expires; never release another request's lock. */ }
    }
  }
}
export const analyzeBookingPhoto = onCall(
  {secrets:[OPENAI_API_KEY],timeoutSeconds:60,maxInstances:2,concurrency:4},
  handleAnalyzeBookingPhoto,
);
