// -----------------------------------------------------------------------------
// bookingEmails.ts — contenu des courriels et rappels de réservation
// (décision Daniel, 2026-11-10). Fonctions pures, testées en unitaire.
//
//   - « Réservation confirmée » : envoyé au client quand la mission est créée
//     (dépôt payé) : référence, date, adresses, objets, dépôt payé, solde,
//     total, lien de suivi.
//   - Rappel 4 h avant le ramassage : client et chauffeur (push, cloche et
//     courriel).
//
// Les montants viennent des champs serveur de la mission (jamais recalculés) ;
// aucun changement aux tarifs, commissions, taxes ni au dépôt.
// -----------------------------------------------------------------------------

import { missionPickupAtMs } from "./missionFees";
import {
  EmailLocale,
  OutgoingEmail,
  formatEmailAddress,
  formatEmailDateTime,
  formatEmailMoney,
  formatEmailTime,
  renderEmailHtml,
  renderEmailText,
} from "./transactionalEmail";

export const PICKUP_REMINDER_LEAD_MS = 4 * 60 * 60 * 1000;
/** Plus de rappel à moins de 10 minutes du ramassage. */
export const PICKUP_REMINDER_MIN_LEAD_MS = 10 * 60 * 1000;

const SITE = "https://movi-k.com";

type Mission = Record<string, any>;

function tr(locale: EmailLocale, fr: string, en: string, es: string): string {
  return locale === "en" ? en : locale === "es" ? es : fr;
}

export function trackingUrl(missionId: string, locale: EmailLocale): string {
  const path = locale === "en" ? "delivery/track" : locale === "es" ? "entrega/seguimiento" : "livraison/suivi";
  return `${SITE}/${locale}/${path}/${encodeURIComponent(missionId)}`;
}

export function driverDashboardUrl(locale: EmailLocale): string {
  return locale === "fr" ? `${SITE}/fr/fournisseur/tableau-de-bord` : `${SITE}/${locale}/provider/dashboard`;
}

/** Livraison « dès que possible » : pas d'heure de ramassage fixe. */
export function isImmediateMission(mission: Mission): boolean {
  return mission.booking_snapshot?.load?.timing_mode === "immediate";
}

function itemsText(mission: Mission): string {
  const items = mission.booking_snapshot?.load?.items;
  if (Array.isArray(items) && items.length) {
    return items
      .filter((i) => i && typeof i === "object")
      .map((i) => `${Number(i.quantity) || 1} × ${String(i.label ?? "").trim()}`)
      .join(", ");
  }
  return typeof mission.description === "string" ? mission.description.replace(/;\s*/g, ", ") : "";
}

function firstName(name: unknown): string {
  return typeof name === "string" ? name.trim().split(/\s+/)[0] ?? "" : "";
}

function footer(locale: EmailLocale): string {
  return tr(
    locale,
    "Movi-K — transport de meubles, électroménagers et colis. Une question ? Répondez à ce courriel ou écrivez à infos@movi-k.com.",
    "Movi-K — moving furniture, appliances and parcels. A question? Reply to this email or write to infos@movi-k.com.",
    "Movi-K — transporte de muebles, electrodomésticos y paquetes. ¿Una pregunta? Responde a este correo o escribe a infos@movi-k.com."
  );
}

/** Courriel « Réservation confirmée » envoyé au client. */
export function bookingConfirmedEmail(missionId: string, mission: Mission, locale: EmailLocale): Omit<OutgoingEmail, "to"> {
  const totalMinor = Number.isSafeInteger(mission.customer_total_minor) ? (mission.customer_total_minor as number) : 0;
  const depositMinor =
    mission.deposit?.status === "captured" && Number.isSafeInteger(mission.deposit?.amount_minor)
      ? (mission.deposit.amount_minor as number)
      : 0;
  const pickupMs = missionPickupAtMs(mission);
  const when = isImmediateMission(mission) || pickupMs === null
    ? tr(locale, "Dès que possible", "As soon as possible", "Lo antes posible")
    : formatEmailDateTime(pickupMs, locale);
  const name = firstName(mission.customer_display_name);
  const rows: Array<[string, string]> = [
    [tr(locale, "Référence", "Reference", "Referencia"), missionId],
    [tr(locale, "Quand", "When", "Cuándo"), when],
    [tr(locale, "Ramassage", "Pickup", "Recogida"), formatEmailAddress(mission.pickup_address)],
    [tr(locale, "Livraison", "Drop-off", "Entrega"), formatEmailAddress(mission.dropoff_address)],
    [tr(locale, "Objets", "Items", "Objetos"), itemsText(mission)],
  ];
  const highlight: Array<[string, string]> = depositMinor > 0
    ? [
      [tr(locale, "Payé aujourd'hui (dépôt)", "Paid today (deposit)", "Pagado hoy (depósito)"), formatEmailMoney(depositMinor, locale)],
      [tr(locale, "Après la livraison (solde)", "After delivery (balance)", "Después de la entrega (saldo)"), formatEmailMoney(totalMinor - depositMinor, locale)],
      [tr(locale, "Total, taxes comprises", "Total, taxes included", "Total, impuestos incluidos"), formatEmailMoney(totalMinor, locale)],
    ]
    : [[tr(locale, "Total, taxes comprises", "Total, taxes included", "Total, impuestos incluidos"), formatEmailMoney(totalMinor, locale)]];
  const content = {
    title: tr(locale, "Votre réservation est confirmée ✅", "Your booking is confirmed ✅", "Tu reserva está confirmada ✅"),
    intro: tr(
      locale,
      `${name ? `Bonjour ${name}, merci` : "Merci"} d'avoir choisi Movi-K. Un chauffeur de la région va accepter votre livraison ; vous recevrez une notification dès qu'il est confirmé.`,
      `${name ? `Hi ${name}, thank you` : "Thank you"} for choosing Movi-K. A driver in your area will accept your delivery; you will be notified as soon as one is confirmed.`,
      `${name ? `Hola ${name}, gracias` : "Gracias"} por elegir Movi-K. Un conductor de la zona aceptará tu entrega; recibirás una notificación en cuanto se confirme.`
    ),
    rows,
    highlight,
    paragraphs: [
      tr(
        locale,
        "Le solde est réservé sur votre carte quand un chauffeur accepte, puis prélevé après la livraison. Dépôt remboursé si aucun chauffeur n'accepte ou si vous annulez plus de 48 h avant le ramassage. Un reçu Stripe vous est aussi envoyé pour chaque paiement.",
        "The balance is held on your card when a driver accepts, then charged after delivery. The deposit is refunded if no driver accepts or if you cancel more than 48 hours before pickup. Stripe also emails you a receipt for each payment.",
        "El saldo se reserva en tu tarjeta cuando un conductor acepta y se cobra después de la entrega. El depósito se reembolsa si ningún conductor acepta o si cancelas más de 48 h antes de la recogida. Stripe también te envía un recibo por cada pago."
      ),
    ],
    button: { label: tr(locale, "Suivre ma livraison", "Track my delivery", "Seguir mi entrega"), url: trackingUrl(missionId, locale) },
    footer: footer(locale),
  };
  return {
    subject: tr(
      locale,
      `Réservation confirmée — Movi-K (${when})`,
      `Booking confirmed — Movi-K (${when})`,
      `Reserva confirmada — Movi-K (${when})`
    ),
    html: renderEmailHtml(content),
    text: renderEmailText(content),
    category: "booking_confirmed",
  };
}

export type ReminderRole = "customer" | "driver";

/** Courriel de rappel, 4 h avant le ramassage. */
export function pickupReminderEmail(
  missionId: string,
  mission: Mission,
  role: ReminderRole,
  pickupMs: number,
  locale: EmailLocale
): Omit<OutgoingEmail, "to"> {
  const time = formatEmailTime(pickupMs, locale);
  const pickup = formatEmailAddress(mission.pickup_address);
  const dropoff = formatEmailAddress(mission.dropoff_address);
  const customer = role === "customer";
  const other = customer ? firstName(mission.driver_display_name) : firstName(mission.customer_display_name);
  const rows: Array<[string, string]> = [
    [tr(locale, "Ramassage", "Pickup", "Recogida"), formatEmailDateTime(pickupMs, locale)],
    [tr(locale, "Adresse de ramassage", "Pickup address", "Dirección de recogida"), pickup],
    [tr(locale, "Livraison", "Drop-off", "Entrega"), dropoff],
    [tr(locale, "Objets", "Items", "Objetos"), itemsText(mission)],
    ...(other
      ? [[customer ? tr(locale, "Votre chauffeur", "Your driver", "Tu conductor") : tr(locale, "Client", "Customer", "Cliente"), other] as [string, string]]
      : []),
    [tr(locale, "Référence", "Reference", "Referencia"), missionId],
  ];
  const content = {
    title: customer
      ? tr(locale, `Rappel : votre livraison à ${time}`, `Reminder: your delivery at ${time}`, `Recordatorio: tu entrega a las ${time}`)
      : tr(locale, `Rappel : ramassage à ${time}`, `Reminder: pickup at ${time}`, `Recordatorio: recogida a las ${time}`),
    intro: customer
      ? tr(
        locale,
        "Votre chauffeur Movi-K passe dans environ 4 heures. Préparez vos objets et assurez-vous que l'accès est dégagé.",
        "Your Movi-K driver arrives in about 4 hours. Get your items ready and make sure the access is clear.",
        "Tu conductor de Movi-K llega en unas 4 horas. Prepara tus objetos y asegúrate de que el acceso esté despejado."
      )
      : tr(
        locale,
        "Vous avez un ramassage Movi-K dans environ 4 heures. Ouvrez la livraison dans l'application pour l'itinéraire et les détails.",
        "You have a Movi-K pickup in about 4 hours. Open the delivery in the app for directions and details.",
        "Tienes una recogida de Movi-K en unas 4 horas. Abre la entrega en la aplicación para ver la ruta y los detalles."
      ),
    rows,
    button: customer
      ? { label: tr(locale, "Suivre ma livraison", "Track my delivery", "Seguir mi entrega"), url: trackingUrl(missionId, locale) }
      : { label: tr(locale, "Ouvrir mes livraisons", "Open my deliveries", "Abrir mis entregas"), url: driverDashboardUrl(locale) },
    footer: footer(locale),
  };
  return {
    subject: content.title + " — Movi-K",
    html: renderEmailHtml(content),
    text: renderEmailText(content),
    category: customer ? "pickup_reminder_customer" : "pickup_reminder_driver",
  };
}

/** Texte du push de rappel. */
export function pickupReminderPush(
  mission: Mission,
  role: ReminderRole,
  pickupMs: number,
  locale: EmailLocale
): { title: string; body: string } {
  const time = formatEmailTime(pickupMs, locale);
  const pickup = formatEmailAddress(mission.pickup_address);
  if (role === "customer") {
    return {
      title: tr(locale, `Rappel : livraison Movi-K à ${time}`, `Reminder: Movi-K delivery at ${time}`, `Recordatorio: entrega Movi-K a las ${time}`),
      body: tr(
        locale,
        `Votre chauffeur passe vers ${time} au ${pickup}. Préparez vos objets.`,
        `Your driver arrives around ${time} at ${pickup}. Get your items ready.`,
        `Tu conductor llega hacia las ${time} a ${pickup}. Prepara tus objetos.`
      ),
    };
  }
  return {
    title: tr(locale, `Rappel : ramassage à ${time}`, `Reminder: pickup at ${time}`, `Recordatorio: recogida a las ${time}`),
    body: tr(
      locale,
      `Ramassage au ${pickup}. Ouvrez Movi-K pour l'itinéraire.`,
      `Pickup at ${pickup}. Open Movi-K for directions.`,
      `Recogida en ${pickup}. Abre Movi-K para ver la ruta.`
    ),
  };
}

/**
 * Doit-on rappeler maintenant ? Oui entre 4 h et 10 min avant le ramassage,
 * seulement si la réservation (client) ou l'acceptation (chauffeur) date
 * d'avant la fenêtre de 4 h — sinon le rendez-vous vient d'être pris.
 */
export function reminderDue(params: {
  pickupMs: number | null;
  nowMs: number;
  committedAtMs: number | null;
}): boolean {
  const { pickupMs, nowMs, committedAtMs } = params;
  if (pickupMs === null) return false;
  const lead = pickupMs - nowMs;
  if (lead > PICKUP_REMINDER_LEAD_MS || lead < PICKUP_REMINDER_MIN_LEAD_MS) return false;
  if (committedAtMs === null) return false;
  return committedAtMs <= pickupMs - PICKUP_REMINDER_LEAD_MS;
}

/** « Votre reçu Movi-K » : renvoyé par le service client (fiche client, 2026-11-10). */
export function paymentReceiptEmail(params: {
  missionId: string | null;
  amountMinor: number;
  paidAtMs: number | null;
  receiptUrl: string;
  locale: EmailLocale;
}): Omit<OutgoingEmail, "to"> {
  const { locale } = params;
  const rows: Array<[string, string]> = [
    [tr(locale, "Montant", "Amount", "Monto"), formatEmailMoney(params.amountMinor, locale)],
    ...(params.paidAtMs !== null
      ? [[tr(locale, "Payé le", "Paid on", "Pagado el"), formatEmailDateTime(params.paidAtMs, locale)] as [string, string]]
      : []),
    ...(params.missionId ? [[tr(locale, "Référence", "Reference", "Referencia"), params.missionId] as [string, string]] : []),
  ];
  const content = {
    title: tr(locale, "Votre reçu Movi-K", "Your Movi-K receipt", "Tu recibo de Movi-K"),
    intro: tr(
      locale,
      "Comme demandé, voici le reçu officiel de votre paiement, émis par Stripe, notre processeur de paiement.",
      "As requested, here is the official receipt for your payment, issued by Stripe, our payment processor.",
      "Como lo pediste, aquí está el recibo oficial de tu pago, emitido por Stripe, nuestro procesador de pagos."
    ),
    rows,
    button: { label: tr(locale, "Voir mon reçu", "View my receipt", "Ver mi recibo"), url: params.receiptUrl },
    footer: footer(locale),
  };
  return {
    subject: tr(locale, "Votre reçu — Movi-K", "Your receipt — Movi-K", "Tu recibo — Movi-K"),
    html: renderEmailHtml(content),
    text: renderEmailText(content),
    category: "payment_receipt",
  };
}
