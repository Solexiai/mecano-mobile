/** Preparation only. Does not authorize a quote, vehicle fit or assignment.
 * AI suggestions are untrusted; the customer must confirm the object.
 * Measurements are never inferred or fabricated by this policy.
 */
export const PHOTO_CATEGORIES = ['sofa','armchair','fridge','washer','table','tv','boxes','materials','other'] as const;
export type PhotoCategory = typeof PHOTO_CATEGORIES[number];
export type IntakeResult = {
  category: PhotoCategory | null;
  status: 'confirm_object' | 'confirm_category' | 'standard' | 'special';
  measurementsRequired: boolean;
  requiredDetails: string[];
  quoteAuthorized: false;
  vehicleFitVerified: false;
};
export function classifyPhotoIntake(input: {
  category: unknown;
  customerConfirmed: boolean;
  specialItem: boolean;
}): IntakeResult {
  const category = typeof input.category === 'string' &&
    (PHOTO_CATEGORIES as readonly string[]).includes(input.category)
    ? input.category as PhotoCategory : null;
  const base = { category, measurementsRequired: false, requiredDetails: [] as string[],
    quoteAuthorized: false as const, vehicleFitVerified: false as const };
  if (!category) return { ...base, status: 'confirm_category' };
  if (input.customerConfirmed !== true) return { ...base, status: 'confirm_object' };
  // Owner decision 2026-10-25: the customer never has to type measurements.
  // A confirmed photo, its type (including "other") and the quantity are
  // enough; the driver judges the fit from the photos and the AI's advisory
  // size range. A special item stays flagged for the driver without
  // blocking the booking.
  if (category === 'materials' || input.specialItem === true) {
    return { ...base, status: 'special' };
  }
  return { ...base, status: 'standard' };
}
