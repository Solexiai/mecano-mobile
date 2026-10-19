import { admin } from './admin';
import { BookingLoad } from './booking';
import { failedPrecondition, invalidArgument } from './errors';

/** Only owned immutable uploads, never a public URL or an arbitrary Storage path. */
export async function validateBookingPhotos(load: BookingLoad, uid: string): Promise<void> {
  if (load.intake_mode !== 'photo_assisted') return;
  const paths: string[] = [];
  for (const item of load.items) {
    const allowed = new Set([0,1,2].map(slot => `booking_photos/${uid}/${load.draft_id}/${item.id}/${slot}.jpg`));
    if (item.photos.some(path => !allowed.has(path)) || new Set(item.photos).size !== item.photos.length) {
      throw invalidArgument('Photo inaccessible pour cet objet.');
    }
    paths.push(...item.photos);
  }
  if (!paths.length) return; // The review returns photo_required.
  const bucket = admin.storage().bucket();
  // Bound parallel metadata reads. Existing Storage rules forbid image replacement.
  for (let i=0;i<paths.length;i+=6) {
    await Promise.all(paths.slice(i,i+6).map(async path => {
      try {
        const [metadata] = await bucket.file(path).getMetadata();
        const size = Number(metadata.size);
        if (metadata.contentType !== 'image/jpeg' || !Number.isSafeInteger(size) ||
            size < 3 || size > 5*1024*1024 || !metadata.generation) throw Error('Invalid photo metadata');
      } catch (_) {
        throw failedPrecondition('Une photo est indisponible. Ajoutez une photo avant de demander le devis.');
      }
    }));
  }
}
