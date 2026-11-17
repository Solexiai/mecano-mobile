// -----------------------------------------------------------------------------
// followUpEmails.ts — relances des prospects (décision Daniel, 2026-11-17).
// Fonctions pures, testées en unitaire.
//
//   - Client : il a obtenu un prix et n'a pas réservé → un courriel le
//     lendemain (J+1) et un autre 3 jours après la première demande (J+3).
//   - Chauffeur : son inscription n'est pas terminée (profil, document
//     demandé ou versements Stripe) → mêmes relances J+1 et J+3 ; pour
//     Stripe, un premier courriel dès l'approbation du dossier.
//
// Aucun rabais (décision du 2026-11-17). Chaque relance porte l'adresse
// postale de Movi-K et un lien « Me désabonner » (loi canadienne
// anti-pourriel) : voir lib/emailPreferences.ts.
// -----------------------------------------------------------------------------

import {
  EmailLocale,
  OutgoingEmail,
  formatEmailAddress,
  formatEmailMoney,
  renderEmailHtml,
  renderEmailText,
} from "./transactionalEmail";

const HOUR_MS = 60 * 60 * 1000;
export const FOLLOW_UP_FIRST_MS = 24 * HOUR_MS;
export const FOLLOW_UP_SECOND_MS = 72 * HOUR_MS;
/** Passé 5 jours, on ne relance plus : la demande est trop vieille. */
export const FOLLOW_UP_END_MS = 120 * HOUR_MS;
/** Une nouvelle série de relances au plus tous les 14 jours par personne. */
export const FOLLOW_UP_COOLDOWN_MS = 14 * 24 * HOUR_MS;
/** Les relances partent de 9 h à 20 h, heure du Québec. */
export const FOLLOW_UP_SEND_FROM_HOUR = 9;
export const FOLLOW_UP_SEND_UNTIL_HOUR = 20;

const SITE = "https://movi-k.com";

/** 0 = tout de suite (approbation chauffeur), 1 = lendemain, 2 = 3 jours après. */
export type FollowUpStep = 0 | 1 | 2;
export type DriverFollowUpStage = "profile" | "documents" | "stripe";

function tr(locale: EmailLocale, fr: string, en: string, es: string): string {
  return locale === "en" ? en : locale === "es" ? es : fr;
}

function firstName(name: unknown): string {
  return typeof name === "string" ? name.trim().split(/\s+/)[0] ?? "" : "";
}

/**
 * Quelle relance est due maintenant ? `anchorMs` = moment de la première
 * demande (ou du début de l'étape chauffeur) ; `sent` = relances déjà faites.
 *   - moins de 24 h : rien (ou l'étape 0 si `immediate`) ;
 *   - de 24 h à 72 h : la relance 1, une seule fois ;
 *   - de 72 h à 5 jours : la relance 2, une seule fois, et jamais moins de
 *     24 h après la relance 1 ;
 *   - ensuite : plus rien.
 */
export function followUpStepDue(params: {
  anchorMs: number | null;
  nowMs: number;
  sent: Partial<Record<FollowUpStep, number>>;
  immediate?: boolean;
}): FollowUpStep | null {
  const { anchorMs, nowMs, sent } = params;
  if (anchorMs === null || !Number.isFinite(anchorMs)) return null;
  const age = nowMs - anchorMs;
  if (age < 0 || age >= FOLLOW_UP_END_MS) return null;
  if (age < FOLLOW_UP_FIRST_MS) {
    return params.immediate && sent[0] === undefined && sent[1] === undefined && sent[2] === undefined ? 0 : null;
  }
  if (age < FOLLOW_UP_SECOND_MS) return sent[1] === undefined && sent[2] === undefined ? 1 : null;
  if (sent[2] !== undefined) return null;
  if (sent[1] !== undefined && nowMs - sent[1] < FOLLOW_UP_FIRST_MS) return null;
  return 2;
}

/** Heure d'envoi permise (9 h à 20 h, heure du Québec) ? */
export function withinFollowUpSendingHours(nowMs: number): boolean {
  const hour = Number(
    new Intl.DateTimeFormat("en-CA", { timeZone: "America/Toronto", hour: "2-digit", hourCycle: "h23" })
      .formatToParts(nowMs).find((p) => p.type === "hour")?.value ?? "0"
  );
  return hour >= FOLLOW_UP_SEND_FROM_HOUR && hour < FOLLOW_UP_SEND_UNTIL_HOUR;
}

/** Instant (ms) d'un Timestamp Firestore, d'une date ISO ou d'un nombre ; sinon null. */
export function followUpMillis(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") {
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
  }
  const ms = (value as { toMillis?: () => number } | null | undefined)?.toMillis?.();
  return typeof ms === "number" && Number.isFinite(ms) ? ms : null;
}

function withCampaign(url: string, campaign: string): string {
  return `${url}?utm_source=movik&utm_medium=email&utm_campaign=${campaign}`;
}

export function bookingRequestUrl(locale: EmailLocale, campaign: string): string {
  const path = locale === "en" ? "delivery/request" : locale === "es" ? "entrega/solicitud" : "livraison/demande";
  return withCampaign(`${SITE}/${locale}/${path}`, campaign);
}

export function driverStageUrl(stage: DriverFollowUpStage, locale: EmailLocale, campaign: string, approved = true): string {
  // Versements : dans l'espace chauffeur une fois approuvé ; avant, sur la page du dossier.
  if (stage === "stripe" && approved) {
    return withCampaign(
      locale === "fr" ? `${SITE}/fr/fournisseur/tableau-de-bord` : `${SITE}/${locale}/provider/dashboard`,
      campaign
    );
  }
  if (stage === "documents" || stage === "stripe") {
    const path = locale === "en" ? "become-driver/status" : locale === "es" ? "convertirse-conductor/estado" : "devenir-chauffeur/statut";
    return withCampaign(`${SITE}/${locale}/${path}`, campaign);
  }
  // L'inscription n'a pas d'adresse en espagnol : la page française s'affiche dans la langue du compte.
  return withCampaign(
    locale === "en" ? `${SITE}/en/become-driver/onboarding` : `${SITE}/fr/devenir-chauffeur/inscription`,
    campaign
  );
}

/** Pied de page légal d'une relance : qui écrit, pourquoi, adresse postale. */
export function followUpFooter(locale: EmailLocale, audience: "customer" | "driver", postalAddress: string): string {
  const why = audience === "customer"
    ? tr(
      locale,
      "Vous recevez ce courriel parce que vous avez demandé un prix sur movi-k.com.",
      "You are receiving this email because you asked for a price on movi-k.com.",
      "Recibes este correo porque pediste un precio en movi-k.com."
    )
    : tr(
      locale,
      "Vous recevez ce courriel parce que vous avez commencé une inscription de chauffeur sur movi-k.com.",
      "You are receiving this email because you started a driver registration on movi-k.com.",
      "Recibes este correo porque empezaste una inscripción de conductor en movi-k.com."
    );
  return `Movi-K · ${postalAddress.trim()} · infos@movi-k.com. ${why}`;
}

function unsubscribeLabel(locale: EmailLocale): string {
  return tr(locale, "Me désabonner de ces rappels", "Unsubscribe from these reminders", "Darme de baja de estos recordatorios");
}

function itemsText(items: unknown): string {
  if (!Array.isArray(items)) return "";
  return items
    .filter((i) => i && typeof i === "object")
    .map((i) => `${Number((i as { quantity?: unknown }).quantity) || 1} × ${String((i as { label?: unknown }).label ?? "").trim()}`)
    .filter((line) => !line.endsWith("× "))
    .join(", ");
}

function stopAddress(quote: Record<string, any>, type: "pickup" | "dropoff"): string {
  const stops = Array.isArray(quote.stops) ? quote.stops : [];
  const matching = stops.filter((s: any) => s && s.type === type);
  const stop = type === "dropoff" ? matching[matching.length - 1] : matching[0];
  return formatEmailAddress(stop?.address);
}

export interface FollowUpLegal {
  postalAddress: string;
  unsubscribeUrl: string;
}

function unsubscribeHeaders(url: string): Record<string, string> {
  return { "List-Unsubscribe": `<${url}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" };
}

/** Relance du client qui a eu un prix sans réserver (étape 1 = J+1, étape 2 = J+3). */
export function quoteFollowUpEmail(params: {
  quote: Record<string, any>;
  step: 1 | 2;
  locale: EmailLocale;
  customerName?: unknown;
  legal: FollowUpLegal;
}): Omit<OutgoingEmail, "to"> {
  const { quote, step, locale, legal } = params;
  const totalMinor = Number.isSafeInteger(quote.customer_total_minor) ? (quote.customer_total_minor as number) : 0;
  const price = totalMinor > 0 ? formatEmailMoney(totalMinor, locale) : "";
  const name = firstName(params.customerName);
  const hello = name
    ? tr(locale, `Bonjour ${name}, `, `Hi ${name}, `, `Hola ${name}, `)
    : "";
  const cap = (text: string) => (hello ? text : text.charAt(0).toUpperCase() + text.slice(1));
  const load = quote.pricing_snapshot?.pre_assignment?.load ?? quote.pricing_snapshot?.booking?.load;
  const rows = ([
    [tr(locale, "Ramassage", "Pickup", "Recogida"), stopAddress(quote, "pickup")],
    [tr(locale, "Livraison", "Drop-off", "Entrega"), stopAddress(quote, "dropoff")],
    [tr(locale, "Objets", "Items", "Objetos"), itemsText(load?.items)],
  ] as Array<[string, string]>).filter(([, value]) => value);
  const campaign = step === 1 ? "relance_prix_j1" : "relance_prix_j3";
  const content = {
    title: step === 1
      ? tr(locale, "Votre prix Movi-K vous attend", "Your Movi-K price is waiting", "Tu precio Movi-K te espera")
      : tr(locale, "Toujours besoin de faire livrer ?", "Still need it delivered?", "¿Aún necesitas la entrega?"),
    intro: step === 1
      ? hello + cap(tr(
        locale,
        "hier, vous avez demandé un prix pour faire transporter vos objets. Il reste une seule étape : choisir votre moment et réserver. Un chauffeur de votre région s'occupe du reste.",
        "yesterday you asked for a price to have your items moved. One step is left: pick your time and book. A driver in your area takes care of the rest.",
        "ayer pediste un precio para transportar tus objetos. Solo falta un paso: elegir el momento y reservar. Un conductor de tu zona se encarga del resto."
      ))
      : hello + cap(tr(
        locale,
        "votre demande de transport est toujours ouverte. Si vos objets attendent encore, réservez en quelques minutes. C'est notre dernier rappel pour cette demande.",
        "your delivery request is still open. If your items are still waiting, you can book in a few minutes. This is our last reminder for this request.",
        "tu solicitud de transporte sigue abierta. Si tus objetos siguen esperando, reserva en unos minutos. Este es nuestro último recordatorio para esta solicitud."
      )),
    rows,
    highlight: price
      ? [[tr(locale, "Votre prix, taxes comprises", "Your price, taxes included", "Tu precio, impuestos incluidos"), price] as [string, string]]
      : [],
    paragraphs: [
      tr(
        locale,
        "Le prix est confirmé à l'écran au moment de réserver. Dépôt de 25 $ à la réservation, déduit du total ; il est remboursé si vous annulez plus de 48 h avant le ramassage.",
        "The price is confirmed on screen when you book. A $25 deposit is paid at booking and deducted from the total; it is refunded if you cancel more than 48 hours before pickup.",
        "El precio se confirma en pantalla al reservar. Depósito de 25 $ al reservar, deducido del total; se reembolsa si cancelas más de 48 h antes de la recogida."
      ),
      tr(
        locale,
        "Une question ? Répondez simplement à ce courriel.",
        "A question? Just reply to this email.",
        "¿Una pregunta? Simplemente responde a este correo."
      ),
    ],
    button: {
      label: tr(locale, "Réserver ma livraison", "Book my delivery", "Reservar mi entrega"),
      url: bookingRequestUrl(locale, campaign),
    },
    footer: followUpFooter(locale, "customer", legal.postalAddress),
    unsubscribe: { label: unsubscribeLabel(locale), url: legal.unsubscribeUrl },
  };
  const subject = step === 1
    ? price
      ? tr(locale, `Votre prix Movi-K : ${price}`, `Your Movi-K price: ${price}`, `Tu precio Movi-K: ${price}`)
      : tr(locale, "Votre prix Movi-K vous attend", "Your Movi-K price is waiting", "Tu precio Movi-K te espera")
    : tr(locale, "Toujours besoin de faire livrer ? — Movi-K", "Still need it delivered? — Movi-K", "¿Aún necesitas la entrega? — Movi-K");
  return {
    subject,
    html: renderEmailHtml(content),
    text: renderEmailText(content),
    category: `quote_followup_${step}`,
    headers: unsubscribeHeaders(legal.unsubscribeUrl),
  };
}

/** Relance du chauffeur dont l'inscription n'est pas terminée. */
export function driverFollowUpEmail(params: {
  stage: DriverFollowUpStage;
  step: FollowUpStep;
  locale: EmailLocale;
  driverName?: unknown;
  /** Motif écrit par Movi-K quand un document est demandé. */
  documentsReason?: unknown;
  /** Étape Stripe : faux tant que Movi-K n'a pas approuvé le dossier (défaut : vrai). */
  approved?: boolean;
  legal: FollowUpLegal;
}): Omit<OutgoingEmail, "to"> {
  const { stage, step, locale, legal } = params;
  const name = firstName(params.driverName);
  const hello = name ? tr(locale, `Bonjour ${name}, `, `Hi ${name}, `, `Hola ${name}, `) : "";
  const cap = (text: string) => (hello ? text : text.charAt(0).toUpperCase() + text.slice(1));
  const last = step === 2
    ? tr(locale, " C'est notre dernier rappel.", " This is our last reminder.", " Este es nuestro último recordatorio.")
    : "";
  const campaign = `relance_chauffeur_${stage}_j${step === 2 ? 3 : step}`;
  const reason = typeof params.documentsReason === "string" ? params.documentsReason.trim().slice(0, 500) : "";

  let title: string;
  let intro: string;
  let buttonLabel: string;
  let rows: Array<[string, string]> = [];
  const paragraphs: string[] = [];

  if (stage === "profile") {
    title = tr(locale, "Terminez votre inscription de chauffeur", "Finish your driver registration", "Termina tu inscripción de conductor");
    intro = hello + cap(tr(
      locale,
      "votre inscription de chauffeur Movi-K n'est pas terminée. Il reste quelques minutes : votre profil, votre véhicule et vos documents.",
      "your Movi-K driver registration is not finished. A few minutes are left: your profile, your vehicle and your documents.",
      "tu inscripción de conductor Movi-K no está terminada. Quedan unos minutos: tu perfil, tu vehículo y tus documentos."
    )) + last;
    paragraphs.push(tr(
      locale,
      "Vous êtes payé à la livraison : de 80 $ à 120 $ pour 2 à 4 articles, et 100 % des pourboires sont à vous. Vous choisissez les livraisons que vous acceptez.",
      "You are paid per delivery: $80 to $120 for 2 to 4 items, and 100% of tips are yours. You choose the deliveries you accept.",
      "Cobras por entrega: de 80 $ a 120 $ por 2 a 4 artículos, y el 100 % de las propinas es tuyo. Tú eliges las entregas que aceptas."
    ));
    buttonLabel = tr(locale, "Terminer mon inscription", "Finish my registration", "Terminar mi inscripción");
  } else if (stage === "documents") {
    title = tr(locale, "Il manque un document à votre dossier", "A document is missing from your file", "Falta un documento en tu expediente");
    intro = hello + cap(tr(
      locale,
      "il manque un document pour que Movi-K puisse approuver votre dossier de chauffeur. Ajoutez-le en quelques minutes et nous reprenons la vérification.",
      "a document is missing before Movi-K can approve your driver file. Add it in a few minutes and we resume the review.",
      "falta un documento para que Movi-K pueda aprobar tu expediente de conductor. Añádelo en unos minutos y retomamos la verificación."
    )) + last;
    if (reason) rows = [[tr(locale, "Ce qu'il manque", "What is missing", "Lo que falta"), reason]];
    buttonLabel = tr(locale, "Ajouter mon document", "Add my document", "Añadir mi documento");
  } else {
    const approved = params.approved !== false;
    title = !approved
      ? tr(locale, "Une dernière étape : activez vos versements", "One last step: turn on your payouts", "Un último paso: activa tus pagos")
      : step === 0
        ? tr(locale, "Votre dossier est approuvé 🎉", "Your file is approved 🎉", "Tu expediente está aprobado 🎉")
        : tr(locale, "Une dernière étape pour être payé", "One last step to get paid", "Un último paso para cobrar");
    intro = hello + cap(!approved
      ? tr(
        locale,
        "votre inscription de chauffeur est presque terminée. Pendant que Movi-K vérifie votre dossier, activez vos versements avec Stripe : vous serez prêt à être payé dès l'approbation.",
        "your driver registration is almost finished. While Movi-K reviews your file, turn on your payouts with Stripe: you will be ready to get paid as soon as you are approved.",
        "tu inscripción de conductor está casi terminada. Mientras Movi-K revisa tu expediente, activa tus pagos con Stripe: estarás listo para cobrar en cuanto te aprueben."
      )
      : step === 0
        ? tr(
          locale,
          "bonne nouvelle : Movi-K a approuvé votre dossier de chauffeur. Il reste une étape pour recevoir vos paiements : activer vos versements avec Stripe.",
          "good news: Movi-K approved your driver file. One step is left to receive your payments: turn on your payouts with Stripe.",
          "buenas noticias: Movi-K aprobó tu expediente de conductor. Falta un paso para recibir tus pagos: activar tus pagos con Stripe."
        )
        : tr(
          locale,
          "votre dossier de chauffeur est approuvé, mais vos versements ne sont pas encore activés. Tant que ce n'est pas fait, vous ne pouvez pas être payé pour une livraison.",
          "your driver file is approved, but your payouts are not turned on yet. Until this is done, you cannot be paid for a delivery.",
          "tu expediente de conductor está aprobado, pero tus pagos aún no están activados. Hasta que lo hagas, no puedes cobrar una entrega."
        )) + last;
    paragraphs.push(tr(
      locale,
      "Stripe est le service de paiement sécurisé qui verse votre argent dans votre compte bancaire. Vos renseignements bancaires sont saisis directement chez Stripe. Prévoyez environ 5 minutes, avec une pièce d'identité et vos coordonnées bancaires.",
      "Stripe is the secure payment service that sends your money to your bank account. Your banking details are entered directly with Stripe. Allow about 5 minutes, with a piece of ID and your banking details.",
      "Stripe es el servicio de pago seguro que envía tu dinero a tu cuenta bancaria. Tus datos bancarios se ingresan directamente en Stripe. Calcula unos 5 minutos, con un documento de identidad y tus datos bancarios."
    ));
    if (approved) {
      paragraphs.push(tr(
        locale,
        "Dans l'application : onglet Profil, puis « Configuration des versements ».",
        "In the app: Profile tab, then “Payout setup”.",
        "En la aplicación: pestaña Perfil, luego «Configuración de pagos»."
      ));
    }
    buttonLabel = tr(locale, "Activer mes versements", "Turn on my payouts", "Activar mis pagos");
  }
  paragraphs.push(tr(
    locale,
    "Besoin d'aide ? Répondez simplement à ce courriel.",
    "Need help? Just reply to this email.",
    "¿Necesitas ayuda? Simplemente responde a este correo."
  ));

  const content = {
    title,
    intro,
    rows,
    paragraphs,
    button: { label: buttonLabel, url: driverStageUrl(stage, locale, campaign, params.approved !== false) },
    footer: followUpFooter(locale, "driver", legal.postalAddress),
    unsubscribe: { label: unsubscribeLabel(locale), url: legal.unsubscribeUrl },
  };
  return {
    subject: `${title} — Movi-K`,
    html: renderEmailHtml(content),
    text: renderEmailText(content),
    category: `driver_followup_${stage}_${step}`,
    headers: unsubscribeHeaders(legal.unsubscribeUrl),
  };
}
