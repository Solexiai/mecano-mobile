// Pixel Meta de Movi-K (Daniel, 2026-11-26) : « que Meta cherche des gens qui
// réservent au lieu de gens qui cliquent ».
//
// UN SEUL RÉGLAGE : l'identifiant du pixel, ci-dessous. Tant qu'il est vide,
// ce fichier ne fait rien : pas de bandeau, pas d'appel vers Meta.
//
// Avec un identifiant :
//   1. le visiteur voit un bandeau « Accepter / Refuser » (Loi 25) ;
//   2. le pixel n'est téléchargé qu'après « Accepter » ; le choix est gardé
//      sur l'appareil (localStorage `movik_ads_consent`) ;
//   3. les pages vues partent toutes seules, y compris les changements de page
//      de l'application (le pixel suit l'historique du navigateur) ;
//   4. l'application et la page d'estimation envoient leurs événements par
//      `window.movikMeta.track(nom, paramètres, identifiantUnique)`.
//
// Les pages du personnel et des chauffeurs (admin, tableaux de bord) ne sont
// pas mesurées. Aucune donnée personnelle n'est envoyée par ce fichier.
(function () {
  'use strict';

  // ↓↓↓ Identifiant du pixel Meta (15 ou 16 chiffres). Vide = désactivé. ↓↓↓
  var PIXEL_ID = '';
  // ↑↑↑ ------------------------------------------------------------- ↑↑↑

  var STORAGE_KEY = 'movik_ads_consent';
  var STANDARD = {
    PageView: 1, ViewContent: 1, Lead: 1, InitiateCheckout: 1,
    AddPaymentInfo: 1, Purchase: 1, CompleteRegistration: 1,
  };
  var INTERNAL = /^\/(fr|en|es)\/(admin|fournisseur|provider|tableau-de-bord|dashboard|panel)(\/|$)/;
  var TEXTS = {
    fr: {
      text: 'Movi-K utilise un témoin publicitaire de Meta (Facebook) pour mesurer ses publicités. Rien n’est envoyé sans votre accord.',
      more: 'En savoir plus', accept: 'Accepter', refuse: 'Refuser', label: 'Témoins publicitaires',
    },
    en: {
      text: 'Movi-K uses a Meta (Facebook) advertising cookie to measure its ads. Nothing is sent without your consent.',
      more: 'Learn more', accept: 'Accept', refuse: 'Decline', label: 'Advertising cookies',
    },
    es: {
      text: 'Movi-K usa una cookie publicitaria de Meta (Facebook) para medir sus anuncios. No se envía nada sin su consentimiento.',
      more: 'Más información', accept: 'Aceptar', refuse: 'Rechazar', label: 'Cookies publicitarias',
    },
  };

  var enabled = /^\d{10,20}$/.test(PIXEL_ID);
  var loaded = false;
  var pending = [];

  function internalPage() {
    return INTERNAL.test(window.location.pathname);
  }
  function stored() {
    try { return window.localStorage.getItem(STORAGE_KEY); } catch (e) { return null; }
  }
  function store(value) {
    try { window.localStorage.setItem(STORAGE_KEY, value); } catch (e) { /* navigation privée */ }
  }
  function locale() {
    var m = /^\/(fr|en|es)(\/|$)/.exec(window.location.pathname);
    return m ? m[1] : 'fr';
  }

  function send(name, params, eventId) {
    var method = STANDARD[name] ? 'track' : 'trackCustom';
    if (eventId) window.fbq(method, name, params || {}, { eventID: String(eventId) });
    else window.fbq(method, name, params || {});
  }

  // Le code de base de Meta, inchangé, appelé seulement après l'accord.
  function load() {
    if (loaded) return;
    loaded = true;
    /* eslint-disable */
    !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
    n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;
    n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;
    t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}
    (window,document,'script','https://connect.facebook.net/en_US/fbevents.js');
    /* eslint-enable */
    window.fbq('init', PIXEL_ID);
    window.fbq('track', 'PageView');
    var queued = pending;
    pending = [];
    for (var i = 0; i < queued.length; i++) send(queued[i][0], queued[i][1], queued[i][2]);
  }

  function hideBanner() {
    var el = document.getElementById('movik-ads-consent');
    if (el && el.parentNode) el.parentNode.removeChild(el);
  }

  function showBanner() {
    if (document.getElementById('movik-ads-consent') || !document.body) return;
    var t = TEXTS[locale()];
    var box = document.createElement('div');
    box.id = 'movik-ads-consent';
    box.setAttribute('role', 'region');
    box.setAttribute('aria-label', t.label);
    box.style.cssText = 'position:fixed;left:12px;right:12px;bottom:12px;z-index:2147483000;' +
      'max-width:720px;margin:0 auto;padding:14px 16px;border-radius:14px;background:#fff;' +
      'color:#0F2A5C;box-shadow:0 6px 28px rgba(15,42,92,.28);' +
      'font:14px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;' +
      'display:flex;flex-wrap:wrap;align-items:center;gap:10px 14px';
    var text = document.createElement('p');
    text.style.cssText = 'margin:0;flex:1 1 280px';
    text.appendChild(document.createTextNode(t.text + ' '));
    var link = document.createElement('a');
    link.href = '/' + locale() + '/legal/cookies';
    link.textContent = t.more;
    link.style.cssText = 'color:#0879E8';
    text.appendChild(link);
    var buttons = document.createElement('div');
    buttons.style.cssText = 'display:flex;gap:8px;flex:0 0 auto';
    // Deux boutons de même taille : refuser est aussi simple qu'accepter.
    var base = 'min-width:104px;min-height:44px;padding:0 16px;border-radius:10px;' +
      'font:600 14px system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;cursor:pointer;';
    var refuse = document.createElement('button');
    refuse.type = 'button';
    refuse.textContent = t.refuse;
    refuse.style.cssText = base + 'background:#fff;color:#0F2A5C;border:1.5px solid #0F2A5C';
    refuse.addEventListener('click', function () { api.consent('denied'); });
    var accept = document.createElement('button');
    accept.type = 'button';
    accept.textContent = t.accept;
    accept.style.cssText = base + 'background:#0F2A5C;color:#fff;border:1.5px solid #0F2A5C';
    accept.addEventListener('click', function () { api.consent('granted'); });
    buttons.appendChild(refuse);
    buttons.appendChild(accept);
    box.appendChild(text);
    box.appendChild(buttons);
    document.body.appendChild(box);
  }

  var api = {
    /// Vrai si un identifiant de pixel est réglé.
    enabled: enabled,
    /// Événement vers Meta. Avant l'accord, il attend (20 au plus) ; après un
    /// refus, il est jeté. `eventId` sert à ne pas compter deux fois le même
    /// événement quand le serveur l'enverra aussi.
    track: function (name, params, eventId) {
      try {
        if (!enabled || !name || internalPage()) return;
        var choice = stored();
        if (choice === 'denied') return;
        if (choice === 'granted') { load(); send(name, params, eventId); return; }
        if (pending.length < 20) pending.push([name, params, eventId]);
      } catch (e) { /* la mesure ne doit jamais gêner le client */ }
    },
    /// Choix du visiteur : 'granted' ou 'denied'.
    consent: function (choice) {
      try {
        if (!enabled) return;
        if (choice === 'granted') {
          store('granted');
          hideBanner();
          if (loaded && window.fbq) window.fbq('consent', 'grant');
          else if (!internalPage()) load();
        } else {
          store('denied');
          pending = [];
          hideBanner();
          if (loaded && window.fbq) window.fbq('consent', 'revoke');
        }
      } catch (e) { /* idem */ }
    },
    /// Rouvre le bandeau (lien « Gérer mes témoins »).
    reset: function () {
      try { window.localStorage.removeItem(STORAGE_KEY); } catch (e) { /* idem */ }
      if (enabled) showBanner();
    },
  };
  window.movikMeta = api;

  if (!enabled || internalPage()) return;
  var choice = stored();
  if (choice === 'granted') { load(); return; }
  if (choice === 'denied') return;
  if (document.body) showBanner();
  else document.addEventListener('DOMContentLoaded', showBanner);
})();
