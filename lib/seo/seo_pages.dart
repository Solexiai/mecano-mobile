// -----------------------------------------------------------------------------
// seo_pages.dart — les pages publiques telles que Google et les IA (ChatGPT,
// Claude, Perplexity…) les lisent (Daniel, 2026-11-10).
//
// movi-k.com est une app Flutter : sans ce fichier, chaque adresse renvoie la
// même coquille vide. Au build Vercel, tool/build_seo_pages.dart écrit une
// vraie page HTML par adresse (titre, description, texte, données
// structurées) à partir d'ici ; l'app prend ensuite le relais à l'écran.
// Le texte reprend celui des écrans (lib/screens/info, accueil, chauffeur) :
// si un écran change, changer aussi sa page ici. Les questions fréquentes
// viennent de lib/content/faq_content.dart (une seule source).
//
// Dart pur : pas d'import Flutter (le script de build tourne avec `dart run`).
// -----------------------------------------------------------------------------

import '../l10n/app_strings.dart';
import '../l10n/home_copy.dart';

const seoLocales = ['fr', 'en', 'es'];
const seoSiteUrl = 'https://movi-k.com';
const seoContactEmail = 'infos@movi-k.com';

typedef SeoText = Map<String, String>;

SeoText _l(String fr, String en, String es) => {'fr': fr, 'en': en, 'es': es};
SeoText _home(String key) => {
  for (final l in seoLocales) l: HomeCopy.text(key, l).replaceAll('\n', ' '),
};

class SeoSection {
  const SeoSection(this.heading, this.body);
  final SeoText heading;
  final SeoText body;
}

class SeoPage {
  const SeoPage({
    required this.id,
    required this.paths,
    required this.titles,
    required this.descriptions,
    required this.headings,
    required this.intros,
    this.sections = const [],
    this.faq = false,
  });

  final String id;
  final SeoText paths;
  final SeoText titles;
  final SeoText descriptions;
  final SeoText headings;
  final SeoText intros;
  final List<SeoSection> sections;

  /// Page des questions fréquentes : ses questions viennent de faqItems().
  final bool faq;

  String path(String locale) => paths[locale] ?? paths['fr']!;
  String url(String locale) => '$seoSiteUrl${path(locale)}';

  /// Fichier généré au build, servi par vercel.json à la place de index.html.
  String file(String locale) => '/seo${path(locale)}.html';
}

final List<SeoPage> seoPages = [
  SeoPage(
    id: 'home',
    paths: _l('/fr', '/en', '/es'),
    titles: {for (final l in seoLocales) l: AppStrings.t('seo_default_title', l)},
    descriptions: {
      for (final l in seoLocales) l: AppStrings.t('seo_default_description', l),
    },
    headings: _home('title'),
    intros: _home('intro'),
    sections: [
      SeoSection(_home('step1'), _home('step1_body')),
      SeoSection(_home('step2'), _home('step2_body')),
      SeoSection(_home('step3'), _home('step3_body')),
      SeoSection(_home('step4'), _home('step4_body')),
      SeoSection(
        _l('Ce que vous pouvez faire livrer', 'What you can have delivered', 'Lo que puedes transportar'),
        _l(
          'Meubles (divan, lit, commode, table…), électroménagers (réfrigérateur, laveuse, cuisinière…), téléviseurs, pneus, souffleuse ou tondeuse, meubles de patio et BBQ, vélos, boîtes, achats Marketplace et matériaux de construction.',
          'Furniture (sofa, bed, dresser, table…), appliances (refrigerator, washer, stove…), TVs, tires, snow blower or lawn mower, patio furniture and BBQ, bikes, boxes, Marketplace purchases and construction materials.',
          'Muebles (sofá, cama, cómoda, mesa…), electrodomésticos (refrigerador, lavadora, estufa…), televisores, neumáticos, quitanieves o cortacésped, muebles de patio y parrilla, bicicletas, cajas, compras de Marketplace y materiales de construcción.',
        ),
      ),
      SeoSection(_home('reassurance_local'), _home('granby_launch')),
    ],
  ),
  SeoPage(
    id: 'delivery',
    paths: _l('/fr/livraison', '/en/delivery', '/es/entrega'),
    titles: _l(
      'Livraison de meubles, électroménagers et gros objets | Movi-K',
      'Delivery of furniture, appliances and large items | Movi-K',
      'Entrega de muebles, electrodomésticos y objetos grandes | Movi-K',
    ),
    descriptions: _l(
      'Faites livrer ce qui ne rentre pas dans votre véhicule : meubles, électroménagers, boîtes, achats Marketplace. Une photo, le prix exact, un chauffeur de la région.',
      'Get what doesn’t fit in your car delivered: furniture, appliances, boxes, Marketplace purchases. One photo, the exact price, a local driver.',
      'Haz entregar lo que no cabe en tu vehículo: muebles, electrodomésticos, cajas, compras de Marketplace. Una foto, el precio exacto, un conductor local.',
    ),
    headings: _home('title'),
    intros: _home('intro'),
    sections: [
      SeoSection(
        _l('Ce que vous pouvez faire livrer', 'What you can have delivered', 'Lo que puedes transportar'),
        _l(
          'Prenez une photo : on reconnaît l’objet pour vous. Votre objet n’est pas dans la liste ? Choisissez « Autre objet ».',
          'Snap a photo and we recognize the item for you. Item not in the list? Choose “Other item”.',
          'Toma una foto y reconocemos el objeto por ti. ¿Tu objeto no está en la lista? Elige «Otro objeto».',
        ),
      ),
      SeoSection(
        _l('Un prix clair, sans surprise', 'A clear price, no surprises', 'Un precio claro, sin sorpresas'),
        _l(
          'Le prix affiché est le prix payé, détail inclus. Vous le voyez avant de confirmer.',
          'The price shown is the price you pay, breakdown included. You see it before confirming.',
          'El precio mostrado es el que pagas, con el desglose. Lo ves antes de confirmar.',
        ),
      ),
      SeoSection(
        _l('GPS en direct', 'Live GPS', 'GPS en directo'),
        _l(
          'Suivez votre chauffeur en direct sur la carte pendant la livraison.',
          'Follow your driver live on the map during the delivery.',
          'Sigue a tu conductor en directo en el mapa durante la entrega.',
        ),
      ),
      SeoSection(_home('step3'), _home('step3_body')),
    ],
  ),
  SeoPage(
    id: 'pricing',
    paths: _l('/fr/tarifs', '/en/pricing', '/es/precios'),
    titles: _l(
      'Tarifs : le prix exact avant de réserver | Movi-K',
      'Pricing: the exact price before you book | Movi-K',
      'Precios: el precio exacto antes de reservar | Movi-K',
    ),
    descriptions: _l(
      'Comment Movi-K calcule le prix d’une livraison : trajet, type d’objet, options, frais de service, TPS et TVQ. Dépôt de 25 \$ à la réservation, solde après la livraison.',
      'How Movi-K prices a delivery: route, item type, options, service fee, GST and QST. \$25 deposit when you book, balance after delivery.',
      'Cómo Movi-K calcula el precio de una entrega: trayecto, tipo de objeto, opciones, cargo de servicio, TPS y TVQ. Depósito de 25 \$ al reservar, saldo después de la entrega.',
    ),
    headings: _l('Un prix clair, avant de réserver', 'A clear price, before you book', 'Un precio claro, antes de reservar'),
    intros: _l(
      'Prenez une photo, entrez vos adresses : vous voyez le prix exact, taxes et détail inclus, avant de confirmer.',
      'Snap a photo, enter your addresses: you see the exact price, taxes and breakdown included, before you confirm.',
      'Toma una foto, indica tus direcciones: ves el precio exacto, con impuestos y desglose, antes de confirmar.',
    ),
    sections: [
      SeoSection(
        _l('Le trajet', 'The route', 'El trayecto'),
        _l(
          'La distance et la durée entre le ramassage et la livraison.',
          'The distance and time between pickup and delivery.',
          'La distancia y la duración entre la recogida y la entrega.',
        ),
      ),
      SeoSection(
        _l('Le type d’objet', 'The type of item', 'El tipo de objeto'),
        _l(
          'Un supplément de manutention peut s’ajouter pour les objets lourds, comme un réfrigérateur ou un divan.',
          'A handling supplement may apply to heavy items, such as a refrigerator or a sofa.',
          'Puede añadirse un suplemento de manipulación para objetos pesados, como un refrigerador o un sofá.',
        ),
      ),
      SeoSection(
        _l('Les options', 'Options', 'Las opciones'),
        _l(
          'L’aide au chargement, les escaliers ou un 2e déménageur, seulement si vous les demandez.',
          'Loading help, stairs or a second mover, only if you ask for them.',
          'Ayuda con la carga, escaleras o un segundo mozo, solo si los pides.',
        ),
      ),
      SeoSection(
        _l('Frais de service et taxes', 'Service fee and taxes', 'Cargo de servicio e impuestos'),
        _l(
          'Les frais de service, la TPS et la TVQ sont affichés dans le détail du prix.',
          'The service fee, GST and QST are shown in the price breakdown.',
          'El cargo de servicio, la TPS y la TVQ se muestran en el desglose del precio.',
        ),
      ),
      SeoSection(
        _l('Votre prix ne bouge pas', 'Your price does not change', 'Tu precio no cambia'),
        _l(
          'Le prix que vous acceptez est figé : il ne change pas après la réservation. Si vous attendez trop longtemps avant de confirmer, un nouveau prix est calculé.',
          'The price you accept is locked: it does not change after booking. If you wait too long before confirming, a new price is calculated.',
          'El precio que aceptas queda fijado: no cambia después de reservar. Si esperas demasiado antes de confirmar, se calcula un nuevo precio.',
        ),
      ),
      SeoSection(
        _l('Quand votre carte est-elle débitée ?', 'When is your card charged?', '¿Cuándo se cobra tu tarjeta?'),
        _l(
          'Un dépôt de 25 \$ est débité quand vous réservez ; il est déduit du prix total. Quand un chauffeur accepte, le solde est réservé sur votre carte (une autorisation, pas un débit). Après la livraison, seul le solde du prix accepté est débité.',
          'A \$25 deposit is charged when you book; it is deducted from the total price. When a driver accepts, the balance is held on your card (an authorization, not a charge). After delivery, only the balance of the accepted price is charged.',
          'Al reservar se cobra un depósito de 25 \$, que se descuenta del precio total. Cuando un conductor acepta, el saldo se reserva en tu tarjeta (una autorización, no un cobro). Después de la entrega solo se cobra el saldo del precio aceptado.',
        ),
      ),
      SeoSection(
        _l('Annulation', 'Cancellation', 'Cancelación'),
        _l(
          'Sans frais avant qu’un chauffeur accepte, ou plus de 48 heures avant le ramassage : votre dépôt est remboursé. Si un chauffeur a accepté et que le ramassage est dans moins de 48 heures, le dépôt de 25 \$ est gardé. Si le chauffeur se déplace pour rien, des frais de 30 \$ s’appliquent.',
          'No charge before a driver accepts, or more than 48 hours before pickup: your deposit is refunded. If a driver has accepted and pickup is less than 48 hours away, the \$25 deposit is kept. If the driver makes a wasted trip, a \$30 fee applies.',
          'Sin costo antes de que un conductor acepte, o más de 48 horas antes de la recogida: se reembolsa tu depósito. Si un conductor ya aceptó y la recogida es en menos de 48 horas, se conserva el depósito de 25 \$. Si el conductor se desplaza en vano, se aplica un cargo de 30 \$.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'how',
    paths: _l('/fr/comment-ca-marche', '/en/how-it-works', '/es/como-funciona'),
    titles: _l(
      'Comment ça marche : une photo, un prix, un chauffeur | Movi-K',
      'How it works: one photo, one price, one driver | Movi-K',
      'Cómo funciona: una foto, un precio, un conductor | Movi-K',
    ),
    descriptions: _l(
      'Les 4 étapes d’une livraison Movi-K : prenez une photo, voyez le prix exact, un chauffeur de la région accepte, suivez votre livraison en direct.',
      'The 4 steps of a Movi-K delivery: snap a photo, see the exact price, a local driver accepts, follow your delivery live.',
      'Los 4 pasos de una entrega Movi-K: toma una foto, ve el precio exacto, un conductor local acepta, sigue tu entrega en vivo.',
    ),
    headings: _l('Comment ça marche', 'How it works', 'Cómo funciona'),
    intros: _home('quote_note'),
    sections: [
      SeoSection(_home('step1'), _home('step1_body')),
      SeoSection(_home('step2'), _home('step2_body')),
      SeoSection(_home('step3'), _home('step3_body')),
      SeoSection(_home('step4'), _home('step4_body')),
      SeoSection(
        _l('Suivi des étapes et GPS', 'Status tracking and GPS', 'Seguimiento de etapas y GPS'),
        _l(
          'Chaque étape de votre livraison est visible dans votre espace client, avec la position de votre chauffeur sur une carte en direct pendant la livraison.',
          'Every step of your delivery is visible in your customer account, with your driver’s position on a live map during the delivery.',
          'Cada etapa de tu entrega es visible en tu cuenta de cliente, con la ubicación de tu conductor en un mapa en vivo durante la entrega.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'safety',
    paths: _l('/fr/securite', '/en/safety', '/es/seguridad'),
    titles: _l(
      'Sécurité : chauffeurs vérifiés et paiement protégé | Movi-K',
      'Safety: verified drivers and protected payment | Movi-K',
      'Seguridad: conductores verificados y pago protegido | Movi-K',
    ),
    descriptions: _l(
      'Comment Movi-K protège vos objets, votre paiement et vos données : chauffeurs vérifiés, photos au ramassage et à la livraison, paiement sécurisé par Stripe.',
      'How Movi-K protects your items, your payment and your data: verified drivers, photos at pickup and delivery, secure payment through Stripe.',
      'Cómo Movi-K protege tus objetos, tu pago y tus datos: conductores verificados, fotos al recoger y entregar, pago seguro con Stripe.',
    ),
    headings: _l('Sécurité', 'Safety', 'Seguridad'),
    intros: _l(
      'Comment Movi‑K protège vos objets, votre paiement et vos données.',
      'How Movi‑K protects your items, your payment and your data.',
      'Cómo Movi‑K protege tus objetos, tu pago y tus datos.',
    ),
    sections: [
      SeoSection(
        _l('Chauffeurs vérifiés', 'Verified drivers', 'Conductores verificados'),
        _l(
          'Chaque chauffeur fournit son permis de conduire, son assurance et les informations de son véhicule. L’équipe Movi‑K approuve son dossier avant qu’il puisse recevoir des demandes.',
          'Every driver provides their driver’s licence, insurance and vehicle details. The Movi‑K team approves their file before they can receive requests.',
          'Cada conductor presenta su licencia de conducir, su seguro y los datos de su vehículo. El equipo de Movi‑K aprueba su expediente antes de que pueda recibir solicitudes.',
        ),
      ),
      SeoSection(
        _l('Photos au ramassage et à la livraison', 'Photos at pickup and delivery', 'Fotos al recoger y al entregar'),
        _l(
          'Le chauffeur prend une photo de vos objets au ramassage, puis à la livraison. Vous les voyez dans votre espace : elles servent de preuve en cas de problème.',
          'The driver takes a photo of your items at pickup, then at delivery. You see them in your account: they serve as proof if something goes wrong.',
          'El conductor toma una foto de tus objetos al recogerlos y al entregarlos. Las ves en tu cuenta: sirven de prueba si hay un problema.',
        ),
      ),
      SeoSection(
        _l('Paiement protégé', 'Protected payment', 'Pago protegido'),
        _l(
          'Votre carte est enregistrée sur la page sécurisée de Stripe : Movi‑K ne voit jamais votre numéro de carte. Un dépôt de 25 \$ est débité à la réservation ; le solde n’est débité qu’après la livraison.',
          'Your card is saved on Stripe’s secure page: Movi‑K never sees your card number. A \$25 deposit is charged when you book; the balance is only charged after delivery.',
          'Tu tarjeta se guarda en la página segura de Stripe: Movi‑K nunca ve tu número de tarjeta. Al reservar se cobra un depósito de 25 \$; el saldo solo se cobra después de la entrega.',
        ),
      ),
      SeoSection(
        _l('Position partagée pendant la livraison', 'Location shared during the delivery', 'Ubicación compartida durante la entrega'),
        _l(
          'Vous voyez la position de votre chauffeur seulement pendant votre livraison en cours. Une fois la livraison terminée, elle n’est plus visible.',
          'You see your driver’s location only during your delivery in progress. Once the delivery is completed, it is no longer visible.',
          'Ves la ubicación de tu conductor solo durante tu entrega en curso. Una vez terminada la entrega, deja de ser visible.',
        ),
      ),
      SeoSection(
        _l('Objets exclus', 'Excluded items', 'Artículos excluidos'),
        _l(
          'Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus du service.',
          'Hazardous materials, illegal goods, live animals and items requiring special permits are excluded from the service.',
          'Se excluyen los materiales peligrosos, bienes ilegales, animales vivos y objetos que requieren permisos especiales.',
        ),
      ),
      SeoSection(
        _l('Urgences', 'Emergencies', 'Emergencias'),
        _l(
          'Movi‑K n’est pas un service d’urgence. En cas de danger immédiat, d’accident ou de problème médical, composez le 911.',
          'Movi‑K is not an emergency service. In case of immediate danger, an accident or a medical issue, call 911.',
          'Movi‑K no es un servicio de emergencia. En caso de peligro inmediato, accidente o problema médico, llama al 911.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'faq',
    paths: _l('/fr/faq', '/en/faq', '/es/faq'),
    titles: _l(
      'Questions fréquentes sur la livraison | Movi-K',
      'Delivery FAQ | Movi-K',
      'Preguntas frecuentes sobre la entrega | Movi-K',
    ),
    descriptions: _l(
      'Prix, paiement, dépôt de 25 \$, annulation, objets acceptés, suivi, chauffeurs vérifiés : tout ce qu’il faut savoir avant de réserver une livraison Movi-K.',
      'Price, payment, \$25 deposit, cancellation, accepted items, tracking, verified drivers: everything to know before booking a Movi-K delivery.',
      'Precio, pago, depósito de 25 \$, cancelación, objetos aceptados, seguimiento, conductores verificados: todo lo que hay que saber antes de reservar una entrega Movi-K.',
    ),
    headings: _l('Questions fréquentes', 'Frequently asked questions', 'Preguntas frecuentes'),
    intros: _l(
      'Tout ce qu’il faut savoir avant de réserver.',
      'Everything you need to know before booking.',
      'Todo lo que necesitas saber antes de reservar.',
    ),
    faq: true,
  ),
  SeoPage(
    id: 'granby',
    paths: _l('/fr/granby', '/en/granby', '/es/granby'),
    titles: _l(
      'Livraison de meubles et électroménagers à Granby | Movi-K',
      'Furniture and appliance delivery in Granby | Movi-K',
      'Entrega de muebles y electrodomésticos en Granby | Movi-K',
    ),
    descriptions: _l(
      'Un divan, un réfrigérateur ou des boîtes à faire livrer à Granby ou dans les environs ? Prenez une photo, voyez le prix exact et réservez avec un chauffeur de la région.',
      'A sofa, a refrigerator or boxes to deliver in or around Granby? Snap a photo, see the exact price and book with a local driver.',
      '¿Un sofá, un refrigerador o cajas para entregar en Granby o alrededores? Toma una foto, ve el precio exacto y reserva con un conductor local.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Granby.',
      'Furniture and appliance delivery in Granby.',
      'Entrega de muebles y electrodomésticos en Granby.',
    ),
    intros: _l(
      'Un divan acheté sur Marketplace, un réfrigérateur, des boîtes ou des matériaux : un chauffeur de la région s’en occupe. Prenez une photo, voyez le prix exact et réservez en ligne.',
      'A sofa bought on Marketplace, a refrigerator, boxes or materials: a local driver takes care of it. Snap a photo, see the exact price and book online.',
      'Un sofá comprado en Marketplace, un refrigerador, cajas o materiales: un conductor de la zona se encarga. Toma una foto, ve el precio exacto y reserva en línea.',
    ),
    sections: [
      SeoSection(
        _l('Zone desservie', 'Service area', 'Zona de servicio'),
        _l(
          'Granby et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
          'Granby and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
          'Granby y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
        ),
      ),
      SeoSection(
        _l('Commencez sans compte', 'Start without an account', 'Empieza sin cuenta'),
        _home('quote_note'),
      ),
      SeoSection(
        _l('Une question ?', 'A question?', '¿Una pregunta?'),
        _l(
          'Écrivez-nous à infos@movi-k.com ou depuis la page Contact.',
          'Write to us at infos@movi-k.com or from the Contact page.',
          'Escríbenos a infos@movi-k.com o desde la página de Contacto.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'driver',
    paths: _l('/fr/devenir-chauffeur', '/en/become-driver', '/es/convertirse-conductor'),
    titles: _l(
      'Devenir chauffeur-livreur avec votre pickup ou camion | Movi-K',
      'Become a delivery driver with your pickup or truck | Movi-K',
      'Hazte conductor de entregas con tu camioneta o camión | Movi-K',
    ),
    descriptions: _l(
      'Vous avez une camionnette, un fourgon, un camion cube ou une remorque ? Livrez avec Movi-K quand vous êtes disponible, à la mission, dans votre zone.',
      'Have a pickup, cargo van, box truck or trailer? Deliver with Movi-K when you are available, per mission, in your area.',
      '¿Tienes una camioneta, un furgón, un camión caja o un remolque? Entrega con Movi-K cuando estés disponible, por misión, en tu zona.',
    ),
    headings: {
      for (final l in seoLocales) l: AppStrings.t('driver_hero_headline', l),
    },
    intros: {for (final l in seoLocales) l: AppStrings.t('driver_hero_sub', l)},
    sections: [
      SeoSection(
        _l('Horaire flexible', 'Flexible schedule', 'Horario flexible'),
        _l('Passez en ligne lorsque vous êtes disponible.', 'Go online when you are available.', 'Conéctate cuando estés disponible.'),
      ),
      SeoSection(
        _l('Choisissez vos demandes', 'Choose your requests', 'Elige tus solicitudes'),
        _l('N’acceptez que les livraisons qui vous conviennent.', 'Accept only deliveries that suit you.', 'Acepta solo las entregas que te convengan.'),
      ),
      SeoSection(
        _l('Définissez votre zone', 'Set your service area', 'Define tu zona'),
        _l('Indiquez votre rayon de service dans votre profil chauffeur.', 'Set your service radius in your driver profile.', 'Indica tu radio de servicio en tu perfil de conductor.'),
      ),
      SeoSection(
        _l('Véhicules admissibles', 'Eligible vehicles', 'Vehículos admisibles'),
        _l(
          'Camionnette, fourgon cargo, camion cube, remorque, VUS avec remorque, véhicule commercial léger.',
          'Pickup truck, cargo van, box truck, trailer, SUV with trailer, light commercial vehicle.',
          'Camioneta, furgón de carga, camión caja, remolque, SUV con remolque, vehículo comercial ligero.',
        ),
      ),
      SeoSection(
        _l('Dossier à approuver', 'Application review required', 'Expediente sujeto a aprobación'),
        _l(
          'Le profil, le véhicule et les documents requis doivent être approuvés avant l’activation. Aucun revenu n’est garanti.',
          'Your profile, vehicle and required documents must be approved before activation. No income is guaranteed.',
          'El perfil, el vehículo y los documentos requeridos deben aprobarse antes de la activación. No se garantiza ningún ingreso.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'about',
    paths: _l('/fr/a-propos', '/en/about', '/es/acerca-de'),
    titles: _l(
      'À propos de Movi-K | Livraison locale de gros objets',
      'About Movi-K | Local delivery of large items',
      'Acerca de Movi-K | Entrega local de objetos grandes',
    ),
    descriptions: _l(
      'Movi-K connecte les gens à des chauffeurs locaux de confiance pour transporter les objets trop gros ou difficiles à déplacer soi-même. Né à Granby.',
      'Movi-K connects people with trusted local drivers to move items too big or hard to move yourself. Born in Granby.',
      'Movi-K conecta a las personas con conductores locales de confianza para transportar objetos demasiado grandes o difíciles de mover. Nacido en Granby.',
    ),
    headings: _l('À propos de Movi-K', 'About Movi-K', 'Acerca de Movi-K'),
    intros: _l(
      'Connecter les gens à des chauffeurs locaux de confiance pour transporter les objets trop gros ou difficiles à déplacer soi-même.',
      'Connecting people with trusted local drivers to transport items that are too large or difficult to move on their own.',
      'Conectar a las personas con conductores locales de confianza para transportar artículos demasiado grandes o difíciles de mover por cuenta propia.',
    ),
    sections: [
      SeoSection(
        _l('Local', 'Local', 'Local'),
        _l(
          'Né à Granby, Movi‑K livre partout où un chauffeur est disponible.',
          'Born in Granby, Movi‑K delivers wherever a driver is available.',
          'Nacido en Granby, Movi‑K entrega dondequiera que haya un conductor disponible.',
        ),
      ),
      SeoSection(
        _l('Fiable', 'Reliable', 'Confiable'),
        _l(
          'Des dossiers chauffeurs soumis à vérification avant activation.',
          'Driver applications are reviewed before activation.',
          'Los expedientes de conductores se revisan antes de la activación.',
        ),
      ),
      SeoSection(
        _l('Transparent', 'Transparent', 'Transparente'),
        _l(
          'Prix et progression de la mission présentés clairement.',
          'Prices and mission progress are presented clearly.',
          'El precio y el progreso de la misión se presentan claramente.',
        ),
      ),
    ],
  ),
  SeoPage(
    id: 'contact',
    paths: _l('/fr/contact', '/en/contact', '/es/contacto'),
    titles: _l('Contact | Movi-K', 'Contact | Movi-K', 'Contacto | Movi-K'),
    descriptions: _l(
      'Une question sur votre livraison ou le service Movi-K ? Écrivez-nous à infos@movi-k.com.',
      'A question about your delivery or the Movi-K service? Email us at infos@movi-k.com.',
      '¿Una pregunta sobre tu entrega o el servicio Movi-K? Escríbenos a infos@movi-k.com.',
    ),
    headings: _l('Contactez Movi-K', 'Contact Movi-K', 'Contacta con Movi-K'),
    intros: _l(
      'Pour une question sur votre demande ou le service, écrivez-nous à infos@movi-k.com. Si vous avez une référence de demande, indiquez-la dans votre message.',
      'For questions about your request or the service, email us at infos@movi-k.com. If you have a request reference, include it in your message.',
      'Si tienes preguntas sobre tu solicitud o el servicio, escríbenos a infos@movi-k.com. Si tienes una referencia de solicitud, inclúyela en tu mensaje.',
    ),
  ),
];

/// La page publique servie à cette adresse, ou null (pages privées, légales…).
SeoPage? seoPageForPath(String path) {
  var clean = path.split('?').first.split('#').first;
  if (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  for (final page in seoPages) {
    for (final locale in seoLocales) {
      if (page.path(locale) == clean) return page;
    }
  }
  return null;
}

/// Langue d'une adresse de page publique, ex. '/en/pricing' → 'en'.
String? seoLocaleForPath(String path) {
  final page = seoPageForPath(path);
  if (page == null) return null;
  var clean = path.split('?').first.split('#').first;
  if (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  for (final locale in seoLocales) {
    if (page.path(locale) == clean) return locale;
  }
  return null;
}
