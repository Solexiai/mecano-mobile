// -----------------------------------------------------------------------------
// estimate_page.dart — page d'estimation par codes postaux (Daniel,
// 2026-11-26) : /fr/estimation, /en/estimate, /es/estimacion.
//
// Page d'arrivée des publicités. Contrairement aux autres pages publiques,
// elle NE charge PAS l'application Flutter : c'est une page HTML légère, qui
// s'affiche tout de suite sur un vieux téléphone ou dans le navigateur de
// Facebook. Le visiteur entre deux codes postaux et un poids ; la page
// appelle la fonction publique `estimateDeliveryPrice` et affiche une
// fourchette. Le bouton « Obtenir mon prix exact » ouvre ensuite la demande
// de livraison (l'application), en gardant les paramètres de la publicité
// (utm_*, fbclid, gclid) pour que la source du prospect soit notée.
//
// Le même formulaire est repris en haut de la page d'accueil légère
// (seo_html.dart) : il envoie simplement vers cette page.
//
// Dart pur : utilisé par tool/build_seo_pages.dart et testé par
// test/seo/estimate_page_test.dart.
// -----------------------------------------------------------------------------

import 'dart:convert';

import '../l10n/home_copy.dart';
import 'seo_pages.dart';

/// Fonction publique (functions/src/functions/estimateDeliveryPrice.ts),
/// appelée par le protocole des fonctions « callable » de Firebase. Le
/// projet est celui de lib/backend/firebase_options.dart (vérifié par test).
const estimateFunctionUrl =
    'https://us-central1-movik-connect-prod.cloudfunctions.net/estimateDeliveryPrice';

/// Fonction publique de reconnaissance d'objet sur photo
/// (functions/src/functions/estimateItemFromPhoto.ts).
const estimatePhotoFunctionUrl =
    'https://us-central1-movik-connect-prod.cloudfunctions.net/estimateItemFromPhoto';

const Map<String, String> estimateSlugs = {
  'fr': 'estimation',
  'en': 'estimate',
  'es': 'estimacion',
};

String estimatePath(String locale) => '/$locale/${estimateSlugs[locale]}';
String estimateFile(String locale) => '/seo/$locale/${estimateSlugs[locale]}.html';
String estimateUrl(String locale) => '$seoSiteUrl${estimatePath(locale)}';

/// La langue de la page d'estimation servie à [path], sinon null.
String? estimateLocaleForPath(String path) {
  var clean = path.split('?').first.split('#').first;
  if (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  for (final locale in seoLocales) {
    if (estimatePath(locale) == clean) return locale;
  }
  return null;
}

/// Code postal canadien, complet (« J2G 3V5 ») ou ses trois premiers
/// caractères (« J2G »). Même règle que functions/src/lib/publicEstimate.ts.
final RegExp _postal = RegExp(
  r'^([ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z])(\d[ABCEGHJ-NPRSTV-Z]\d)?$',
);

/// « j2g3v5 » → « J2G 3V5 » ; null si ce n'est pas un code postal canadien.
String? normalizePostalCode(String raw) {
  final match = _postal.firstMatch(
    raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), ''),
  );
  if (match == null) return null;
  final rest = match.group(2);
  return rest == null ? match.group(1) : '${match.group(1)} $rest';
}

const List<String> estimateWeights = ['light', 'medium', 'heavy'];

/// L'adresse de la page d'estimation avec le formulaire déjà rempli.
String estimateLink(
  String locale, {
  required String from,
  required String to,
  required String weight,
}) => Uri(
  path: estimatePath(locale),
  queryParameters: {'de': from, 'a': to, 'poids': weight},
).toString();

/// L'adresse de la page d'estimation qui invite à ajouter une photo
/// (« Pas certain ? Ajoutez une photo »). Les codes postaux déjà saisis
/// suivent ; sans eux, la page s'ouvre vide.
String estimatePhotoLink(String locale, {String? from, String? to, String? weight}) => Uri(
  path: estimatePath(locale),
  queryParameters: {
    'photo': '1',
    if (from != null) 'de': from,
    if (to != null) 'a': to,
    if (weight != null) 'poids': weight,
  },
).toString();

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _h(String key, String locale) => HomeCopy.text(key, locale);

const Map<String, Map<String, String>> _copy = {
  'title': {
    'fr': 'Estimation du prix de livraison par code postal | Movi-K',
    'en': 'Delivery price estimate by postal code | Movi-K',
    'es': 'Precio estimado de entrega por código postal | Movi-K',
  },
  'description': {
    'fr':
        'Deux codes postaux et le poids de l’objet : estimez en 10 secondes le prix de livraison d’un meuble, d’un électroménager ou d’un gros objet. Sans compte.',
    'en':
        'Two postal codes and the weight of the item: estimate in 10 seconds the delivery price of furniture, an appliance or a large item. No account.',
    'es':
        'Dos códigos postales y el peso del objeto: calcula en 10 segundos el precio de entrega de un mueble, un electrodoméstico o un objeto grande. Sin cuenta.',
  },
  'heading': {
    'fr': 'Ça rentre pas ? On s’en occupe.',
    'en': 'Won’t fit? We’ve got it.',
    'es': '¿No cabe? Nosotros nos encargamos.',
  },
  'result_label': {
    'fr': 'Votre estimation',
    'en': 'Your estimate',
    'es': 'Tu precio estimado',
  },
  'taxes': {
    'fr': 'Taxes comprises.',
    'en': 'Taxes included.',
    'es': 'Impuestos incluidos.',
  },
  'result_note': {
    'fr':
        'Le prix exact dépend des escaliers, de l’aide pour porter et du nombre d’objets. On vous le donne à l’étape suivante.',
    'en':
        'The exact price depends on stairs, help with carrying and the number of items. You get it at the next step.',
    'es':
        'El precio exacto depende de las escaleras, de la ayuda para cargar y del número de objetos. Te lo damos en el siguiente paso.',
  },
  'next': {
    'fr': 'Obtenir mon prix exact',
    'en': 'Get my exact price',
    'es': 'Obtener mi precio exacto',
  },
  'next_note': {
    'fr': 'Quelques questions rapides. Rien à payer maintenant.',
    'en': 'A few quick questions. Nothing to pay now.',
    'es': 'Unas preguntas rápidas. Nada que pagar ahora.',
  },
  'loading': {
    'fr': 'Calcul en cours…',
    'en': 'Calculating…',
    'es': 'Calculando…',
  },
  'error_route': {
    'fr': 'Trajet introuvable. Vérifiez les deux codes postaux.',
    'en': 'Trip not found. Check both postal codes.',
    'es': 'Trayecto no encontrado. Verifica los dos códigos postales.',
  },
  'error_busy': {
    'fr': 'Trop de demandes rapprochées. Réessayez dans quelques minutes.',
    'en': 'Too many requests. Try again in a few minutes.',
    'es': 'Demasiadas solicitudes. Inténtalo de nuevo en unos minutos.',
  },
  'error_other': {
    'fr':
        'L’estimation n’est pas disponible pour le moment. Vous pouvez obtenir votre prix exact tout de suite.',
    'en':
        'The estimate is not available right now. You can get your exact price right away.',
    'es':
        'El precio estimado no está disponible por ahora. Puedes obtener tu precio exacto de inmediato.',
  },
  'photo_prompt': {
    'fr': 'Touchez « Ajoutez une photo » pour prendre ou choisir la photo de votre objet.',
    'en': 'Tap “Add a photo” to take or choose a photo of your item.',
    'es': 'Toca «Añade una foto» para tomar o elegir la foto de tu objeto.',
  },
  'photo_loading': {
    'fr': 'Analyse de la photo…',
    'en': 'Analyzing the photo…',
    'es': 'Analizando la foto…',
  },
  'photo_found': {
    'fr': 'Reconnu : {label}. Poids choisi : {weight}.',
    'en': 'Recognized: {label}. Weight selected: {weight}.',
    'es': 'Reconocido: {label}. Peso elegido: {weight}.',
  },
  'photo_unsure': {
    'fr': 'On n’est pas certain de l’objet sur la photo. Choisissez le poids ci-dessus.',
    'en': 'We are not sure about the item in the photo. Choose the weight above.',
    'es': 'No estamos seguros del objeto de la foto. Elige el peso arriba.',
  },
  'photo_error': {
    'fr': 'La photo n’a pas pu être analysée. Choisissez le poids ci-dessus.',
    'en': 'The photo could not be analyzed. Choose the weight above.',
    'es': 'No se pudo analizar la foto. Elige el peso arriba.',
  },
  'nav_home': {'fr': 'Accueil', 'en': 'Home', 'es': 'Inicio'},
  'nav_delivery': {'fr': 'Livraison', 'en': 'Delivery', 'es': 'Entrega'},
  'nav_pricing': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
  'nav_how': {'fr': 'Comment ça marche', 'en': 'How it works', 'es': 'Cómo funciona'},
  'nav_faq': {'fr': 'FAQ', 'en': 'FAQ', 'es': 'Preguntas'},
  'km': {'fr': 'environ {km} km', 'en': 'about {km} km', 'es': 'unos {km} km'},
  'range': {'fr': '{low} \$ à {high} \$', 'en': '\${low} to \${high}', 'es': '{low} \$ a {high} \$'},
  'single': {'fr': 'environ {low} \$', 'en': 'about \${low}', 'es': 'unos {low} \$'},
  'driver': {'fr': 'Devenir chauffeur', 'en': 'Become a driver', 'es': 'Ser conductor'},
  'check_1': {
    'fr': 'Aucun compte pour voir l’estimation',
    'en': 'No account needed to see the estimate',
    'es': 'Sin cuenta para ver el precio estimado',
  },
  'check_2': {
    'fr': 'Dépôt de 25 \$ seulement à la réservation',
    'en': '\$25 deposit only when you book',
    'es': 'Depósito de 25 \$ solo al reservar',
  },
  'check_3': {
    'fr': 'Un chauffeur local avec le bon véhicule',
    'en': 'A local driver with the right vehicle',
    'es': 'Un conductor local con el vehículo adecuado',
  },
};

String _c(String key, String locale) => _copy[key]![locale] ?? _copy[key]!['fr']!;

const Map<String, String> _languageNames = {
  'fr': 'Français',
  'en': 'English',
  'es': 'Español',
};

/// Styles du formulaire, communs à la page d'estimation et à l'accueil léger.
const estimateFormCss =
    // Un bloc masqué le reste, même s'il a sa propre règle d'affichage.
    '.mk-est-form [hidden],.mk-est-page [hidden]{display:none!important}'
    '.mk-est-form{background:#fff;border-radius:16px;padding:18px;margin:18px 0;'
    'box-shadow:0 2px 10px rgba(15,42,92,.10);display:grid;gap:14px;max-width:460px}'
    '.mk-est-form h2{margin:0;font-size:18px;line-height:1.25}'
    '.mk-est-field{display:grid;gap:6px;font-size:13px;font-weight:600}'
    '.mk-est-field input{height:48px;box-sizing:border-box;border:1.5px solid #8A96AD;'
    'border-radius:10px;padding:0 14px;font:600 17px system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;'
    'color:#0F2A5C;letter-spacing:1px;text-transform:uppercase;width:100%}'
    '.mk-est-weights{border:0;margin:0;padding:0;min-width:0}'
    '.mk-est-weights legend{padding:0;margin-bottom:6px;font-size:13px;font-weight:600}'
    '.mk-est-opts{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}'
    '.mk-est-opt{position:relative;display:block;cursor:pointer}'
    '.mk-est-opt input{position:absolute;opacity:0;width:100%;height:100%;margin:0;cursor:pointer}'
    '.mk-est-opt span{display:block;min-height:64px;box-sizing:border-box;border:1.5px solid #8A96AD;'
    'border-radius:10px;padding:10px 4px;text-align:center;background:#fff}'
    '.mk-est-opt b{display:block;font-size:15px}'
    '.mk-est-opt small{display:block;font-size:11px;color:#3D4A66;font-weight:500}'
    '.mk-est-opt input:checked+span{border:2px solid #0F2A5C;background:#E6EDFA}'
    '.mk-est-opt input:focus-visible+span{outline:3px solid #0879E8;outline-offset:2px}'
    '.mk-est-photo{display:flex;align-items:center;justify-content:center;gap:10px;min-height:48px;'
    'box-sizing:border-box;border:1.5px dashed #0F2A5C;border-radius:10px;padding:6px 10px;'
    'font-size:14px;font-weight:600;color:#0F2A5C!important;text-decoration:none;background:#fff}'
    '.mk-est-photo-msg{margin:0;font-size:14px;font-weight:600;color:#1F6B3A}'
    '.mk-est-photo-msg.mk-est-plain{color:#3D4A66}'
    '.mk-est-photo-note{margin:0;font-size:12px;color:#54607A;text-align:center}'
    '.mk-est-btn{display:flex;align-items:center;justify-content:center;min-height:54px;width:100%;'
    'box-sizing:border-box;border:0;border-radius:12px;background:#0F2A5C;color:#fff!important;'
    'font:700 17px system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;text-decoration:none;cursor:pointer}'
    '.mk-est-btn[disabled]{opacity:.6;cursor:default}'
    '.mk-est-msg{margin:0;font-size:14px;color:#A33A2F;font-weight:600}';

const _cameraIcon =
    '<svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" '
    'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M3 8h4l2-3h6l2 3h4v11H3z"/><circle cx="12" cy="13" r="3.5"/></svg>';

/// Le formulaire d'estimation. Sans JavaScript, il ouvre la page
/// d'estimation avec ses champs dans l'adresse (`?de=…&a=…&poids=…`).
///
/// « Pas certain ? Ajoutez une photo » mène à la page d'estimation. Sur
/// cette page ([photoUpload]), le même bouton ouvre l'appareil photo : une
/// IA reconnaît l'objet et choisit le poids (Daniel, 2026-11-26).
String renderEstimateForm(String locale, {bool photoUpload = false}) {
  const postalPattern = r'[A-Za-z]\d[A-Za-z][ \-]?(\d[A-Za-z]\d)?';
  final b = StringBuffer()
    ..writeln(
      '<form class="mk-est-form" id="mk-est-form" action="${estimatePath(locale)}" method="get">',
    )
    ..writeln('  <h2>${_esc(_h('estimate_title', locale))}</h2>');
  for (final (name, key, autocomplete, example) in [
    ('de', 'estimate_from', 'postal-code', 'J2G 3V5'),
    ('a', 'estimate_to', 'off', 'J2L 1A1'),
  ]) {
    b.writeln(
      '  <label class="mk-est-field">${_esc(_h(key, locale))}'
      '<input name="$name" type="text" required maxlength="7" inputmode="text" '
      'autocapitalize="characters" autocomplete="$autocomplete" spellcheck="false" '
      'pattern="$postalPattern" placeholder="$example"></label>',
    );
  }
  b
    ..writeln('  <fieldset class="mk-est-weights">')
    ..writeln('    <legend>${_esc(_h('estimate_what', locale))}</legend>')
    ..writeln('    <div class="mk-est-opts">');
  for (final weight in estimateWeights) {
    b.writeln(
      '      <label class="mk-est-opt"><input type="radio" name="poids" value="$weight"'
      '${weight == 'medium' ? ' checked' : ''}>'
      '<span><b>${_esc(_h('estimate_$weight', locale))}</b>'
      '<small>${_esc(_h('estimate_${weight}_sub', locale))}</small></span></label>',
    );
  }
  b
    ..writeln('    </div>')
    ..writeln('  </fieldset>')
    ..writeln(
      '  <a class="mk-est-photo" id="mk-est-photo" href="${estimatePath(locale)}?photo=1">$_cameraIcon'
      '<span>${_esc(_h('estimate_photo', locale))}</span></a>',
    );
  if (photoUpload) {
    b
      ..writeln('  <input type="file" id="mk-est-file" accept="image/*" hidden>')
      ..writeln(
        '  <p class="mk-est-photo-msg" id="mk-est-photo-msg" role="status" hidden></p>',
      )
      ..writeln(
        '  <p class="mk-est-photo-note">${_esc(_h('estimate_photo_note', locale))}</p>',
      );
  }
  b
    ..writeln(
      '  <button class="mk-est-btn" type="submit">${_esc(_h('estimate_button', locale))}</button>',
    )
    ..writeln('  <p class="mk-est-msg" id="mk-est-msg" role="alert" hidden></p>')
    ..writeln('</form>');
  return b.toString();
}

const _pageCss =
    'body{margin:0;background:#F6F8FC;color:#0F2A5C;'
    'font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.45}'
    '.mk-est-page{max-width:460px;margin:0 auto;padding:0 20px 32px}'
    '.mk-est-page a{color:#0F2A5C}'
    '.mk-est-head{display:flex;justify-content:space-between;align-items:center;padding:14px 0}'
    '.mk-est-head a{font-size:14px;font-weight:600;text-decoration:none;padding:12px 0}'
    '.mk-est-head .mk-est-logo{font-size:20px;font-weight:800}'
    '.mk-est-page h1{margin:8px 0 10px;font-size:32px;line-height:1.1;font-weight:800}'
    '.mk-est-lead{margin:0;font-size:16px;color:#3D4A66}'
    '.mk-est-result{background:#fff;border-radius:16px;padding:20px;margin:18px 0;'
    'box-shadow:0 2px 10px rgba(15,42,92,.10);display:grid;gap:12px}'
    '.mk-est-result p{margin:0}'
    '.mk-est-route{font-size:15px;font-weight:600}'
    '.mk-est-label{font-size:13px;font-weight:600;color:#3D4A66;border-top:1px solid #DCE3F0;padding-top:12px}'
    '.mk-est-price{font-size:44px;line-height:1.05;font-weight:800}'
    '.mk-est-note{font-size:14px;color:#3D4A66}'
    '.mk-est-next-note{text-align:center;font-size:13px;color:#3D4A66}'
    '.mk-est-checks{list-style:none;margin:18px 0 0;padding:0;display:grid;gap:10px;font-size:14px;color:#3D4A66}'
    '.mk-est-checks li{display:flex;gap:10px;align-items:center}'
    '.mk-est-foot{margin-top:28px;font-size:13px;color:#3D4A66}'
    '.mk-est-foot a{margin-right:12px;display:inline-block;padding:6px 0}';

const _checkIcon =
    '<svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" '
    'stroke="#1F6B3A" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M4 12l5 5L20 6"/></svg>';

// Le script de la page. `C` (textes et adresses) est injecté juste avant.
const _script = r'''
(function () {
  var form = document.getElementById('mk-est-form');
  var msg = document.getElementById('mk-est-msg');
  var result = document.getElementById('mk-est-result');
  var next = document.getElementById('mk-est-next');
  if (!form || !result || !next) return;
  var button = form.querySelector('button[type="submit"]');
  var buttonLabel = button.textContent;
  var postal = /^([ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z])(\d[ABCEGHJ-NPRSTV-Z]\d)?$/;

  function norm(value) {
    var m = postal.exec(String(value || '').toUpperCase().replace(/[\s-]/g, ''));
    return m ? (m[2] ? m[1] + ' ' + m[2] : m[1]) : null;
  }
  function track(name, params) {
    try { if (window.gtag) window.gtag('event', name, params || {}); } catch (e) { /* mesure seulement */ }
    // Pixel Meta : une estimation affichée (inactif sans identifiant ni accord).
    try { if (name === 'estimate_shown' && window.movikMeta) window.movikMeta.track('EstimateShown'); } catch (e) { /* idem */ }
  }
  function say(text) {
    msg.textContent = text || '';
    msg.hidden = !text;
  }
  function fill(template, values) {
    return template.replace(/\{(\w+)\}/g, function (_, key) { return values[key]; });
  }
  function weight() {
    var checked = form.querySelector('input[name="poids"]:checked');
    return checked && C.weights.indexOf(checked.value) >= 0 ? checked.value : 'medium';
  }

  // Les paramètres de la publicité suivent le visiteur jusqu'à la demande.
  var keep = [];
  var query = new URLSearchParams(window.location.search);
  query.forEach(function (value, key) {
    if (/^utm_[a-z]+$/.test(key) || key === 'gclid' || key === 'fbclid' || key === 'msclkid') {
      keep.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
    }
  });
  if (keep.length) next.href = C.next + '?' + keep.join('&');
  next.addEventListener('click', function () { track('estimate_to_booking'); });

  var running = false;
  function estimate() {
    if (running) return;
    var from = norm(form.elements['de'].value);
    var to = norm(form.elements['a'].value);
    if (!from || !to) { say(C.invalid); return; }
    form.elements['de'].value = from;
    form.elements['a'].value = to;
    var w = weight();
    say('');
    running = true;
    button.disabled = true;
    button.textContent = C.loading;
    track('estimate_requested', { weight: w });
    fetch(C.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: { fromPostalCode: from, toPostalCode: to, weight: w } })
    }).then(function (response) {
      return response.json().then(function (body) { return body; }, function () { return {}; });
    }).then(function (body) {
      var r = body && body.result;
      if (!r || !(r.low_dollars > 0)) {
        var status = body && body.error && body.error.status;
        result.hidden = true;
        say(status === 'NOT_FOUND' ? C.errorRoute
          : status === 'INVALID_ARGUMENT' ? C.invalid
          : status === 'RESOURCE_EXHAUSTED' ? C.errorBusy : C.errorOther);
        track('estimate_error', { reason: status || 'unknown' });
        return;
      }
      document.getElementById('mk-est-from').textContent = from;
      document.getElementById('mk-est-to').textContent = to;
      document.getElementById('mk-est-km').textContent = fill(C.km, { km: r.distance_km });
      document.getElementById('mk-est-price').textContent = r.high_dollars > r.low_dollars
        ? fill(C.range, { low: r.low_dollars, high: r.high_dollars })
        : fill(C.single, { low: r.low_dollars });
      result.hidden = false;
      track('estimate_shown', { weight: w });
      if (result.scrollIntoView) result.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }).catch(function () {
      result.hidden = true;
      say(C.errorOther);
      track('estimate_error', { reason: 'network' });
    }).then(function () {
      running = false;
      button.disabled = false;
      button.textContent = buttonLabel;
    });
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    estimate();
  });

  // « Pas certain ? Ajoutez une photo » : la photo est réduite sur
  // l'appareil, envoyée à la fonction de reconnaissance, puis oubliée.
  var photoLink = document.getElementById('mk-est-photo');
  var fileInput = document.getElementById('mk-est-file');
  var photoMsg = document.getElementById('mk-est-photo-msg');
  var photoBusy = false;
  function sayPhoto(text, plain) {
    if (!photoMsg) return;
    photoMsg.textContent = text || '';
    photoMsg.hidden = !text;
    photoMsg.className = 'mk-est-photo-msg' + (plain ? ' mk-est-plain' : '');
  }
  function toJpeg(file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file);
      var image = new Image();
      image.onload = function () {
        var w = image.naturalWidth, h = image.naturalHeight;
        if (!w || !h) { URL.revokeObjectURL(url); reject(new Error('empty')); return; }
        var scale = Math.min(1, 1280 / Math.max(w, h));
        var canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(w * scale));
        canvas.height = Math.max(1, Math.round(h * scale));
        var context = canvas.getContext('2d');
        context.fillStyle = '#fff';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        var data = canvas.toDataURL('image/jpeg', 0.8);
        resolve(data.slice(data.indexOf(',') + 1));
      };
      image.onerror = function () { URL.revokeObjectURL(url); reject(new Error('format')); };
      image.src = url;
    });
  }
  function recognize(file) {
    if (photoBusy) return;
    photoBusy = true;
    sayPhoto(C.photoLoading, true);
    track('estimate_photo_requested');
    toJpeg(file).then(function (base64) {
      return fetch(C.photoUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: { imageBase64: base64, locale: C.locale, consent: true } })
      });
    }).then(function (response) {
      return response.json().then(function (body) { return body; }, function () { return {}; });
    }).then(function (body) {
      var r = body && body.result;
      if (!r || typeof r.label !== 'string') {
        var status = body && body.error && body.error.status;
        sayPhoto(status === 'RESOURCE_EXHAUSTED' ? C.errorBusy : C.photoError, true);
        track('estimate_photo_error', { reason: status || 'unknown' });
        return;
      }
      if (C.weights.indexOf(r.weight) < 0) {
        sayPhoto(C.photoUnsure, true);
        track('estimate_photo_unsure');
        return;
      }
      var radio = form.querySelector('input[name="poids"][value="' + r.weight + '"]');
      if (radio) radio.checked = true;
      sayPhoto(fill(C.photoFound, { label: r.label, weight: C.weightNames[r.weight] }));
      track('estimate_photo_recognized', { weight: r.weight });
      if (norm(form.elements['de'].value) && norm(form.elements['a'].value)) estimate();
    }).catch(function () {
      sayPhoto(C.photoError, true);
      track('estimate_photo_error', { reason: 'client' });
    }).then(function () { photoBusy = false; });
  }
  if (photoLink && fileInput) {
    photoLink.addEventListener('click', function (event) {
      event.preventDefault();
      fileInput.click();
    });
    fileInput.addEventListener('change', function () {
      var file = fileInput.files && fileInput.files[0];
      fileInput.value = '';
      if (file) recognize(file);
    });
    // Arrivée depuis une autre page par « Ajoutez une photo » : le navigateur
    // n'ouvre l'appareil photo que sur un geste, donc on montre où toucher.
    if (query.get('photo') === '1') {
      sayPhoto(C.photoPrompt, true);
      if (photoLink.focus) photoLink.focus();
    }
  }

  // Arrivée depuis l'accueil : le formulaire est déjà rempli dans l'adresse.
  var from = norm(query.get('de'));
  var to = norm(query.get('a'));
  var w = query.get('poids');
  if (C.weights.indexOf(w) >= 0) {
    var radio = form.querySelector('input[name="poids"][value="' + w + '"]');
    if (radio) radio.checked = true;
  }
  if (from) form.elements['de'].value = from;
  if (to) form.elements['a'].value = to;
  if (from && to) estimate();
})();
''';

/// Le bloc Google Analytics de index.html, repris tel quel (vide si absent).
String _analytics(String indexHtml) {
  final match = RegExp(
    r'<script async src="https://www\.googletagmanager\.com/gtag/js\?id=[^"]+"></script>\s*<script>[\s\S]*?</script>',
  ).firstMatch(indexHtml);
  return match == null ? '' : '  ${match.group(0)}\n';
}

/// La page d'estimation en [locale]. [indexHtml] ne sert qu'à reprendre la
/// mesure Google Analytics du site.
String renderEstimatePage(String indexHtml, String locale) {
  final title = _esc(_c('title', locale));
  final description = _esc(_c('description', locale));
  final driver = seoPages.firstWhere((p) => p.id == 'driver');
  final home = seoPages.firstWhere((p) => p.id == 'home');
  final config = jsonEncode({
    'url': estimateFunctionUrl,
    'next': '/$locale/livraison/demande',
    'weights': estimateWeights,
    'invalid': _h('estimate_invalid', locale),
    'loading': _c('loading', locale),
    'errorRoute': _c('error_route', locale),
    'errorBusy': _c('error_busy', locale),
    'errorOther': _c('error_other', locale),
    'photoUrl': estimatePhotoFunctionUrl,
    'locale': locale,
    'weightNames': {
      for (final weight in estimateWeights) weight: _h('estimate_$weight', locale),
    },
    'photoPrompt': _c('photo_prompt', locale),
    'photoLoading': _c('photo_loading', locale),
    'photoFound': _c('photo_found', locale),
    'photoUnsure': _c('photo_unsure', locale),
    'photoError': _c('photo_error', locale),
    'km': _c('km', locale),
    'range': _c('range', locale),
    'single': _c('single', locale),
  }).replaceAll('</', '<\\/');

  final b = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="$locale">')
    ..writeln('<head>')
    ..writeln('  <meta charset="UTF-8">')
    ..writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">')
    ..writeln('  <title>$title</title>')
    ..writeln('  <meta name="description" content="$description">')
    ..writeln('  <meta name="theme-color" content="#0F2A5C">')
    ..writeln('  <link rel="icon" type="image/png" href="/favicon.png">')
    ..writeln('  <link rel="canonical" href="${estimateUrl(locale)}">');
  for (final l in seoLocales) {
    b.writeln('  <link rel="alternate" hreflang="$l" href="${estimateUrl(l)}">');
  }
  b
    ..writeln('  <link rel="alternate" hreflang="x-default" href="${estimateUrl('fr')}">')
    ..writeln('  <meta property="og:type" content="website">')
    ..writeln('  <meta property="og:site_name" content="Movi-K">')
    ..writeln('  <meta property="og:title" content="$title">')
    ..writeln('  <meta property="og:description" content="$description">')
    ..writeln('  <meta property="og:url" content="${estimateUrl(locale)}">')
    ..writeln('  <meta property="og:image" content="$seoSiteUrl/icons/Icon-512.png">')
    ..write(_analytics(indexHtml))
    // Pixel Meta (web/meta_pixel.js) : la page d'arrivée des publicités doit
    // le charger elle-même, puisqu'elle ne charge pas l'application. Rien
    // n'est envoyé sans l'accord du visiteur.
    ..writeln('  <script src="/meta_pixel.js" defer></script>')
    ..writeln('  <style>$_pageCss$estimateFormCss</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<main class="mk-est-page">')
    ..writeln('  <div class="mk-est-head">')
    ..writeln('    <a class="mk-est-logo" href="${home.path(locale)}">Movi-K</a>')
    ..writeln(
      '    <a href="${driver.path(locale)}">${_esc(_c('driver', locale))}</a>',
    )
    ..writeln('  </div>')
    ..writeln('  <h1>${_esc(_c('heading', locale))}</h1>')
    ..writeln('  <p class="mk-est-lead">${_esc(_h('estimate_note', locale))}</p>')
    ..write(renderEstimateForm(locale, photoUpload: true))
    ..writeln('  <section class="mk-est-result" id="mk-est-result" aria-live="polite" hidden>')
    ..writeln(
      '    <p class="mk-est-route"><span id="mk-est-from"></span> → '
      '<span id="mk-est-to"></span> · <span id="mk-est-km"></span></p>',
    )
    ..writeln('    <p class="mk-est-label">${_esc(_c('result_label', locale))}</p>')
    ..writeln('    <p class="mk-est-price" id="mk-est-price"></p>')
    ..writeln(
      '    <p class="mk-est-note">${_esc(_c('taxes', locale))} ${_esc(_c('result_note', locale))}</p>',
    )
    ..writeln(
      '    <a class="mk-est-btn" id="mk-est-next" href="/$locale/livraison/demande">'
      '${_esc(_c('next', locale))}</a>',
    )
    ..writeln('    <p class="mk-est-next-note">${_esc(_c('next_note', locale))}</p>')
    ..writeln('  </section>')
    ..writeln('  <ul class="mk-est-checks">');
  for (final key in ['check_1', 'check_2', 'check_3']) {
    b.writeln('    <li>$_checkIcon<span>${_esc(_c(key, locale))}</span></li>');
  }
  b.writeln('  </ul>');
  // Liens vers le reste du site : la page ne charge pas le menu de l'application.
  b.write('  <nav class="mk-est-foot">');
  b.write('<a href="${home.path(locale)}">${_esc(_c('nav_home', locale))}</a>');
  for (final (id, key) in [
    ('delivery', 'nav_delivery'),
    ('pricing', 'nav_pricing'),
    ('how', 'nav_how'),
    ('faq', 'nav_faq'),
    ('driver', 'driver'),
  ]) {
    final target = seoPages.firstWhere((p) => p.id == id);
    b.write('<a href="${target.path(locale)}">${_esc(_c(key, locale))}</a>');
  }
  b
    ..writeln('</nav>')
    ..writeln('  <p class="mk-est-foot">Movi-K · <a href="mailto:$seoContactEmail">$seoContactEmail</a></p>')
    ..write('  <p class="mk-est-foot">');
  for (final l in seoLocales) {
    b.write('<a href="${estimatePath(l)}" hreflang="$l" lang="$l">${_languageNames[l]}</a>');
  }
  b
    ..writeln('</p>')
    ..writeln('</main>')
    ..writeln('<script>var C = $config;$_script</script>')
    ..writeln('</body>')
    ..writeln('</html>');
  return b.toString();
}

/// Les trois pages d'estimation : chemin du fichier → HTML.
Map<String, String> renderAllEstimatePages(String indexHtml) => {
  for (final locale in seoLocales) estimateFile(locale): renderEstimatePage(indexHtml, locale),
};
