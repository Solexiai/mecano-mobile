// -----------------------------------------------------------------------------
// adminCustomerDeletion.ts — Admin › Utilisateurs (Daniel, 2026-11-10).
//
//   - deleteCustomerAccount (super-admin seulement) : effacer un client.
//     `dryRun: true` montre d'abord ce qui va se passer, sans rien toucher.
//     Client avec historique → ANONYMISÉ : compte de connexion, courriel,
//     téléphone, carnet d'adresses, notes internes, notifications, appareils,
//     brouillon et prix non réservés effacés ; livraisons, paiements et
//     écritures comptables gardés tels quels (preuves fiscales, 6 ans, visibles
//     par l'administration seulement). Client sans livraison ni paiement →
//     tout est effacé, photos de brouillon comprises.
//   - getMarketingOptIns (analyste et plus) : clients dont la dernière
//     réservation accepte « recevoir des offres ».
//
// Rien ici ne touche à Stripe, aux tarifs ni aux paiements. Chaque effacement
// est journalisé (audit_logs) avec la raison donnée.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { AuthContext, requireAnalystOrAbove, requireSignedIn, requireSuperAdmin } from "../lib/auth";
import {
  anonymizedUserDoc,
  deletionBlockers,
  deletionMode,
  latestMarketingOptIns,
} from "../lib/customerDeletion";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";

type Doc = Record<string, any>;

function roleOf(ctx: AuthContext): string {
  return ctx.role ?? ctx.roles[0] ?? "staff";
}

function userIdOf(raw: unknown): string {
  if (typeof raw !== "string" || !raw || raw.length > 128 || raw.includes("/")) {
    throw invalidArgument("Identifiant client invalide.");
  }
  return raw;
}

function rolesOf(user: Doc): string[] {
  if (Array.isArray(user.roles)) return user.roles.filter((r: unknown) => typeof r === "string");
  return typeof user.role === "string" && user.role ? [user.role] : ["customer"];
}

async function deleteAll(refs: FirebaseFirestore.DocumentReference[]): Promise<void> {
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

export const deleteCustomerAccount = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireSuperAdmin(ctx);
  const userId = userIdOf(request.data?.userId);
  const dryRun = request.data?.dryRun === true;

  const userRef = db.collection("users").doc(userId);
  const [authUser, userSnap, driverSnap, missionsSnap, paymentsSnap] = await Promise.all([
    admin.auth().getUser(userId).catch(() => null),
    userRef.get(),
    db.collection("driver_profiles").doc(userId).get(),
    db.collection("delivery_requests").where("customer_id", "==", userId).limit(500).get(),
    db.collection("payments").where("customer_id", "==", userId).limit(1000).get(),
  ]);
  const user = userSnap.data() ?? {};
  if (!authUser && !userSnap.exists) throw notFound("Compte introuvable.");
  if (user.deleted === true) throw failedPrecondition("Ce client est déjà effacé.");

  const missions = missionsSnap.docs.map((d) => d.data());
  const payments = paymentsSnap.docs.map((d) => d.data());
  const blockers = deletionBlockers({
    actorUid: ctx.uid,
    targetUid: userId,
    roles: rolesOf(user),
    hasDriverProfile: driverSnap.exists,
    missions,
    payments,
  });
  const mode = deletionMode(missions, payments);
  const preview = {
    mode,
    blockers,
    deliveries: missions.filter((m) => m.status !== "draft" && m.status !== "quoted").length,
    payments: payments.length,
  };
  if (dryRun) return preview;
  if (blockers.length) throw failedPrecondition(blockers.join(" "));

  const reason = typeof request.data?.reason === "string" ? request.data.reason.trim() : "";
  if (reason.length < 5 || reason.length > 500) {
    throw invalidArgument("Indiquez la raison de l'effacement (5 caractères ou plus).");
  }

  // La connexion part en premier : si une étape suivante échoue, relancer
  // l'effacement reprend là où il s'est arrêté (le profil n'est marqué
  // « effacé » qu'à la toute fin).
  if (authUser) {
    await admin.auth().deleteUser(userId).catch((error: { code?: string }) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });
  }

  // Données personnelles rattachées au client, dans les deux cas.
  const [notifications, notes, tokens, quotes] = await Promise.all([
    userRef.collection("notifications").get(),
    db.collection("customer_notes").where("user_id", "==", userId).get(),
    db.collection("push_tokens").where("user_id", "==", userId).get(),
    db.collection("delivery_quotes").where("customer_id", "==", userId).get(),
  ]);
  // Un prix qui a servi à une réservation reste avec la livraison (preuve du
  // prix) ; les prix calculés sans réservation partent.
  const unusedQuotes = quotes.docs.filter((d) => d.data().is_consumed !== true);
  await deleteAll([
    ...notifications.docs.map((d) => d.ref),
    ...notes.docs.map((d) => d.ref),
    ...tokens.docs.map((d) => d.ref),
    ...(mode === "erase" ? quotes.docs : unusedQuotes).map((d) => d.ref),
    db.collection("booking_drafts").doc(userId),
  ]);

  if (mode === "erase") {
    await deleteAll([userRef, db.collection("payment_profiles").doc(userId)]);
    // Photos de brouillon jamais rattachées à une livraison.
    try {
      await admin.storage().bucket().deleteFiles({ prefix: `booking_photos/${userId}/`, force: true });
    } catch {
      // Le compte est effacé même si le stockage ne répond pas ; le ménage
      // horaire des brouillons reprendra les fichiers expirés.
    }
  } else {
    // Réécriture complète (pas de fusion) : aucun champ personnel ne survit.
    await userRef.set(
      anonymizedUserDoc(user, userId, ctx.uid, admin.firestore.FieldValue.serverTimestamp())
    );
  }

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: roleOf(ctx),
    action: "customer_account_deleted",
    sourceFunction: "deleteCustomerAccount",
    targetId: userId,
    metadata: {
      mode,
      reason,
      deliveriesKept: mode === "anonymize" ? preview.deliveries : 0,
      paymentsKept: mode === "anonymize" ? preview.payments : 0,
      notesDeleted: notes.size,
      notificationsDeleted: notifications.size,
      quotesDeleted: mode === "erase" ? quotes.size : unusedQuotes.length,
    },
  });

  return { ...preview, deleted: true };
});

export const getMarketingOptIns = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);
  const missions = await db.collection("delivery_requests").select("customer_id", "created_at").limit(5000).get();
  const bookings = missions.docs.map((d) => d.ref.collection("private").doc("booking"));
  const rows: Array<{ customerId: unknown; createdAt: unknown; optIn: boolean }> = [];
  for (let i = 0; i < bookings.length; i += 300) {
    const chunk = bookings.slice(i, i + 300);
    if (!chunk.length) break;
    const snaps = await db.getAll(...chunk);
    snaps.forEach((snap, index) => {
      const mission = missions.docs[i + index].data();
      if (!snap.exists) return;
      rows.push({
        customerId: mission.customer_id,
        createdAt: mission.created_at,
        optIn: snap.data()?.marketing_preference?.opt_in === true,
      });
    });
  }
  return { userIds: latestMarketingOptIns(rows) };
});
