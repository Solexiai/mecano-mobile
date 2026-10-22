import { admin, db } from './admin';
import { failedPrecondition } from './errors';
import { calculateDriverCompensation, resolveCommission } from './pricingEngine';
import { ResolvedLockedQuote } from './quoteIntegrity';
import { CommissionConfigDoc, FoundingDriverQualificationDoc, FoundingDriverProgramDoc,
  FoundingDriverStatuses, PricingVersionDoc } from './types';

/** Shared read-only calculation. The existing acceptance rules are unchanged. */
export async function readDriverOfferCompensation(
  tx: FirebaseFirestore.Transaction, driverId: string, lockedQuote: ResolvedLockedQuote
) {
    const versionSnap = await tx.get(
      db.collection("pricing_versions").doc(lockedQuote.pricingVersion)
    );
    if (!versionSnap.exists) {
      throw failedPrecondition(`pricing_versions/${lockedQuote.pricingVersion} introuvable.`);
    }
    const pricingConfig = versionSnap.data() as PricingVersionDoc;
    const pricingResult = lockedQuote.pricingResult;

    // ---- Résolution de commission : Founding Driver > promo > standard ----
    // 🔒 BLOC O — CORRECTIF : on ne suppose JAMAIS un `programId` fixe
    // ("default" était une hypothèse ad-hoc jamais bootstrapée ailleurs dans
    // le projet — voir qualifyFoundingDriver.ts, qui accepte n'importe quel
    // `programId` fourni par l'admin). On cherche la qualification RÉELLE du
    // chauffeur via une requête collection-group sur `qualifications`
    // (indexée par `driver_id`, voir firestore.indexes.json), puis on charge
    // le VRAI programme référencé par `qualification.program_id`. L'absence
    // de qualification est un cas NORMAL (grande majorité des chauffeurs),
    // jamais une erreur.
    const qualQuerySnap = await tx.get(
      db.collectionGroup("qualifications").where("driver_id", "==", driverId).limit(1)
    );
    const promoSnap = await tx.get(
      db.collection("driver_promotions").where("driver_id", "==", driverId).limit(1)
    );

    let foundingQualificationForResolver: { status: string; promotionalPeriodEndsAtMillis: number } | null =
      null;
    let foundingProgramForResolver: { promotionalCommissionRate: number; preferredCommissionRate: number } | null =
      null;

    if (!qualQuerySnap.empty) {
      const qual = qualQuerySnap.docs[0].data() as FoundingDriverQualificationDoc;
      foundingQualificationForResolver = {
        status: qual.status,
        promotionalPeriodEndsAtMillis: qual.promotional_period_ends_at.toMillis(),
      };

      if (qual.status === FoundingDriverStatuses.QUALIFIED) {
        // 🔒 Une qualification 'qualified' DOIT référencer un programme réel
        // et cohérent — jamais un taux Founding inventé localement. Toute
        // incohérence (program_id manquant, programme introuvable, programme
        // désactivé, taux manquants/invalides) est une CORRUPTION DE
        // CONFIGURATION : on refuse explicitement le calcul (failed-precondition)
        // plutôt que de retomber silencieusement sur le taux standard (perte
        // injustifiée pour un chauffeur légitimement Founding) ou d'inventer
        // un taux local (remise commerciale silencieuse non auditée).
        if (!qual.program_id) {
          throw failedPrecondition(
            `Qualification Founding Driver de ${driverId} incohérente : program_id manquant.`
          );
        }
        const programSnap = await tx.get(
          db.collection("founding_driver_programs").doc(qual.program_id)
        );
        if (!programSnap.exists) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} introuvable (référencé par la qualification de ${driverId}).`
          );
        }
        const program = programSnap.data() as FoundingDriverProgramDoc;
        if (program.is_active === false) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} est désactivé — configuration Founding Driver incohérente pour ${driverId}.`
          );
        }
        if (
          typeof program.promotional_commission_rate !== "number" ||
          typeof program.preferred_commission_rate !== "number"
        ) {
          throw failedPrecondition(
            `founding_driver_programs/${qual.program_id} : taux de commission manquants ou invalides.`
          );
        }
        foundingProgramForResolver = {
          promotionalCommissionRate: program.promotional_commission_rate,
          preferredCommissionRate: program.preferred_commission_rate,
        };
      }
    }

    const now = admin.firestore.Timestamp.now();
    const resolved = resolveCommission({
      nowMillis: now.toMillis(),
      foundingQualification: foundingQualificationForResolver,
      foundingProgram: foundingProgramForResolver,
      activePromotion:
        !promoSnap.empty && promoSnap.docs[0].data().is_active
          ? {
              promotionalCommissionRate: promoSnap.docs[0].data().promotional_commission_rate,
              startsAtMillis: promoSnap.docs[0].data().starts_at.toMillis(),
              endsAtMillis: promoSnap.docs[0].data().ends_at.toMillis(),
              isActive: promoSnap.docs[0].data().is_active,
            }
          : null,
      standardRate: (pricingConfig.commission as CommissionConfigDoc).standard_commission_rate,
    });

    const compensation = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolved,
      commissionConfig: pricingConfig.commission,
    });


  return { pricingConfig, pricingResult, now, resolved, compensation };
}
