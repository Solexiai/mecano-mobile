// -----------------------------------------------------------------------------
// updateTaxConfiguration — Cloud Function callable (admin/super_admin).
//
// Point 14 de la directive 38 points (Bloc E) : « Créer une vraie gestion
// admin : updateTaxConfiguration avec contrôle admin/super-admin.
// Configuration versionnée : jurisdiction, tax_code, display_name, rate,
// taxable_components, effective_from, effective_until, enabled, version.
// Ne jamais écraser une configuration historique. »
//
// 🔒 RÈGLE CRITIQUE (identique en esprit à updatePricingConfiguration.ts) :
// chaque appel CRÉE un NOUVEAU document `tax_configs/{jurisdiction}_{tax_code}_v{N}`
// — jamais un overwrite d'une version existante. Un alias mutable
// `tax_configs/{jurisdiction}_{tax_code}_current` est mis à jour pour
// pointer vers la nouvelle version, permettant à `readActiveTaxConfigs()`
// de résoudre rapidement les configurations actives sans scanner tout
// l'historique.
//
// ⚠️ AUCUNE RÈGLE FISCALE INVENTÉE : cette fonction ne fixe AUCUN taux par
// défaut. Le `rate` est TOUJOURS fourni explicitement par l'appelant
// (admin/super_admin), après validation comptable/légale hors-code. Voir
// taxEngine.ts pour le mécanisme de calcul consommant ces configurations.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { TaxConfigDoc, TaxTypes, TaxType, TaxableComponent } from "../lib/types";

export interface UpdateTaxConfigurationRequest {
  jurisdiction: string; // ex: 'QC', 'ON', 'CA'
  taxCode: string; // ex: 'GST', 'QST', 'HST' — identifiant STABLE indépendant du taux
  taxType: TaxType; // catégorie technique (gst/qst/hst/other_tax/tax_exempt)
  displayName: string; // ex: "TPS (5%)"
  rate: number; // ex: 0.05 — DOIT être fourni explicitement, jamais déduit
  taxableComponents: TaxableComponent[]; // ex: ['transport','platform_fees']
  effectiveFromMillis: number;
  effectiveUntilMillis?: number | null;
  enabled: boolean;
  taxRegistrationOwner: "platform" | "driver" | "not_applicable";
}

function configDocId(jurisdiction: string, taxCode: string, version: number): string {
  return `${jurisdiction}_${taxCode}_v${version}`;
}

function currentAliasDocId(jurisdiction: string, taxCode: string): string {
  return `${jurisdiction}_${taxCode}_current`;
}

function assertValidRate(rate: unknown): void {
  if (typeof rate !== "number" || !Number.isFinite(rate) || rate < 0 || rate > 1) {
    throw invalidArgument("rate doit être un nombre compris entre 0 et 1 (ex: 0.05 pour 5%).");
  }
}

export const updateTaxConfiguration = onCall<UpdateTaxConfigurationRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const {
    jurisdiction,
    taxCode,
    taxType,
    displayName,
    rate,
    taxableComponents,
    effectiveFromMillis,
    effectiveUntilMillis,
    enabled,
    taxRegistrationOwner,
  } = request.data;

  if (!jurisdiction || typeof jurisdiction !== "string") {
    throw invalidArgument("jurisdiction est requis (ex: 'QC').");
  }
  if (!taxCode || typeof taxCode !== "string") {
    throw invalidArgument("taxCode est requis (ex: 'GST').");
  }
  if (!Object.values(TaxTypes).includes(taxType)) {
    throw invalidArgument(`taxType invalide: ${taxType}`);
  }
  if (!displayName || typeof displayName !== "string") {
    throw invalidArgument("displayName est requis.");
  }
  assertValidRate(rate);
  if (!Array.isArray(taxableComponents) || taxableComponents.length === 0) {
    throw invalidArgument("taxableComponents doit contenir au moins un élément.");
  }
  if (typeof effectiveFromMillis !== "number" || !Number.isFinite(effectiveFromMillis)) {
    throw invalidArgument("effectiveFromMillis est requis (timestamp ms).");
  }
  if (
    effectiveUntilMillis !== undefined &&
    effectiveUntilMillis !== null &&
    (typeof effectiveUntilMillis !== "number" || effectiveUntilMillis <= effectiveFromMillis)
  ) {
    throw invalidArgument("effectiveUntilMillis doit être > effectiveFromMillis si fourni.");
  }
  if (typeof enabled !== "boolean") {
    throw invalidArgument("enabled doit être un booléen.");
  }
  if (!["platform", "driver", "not_applicable"].includes(taxRegistrationOwner)) {
    throw invalidArgument("taxRegistrationOwner invalide.");
  }

  const aliasRef = db.collection("tax_configs").doc(currentAliasDocId(jurisdiction, taxCode));

  const result = await db.runTransaction(async (tx) => {
    // ---- Résolution du prochain numéro de version via l'alias mutable ----
    // 🔒 Ne JAMAIS écraser une configuration historique : le nouveau numéro
    // de version est déterminé en lisant l'alias `_current` (qui référence
    // le dernier `version` connu), jamais en scannant/devinant.
    const aliasSnap = await tx.get(aliasRef);
    const previousVersion = aliasSnap.exists
      ? (aliasSnap.data()!.latest_version as number)
      : 0;
    const newVersion = previousVersion + 1;

    const newConfigRef = db
      .collection("tax_configs")
      .doc(configDocId(jurisdiction, taxCode, newVersion));

    // Garde-fou : le doc versionné ne doit jamais déjà exister (protège même
    // contre une incohérence de l'alias — collision d'ID impossible en
    // fonctionnement normal, mais explicitement vérifiée par sécurité).
    const existingVersionSnap = await tx.get(newConfigRef);
    if (existingVersionSnap.exists) {
      throw failedPrecondition(
        `tax_configs/${newConfigRef.id} existe déjà — incohérence de version détectée, opération refusée.`
      );
    }

    const now = admin.firestore.Timestamp.now();
    const effectiveFrom = admin.firestore.Timestamp.fromMillis(effectiveFromMillis);
    const effectiveUntil =
      effectiveUntilMillis !== undefined && effectiveUntilMillis !== null
        ? admin.firestore.Timestamp.fromMillis(effectiveUntilMillis)
        : null;

    const newConfig: TaxConfigDoc = {
      jurisdiction,
      tax_code: taxCode,
      tax_type: taxType,
      display_name: displayName,
      rate,
      taxable_components: taxableComponents,
      applies_to_transport: taxableComponents.includes("transport"),
      applies_to_platform_fees: taxableComponents.includes("platform_fees"),
      effective_from: effectiveFrom,
      effective_until: effectiveUntil,
      enabled,
      version: newVersion,
      is_active: enabled,
      tax_registration_owner: taxRegistrationOwner,
      created_at: now,
      updated_at: now,
      updated_by_user_id: ctx.uid,
    };

    tx.set(newConfigRef, newConfig);

    tx.set(aliasRef, {
      is_alias: true,
      jurisdiction,
      tax_code: taxCode,
      latest_version: newVersion,
      latest_config_id: newConfigRef.id,
      updated_at: now,
      updated_by_user_id: ctx.uid,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "tax_configuration_changed",
      sourceFunction: "updateTaxConfiguration",
      targetId: newConfigRef.id,
      metadata: {
        jurisdiction,
        taxCode,
        previousVersion,
        newVersion,
        rate,
        enabled,
      },
    });

    return { configId: newConfigRef.id, version: newVersion };
  });

  return { success: true, ...result };
});
