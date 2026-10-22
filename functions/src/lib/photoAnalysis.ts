import { PHOTO_CATEGORIES, PhotoCategory } from './photoIntake';

export const PHOTO_ANALYSIS_VERSION = 'photo-identification-v2';
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
export type PhotoSizeEstimate = {
 basis: 'typical_object' | 'visible_reference'; confidence: 'low' | 'medium';
 length_cm: {min:number;max:number}; width_cm: {min:number;max:number}; height_cm: {min:number;max:number};
};
export function parsePhotoSizeEstimate(value: unknown): PhotoSizeEstimate | null {
 if (value === null) return null;
 if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PhotoAnalysisError('unavailable');
 const v=value as Record<string,any>;
 if (Object.keys(v).sort().join(',') !== 'basis,confidence,height_cm,length_cm,width_cm' ||
     !['typical_object','visible_reference'].includes(v.basis) || !['low','medium'].includes(v.confidence) ||
     (v.basis === 'typical_object' && v.confidence !== 'low')) throw new PhotoAnalysisError('unavailable');
 for (const key of ['length_cm','width_cm','height_cm']) {
  const range=v[key];
  if (!range || Object.keys(range).sort().join(',') !== 'max,min' ||
      !Number.isSafeInteger(range.min) || !Number.isSafeInteger(range.max) ||
      range.min < 1 || range.max > 2000 || range.min >= range.max) throw new PhotoAnalysisError('unavailable');
 }
 return {basis:v.basis,confidence:v.confidence,length_cm:{...v.length_cm},width_cm:{...v.width_cm},height_cm:{...v.height_cm}};
}
export type PhotoSuggestion = {
  category: PhotoCategory; label: string; confidence: 'low' | 'medium' | 'high';
  special_handling: boolean; reason: 'ordinary' | 'special' | 'uncertain' | 'multiple_objects';
  size_estimate?: PhotoSizeEstimate | null;
};
export class PhotoAnalysisError extends Error {
  constructor(public readonly code: 'invalid-argument' | 'permission-denied' | 'failed-precondition' | 'resource-exhausted' | 'unavailable') {
    super('Photo analysis unavailable.');
  }
}
export function parsePhotoSuggestion(value: unknown): PhotoSuggestion {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PhotoAnalysisError('unavailable');
  const v = value as Record<string, unknown>;
  if (Object.keys(v).filter(k => k !== 'size_estimate').sort().join(',') !== 'category,confidence,label,reason,special_handling' ||
      !(PHOTO_CATEGORIES as readonly unknown[]).includes(v.category) ||
      typeof v.label !== 'string' || !v.label.trim() || v.label.length > 160 ||
      [...v.label].some(c => c.charCodeAt(0) < 32 || c === '<' || c === '>') ||
      !['low', 'medium', 'high'].includes(v.confidence as string) ||
      typeof v.special_handling !== 'boolean' ||
      !['ordinary', 'special', 'uncertain', 'multiple_objects'].includes(v.reason as string)) {
    throw new PhotoAnalysisError('unavailable');
  }
  // Ambiguity never silently becomes an ordinary object eligible for a quote.
  const uncertain = v.confidence === 'low' || ['uncertain', 'multiple_objects'].includes(v.reason as string);
  const category = uncertain ? 'other' : v.category as PhotoCategory;
  const estimate = v.size_estimate === undefined ? undefined : parsePhotoSizeEstimate(v.size_estimate);
  return { ...(estimate === undefined ? {} : {size_estimate:uncertain ? null : estimate}), category, label: v.label.trim(), confidence: v.confidence as PhotoSuggestion['confidence'],
    special_handling: v.special_handling || category === 'materials' || category === 'other' || v.reason === 'special',
    reason: uncertain ? (v.reason === 'multiple_objects' ? 'multiple_objects' : 'uncertain') : v.reason as PhotoSuggestion['reason'] };
}
export type PhotoRequest = { draftId: string; itemId: string; photoPath: string; locale: 'fr' | 'en' | 'es' };
export function parsePhotoRequest(uid: string, value: unknown): PhotoRequest {
  const v = value as Record<string, unknown> | null;
  if (!v || v.consent !== true || typeof v.draftId !== 'string' || !/^[a-zA-Z0-9_-]{8,80}$/.test(v.draftId) ||
      typeof v.itemId !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(v.itemId) ||
      !['fr', 'en', 'es'].includes(v.locale as string) || typeof v.photoPath !== 'string' ||
      ![0, 1, 2].some(slot => v.photoPath === `booking_photos/${uid}/${v.draftId}/${v.itemId}/${slot}.jpg`)) {
    throw new PhotoAnalysisError('invalid-argument');
  }
  return {draftId:v.draftId, itemId:v.itemId, photoPath:v.photoPath, locale:v.locale as PhotoRequest['locale']};
}
export function assertPhotoDraft(uid: string, request: PhotoRequest, draft: Record<string, any> | undefined, now: number): void {
  if (!draft || draft.owner_uid !== uid || draft.draft_id !== request.draftId ||
      typeof draft.expires_at?.toMillis !== 'function' || !(draft.expires_at.toMillis() > now) ||
      draft.draft?.intake_mode !== 'photo_assisted' ||
      !Array.isArray(draft.draft?.items) || !draft.draft.items.some((item: any) =>
        item.id === request.itemId && Array.isArray(item.photos) && item.photos.includes(request.photoPath))) {
    throw new PhotoAnalysisError('permission-denied');
  }
}
export function assertPhotoBytes(bytes: Buffer): void {
  if (bytes.length < 3 || bytes.length > MAX_PHOTO_BYTES || bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255) {
    throw new PhotoAnalysisError('invalid-argument');
  }
}
export type PhotoAnalysisConfig = { enabled: true; model: string; userDailyLimit: number; globalDailyLimit: number };
export function photoAnalysisConfig(raw: Record<string, any> | undefined, uid: string): PhotoAnalysisConfig {
  if (raw?.enabled !== true || raw.provider !== 'openai' || typeof raw.model !== 'string' ||
      !/^[a-zA-Z0-9._:-]{1,100}$/.test(raw.model) || !Array.isArray(raw.allowedUserUids) ||
      (raw.allowAuthenticatedUsers !== true && !raw.allowedUserUids.includes(uid)) || !Number.isSafeInteger(raw.userDailyLimit) ||
      raw.userDailyLimit < 1 || raw.userDailyLimit > 100 || !Number.isSafeInteger(raw.globalDailyLimit) ||
      raw.globalDailyLimit < 1 || raw.globalDailyLimit > 10000) throw new PhotoAnalysisError('failed-precondition');
  return {enabled:true,model:raw.model,userDailyLimit:raw.userDailyLimit,globalDailyLimit:raw.globalDailyLimit};
}
export function checkPhotoQuota(user: Record<string, any>, global: Record<string, any>, config: PhotoAnalysisConfig, now: number): void {
  const valid = (n: unknown) => n === undefined || (Number.isSafeInteger(n) && (n as number) >= 0);
  if (!valid(user.count) || !valid(global.count) || (user.count ?? 0) >= config.userDailyLimit ||
      (global.count ?? 0) >= config.globalDailyLimit || (user.busyUntil ?? 0) > now) {
    throw new PhotoAnalysisError('resource-exhausted');
  }
}
