// Questions fréquentes de Movi-K — une seule source pour la page FAQ de
// l'app et pour les pages lues par Google et les IA (tool/build_seo_pages.dart,
// llms.txt, données structurées FAQPage). Dart pur : pas d'import Flutter.
//
// Les réponses suivent ce que fait le produit le 10 nov. 2026 : photo + IA,
// dépôt de 25 $ débité à la réservation et déduit du total
// (functions/src/lib/bookingDeposit.ts), solde réservé à l'acceptation puis
// débité après la livraison, dépôt remboursé si aucun chauffeur n'accepte ou
// si le client annule avant l'acceptation ou plus de 48 h avant le
// ramassage, frais de 30 $ si le chauffeur se déplace pour rien
// (missionFees.ts). Pas de limite de distance depuis le 11 nov. 2026 :
// chaque chauffeur reçoit les livraisons dans le rayon qu'il a choisi.
// Aucun horaire ni jour n'est écrit ici : l'administration peut les changer.

String _pick(String locale, String fr, String en, String es) =>
    locale == 'en' ? en : locale == 'es' ? es : fr;

/// (question, réponse) dans la langue demandée (fr par défaut).
List<(String, String)> faqItems(String locale) => <(String, String)>[
      (
        _pick(
          locale,
          'Comment obtenir un prix ?',
          'How do I get a price?',
          '¿Cómo obtengo un precio?',
        ),
        _pick(
          locale,
          'Prenez une photo de vos objets : on les reconnaît pour vous. Ajoutez les adresses de ramassage et de livraison, le moment voulu et l’aide nécessaire. Le prix exact s’affiche, taxes et détail inclus, avant que vous confirmiez.',
          'Snap a photo of your items and we recognize them for you. Add the pickup and delivery addresses, the time you want and the help you need. The exact price is shown, taxes and breakdown included, before you confirm.',
          'Toma una foto de tus objetos y los reconocemos por ti. Añade las direcciones de recogida y entrega, el momento deseado y la ayuda necesaria. El precio exacto se muestra, con impuestos y desglose, antes de confirmar.',
        ),
      ),
      (
        _pick(
          locale,
          'Dois-je créer un compte ?',
          'Do I need an account?',
          '¿Necesito una cuenta?',
        ),
        _pick(
          locale,
          'Vous pouvez commencer sans compte. La connexion est demandée pour obtenir votre prix et réserver. Ce que vous avez déjà rempli est gardé 24 heures.',
          'You can start without an account. Sign-in is required to get your price and book. What you have already filled in is kept for 24 hours.',
          'Puedes empezar sin cuenta. Se pide iniciar sesión para obtener tu precio y reservar. Lo que ya completaste se guarda 24 horas.',
        ),
      ),
      (
        _pick(
          locale,
          'Quels objets pouvez-vous livrer ?',
          'What items can you deliver?',
          '¿Qué objetos pueden transportar?',
        ),
        _pick(
          locale,
          'Meubles (divan, lit, commode, table…), électroménagers (réfrigérateur, laveuse, cuisinière…), téléviseurs, pneus, souffleuse ou tondeuse, meubles de patio et BBQ, vélos, boîtes et matériaux de construction. Votre objet n’est pas dans la liste ? Choisissez « Autre objet ». Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus.',
          'Furniture (sofa, bed, dresser, table…), appliances (refrigerator, washer, stove…), TVs, tires, snow blower or lawn mower, patio furniture and BBQ, bikes, boxes and construction materials. Item not in the list? Choose “Other item”. Hazardous materials, illegal goods, live animals and items requiring special permits are excluded.',
          'Muebles (sofá, cama, cómoda, mesa…), electrodomésticos (refrigerador, lavadora, estufa…), televisores, neumáticos, quitanieves o cortacésped, muebles de patio y parrilla, bicicletas, cajas y materiales de construcción. ¿Tu objeto no está en la lista? Elige «Otro objeto». Se excluyen materiales peligrosos, bienes ilegales, animales vivos y objetos que requieren permisos especiales.',
        ),
      ),
      (
        _pick(
          locale,
          'Dois-je mesurer mes objets ?',
          'Do I need to measure my items?',
          '¿Debo medir mis objetos?',
        ),
        _pick(
          locale,
          'Non. Le chauffeur voit vos photos et confirme que tout entre dans son véhicule avant d’accepter votre demande.',
          'No. The driver sees your photos and confirms everything fits in their vehicle before accepting your request.',
          'No. El conductor ve tus fotos y confirma que todo cabe en su vehículo antes de aceptar tu solicitud.',
        ),
      ),
      (
        _pick(
          locale,
          'Quand ma livraison peut-elle avoir lieu ?',
          'When can my delivery happen?',
          '¿Cuándo puede hacerse mi entrega?',
        ),
        _pick(
          locale,
          'Choisissez « Dès que possible », ou un jour et une heure parmi les créneaux offerts, quelques jours à l’avance. L’heure est confirmée quand un chauffeur accepte votre demande.',
          'Choose “As soon as possible”, or a day and a time among the slots offered, a few days ahead. The time is confirmed when a driver accepts your request.',
          'Elige «Lo antes posible», o un día y una hora entre las franjas ofrecidas, con unos días de antelación. La hora se confirma cuando un conductor acepta tu solicitud.',
        ),
      ),
      (
        _pick(
          locale,
          'Est-ce que je choisis mon chauffeur ?',
          'Do I choose my driver?',
          '¿Elijo al conductor?',
        ),
        _pick(
          locale,
          'Non. Votre demande est envoyée aux chauffeurs vérifiés de la région. Le premier qui accepte s’occupe de votre livraison.',
          'No. Your request is sent to verified drivers in the area. The first one to accept handles your delivery.',
          'No. Tu solicitud se envía a los conductores verificados de la zona. El primero que acepta se encarga de tu entrega.',
        ),
      ),
      (
        _pick(
          locale,
          'Comment et quand vais-je payer ?',
          'How and when do I pay?',
          '¿Cómo y cuándo pago?',
        ),
        _pick(
          locale,
          'Par carte, sur la page sécurisée de Stripe. Un dépôt de 25 \$ est débité quand vous réservez : il est déduit du prix total. Quand un chauffeur accepte, le solde est réservé sur votre carte, puis débité après la livraison.',
          'By card, on Stripe’s secure page. A \$25 deposit is charged when you book: it is deducted from the total price. When a driver accepts, the balance is held on your card, then charged after delivery.',
          'Con tarjeta, en la página segura de Stripe. Al reservar se cobra un depósito de 25 \$, que se descuenta del precio total. Cuando un conductor acepta, el saldo se reserva en tu tarjeta y se cobra después de la entrega.',
        ),
      ),
      (
        _pick(
          locale,
          'Le prix peut-il changer ?',
          'Can the price change?',
          '¿Puede cambiar el precio?',
        ),
        _pick(
          locale,
          'Non, une fois que vous l’avez accepté. Par mauvais temps (tempête, verglas), un supplément peut s’ajouter au prix : il est indiqué, avec sa raison, avant que vous confirmiez.',
          'No, once you have accepted it. In bad weather (storm, freezing rain), a supplement may be added to the price: it is shown, with its reason, before you confirm.',
          'No, una vez que lo aceptas. Con mal tiempo (tormenta, hielo), puede añadirse un suplemento al precio: se indica, con su motivo, antes de confirmar.',
        ),
      ),
      (
        _pick(
          locale,
          'Et si aucun chauffeur n’accepte ?',
          'What if no driver accepts?',
          '¿Y si ningún conductor acepta?',
        ),
        _pick(
          locale,
          'Votre dépôt de 25 \$ vous est remboursé et rien d’autre n’est débité : le solde n’est réservé qu’au moment où un chauffeur accepte.',
          'Your \$25 deposit is refunded and nothing else is charged: the balance is only held when a driver accepts.',
          'Se te reembolsa el depósito de 25 \$ y no se cobra nada más: el saldo solo se reserva cuando un conductor acepta.',
        ),
      ),
      (
        _pick(
          locale,
          'Puis-je annuler ?',
          'Can I cancel?',
          '¿Puedo cancelar?',
        ),
        _pick(
          locale,
          'Oui. Votre dépôt de 25 \$ est remboursé si vous annulez avant qu’un chauffeur accepte, ou plus de 48 heures avant le ramassage. Si un chauffeur a accepté et que le ramassage est dans moins de 48 heures, le dépôt est gardé. Si le chauffeur se déplace pour rien, des frais de 30 \$ s’appliquent.',
          'Yes. Your \$25 deposit is refunded if you cancel before a driver accepts, or more than 48 hours before pickup. If a driver has accepted and pickup is less than 48 hours away, the deposit is kept. If the driver makes a wasted trip, a \$30 fee applies.',
          'Sí. Tu depósito de 25 \$ se reembolsa si cancelas antes de que un conductor acepte, o más de 48 horas antes de la recogida. Si un conductor ya aceptó y la recogida es en menos de 48 horas, el depósito se conserva. Si el conductor se desplaza en vano, se aplica un cargo de 30 \$.',
        ),
      ),
      (
        _pick(
          locale,
          'Comment suivre ma livraison ?',
          'How do I follow my delivery?',
          '¿Cómo sigo mi entrega?',
        ),
        _pick(
          locale,
          'Dans votre espace, vous voyez chaque étape, la position du chauffeur sur la carte pendant la livraison, puis les photos prises au ramassage et à la livraison.',
          'In your account, you see each step, the driver’s position on the map during the delivery, then the photos taken at pickup and delivery.',
          'En tu cuenta ves cada etapa, la ubicación del conductor en el mapa durante la entrega y luego las fotos tomadas al recoger y al entregar.',
        ),
      ),
      (
        _pick(
          locale,
          'Comment les chauffeurs sont-ils vérifiés ?',
          'How are drivers verified?',
          '¿Cómo se verifican los conductores?',
        ),
        _pick(
          locale,
          'Chaque chauffeur fournit son permis de conduire, son assurance et les informations de son véhicule. L’équipe Movi‑K approuve son dossier avant qu’il puisse recevoir des demandes.',
          'Every driver provides their driver’s licence, insurance and vehicle details. The Movi‑K team approves their file before they can receive requests.',
          'Cada conductor presenta su licencia de conducir, su seguro y los datos de su vehículo. El equipo de Movi‑K aprueba su expediente antes de que pueda recibir solicitudes.',
        ),
      ),
      (
        _pick(
          locale,
          'Où le service est-il offert ?',
          'Where is the service offered?',
          '¿Dónde se ofrece el servicio?',
        ),
        _pick(
          locale,
          'Partout, sans limite de distance : votre livraison a lieu dès qu’un chauffeur près de votre adresse de ramassage l’accepte. Si aucun chauffeur n’accepte, votre dépôt de 25 \$ est remboursé.',
          'Everywhere, with no distance limit: your delivery happens as soon as a driver near your pickup address accepts it. If no driver accepts, your \$25 deposit is refunded.',
          'En todas partes, sin límite de distancia: tu entrega se realiza en cuanto un conductor cerca de tu dirección de recogida la acepta. Si ningún conductor acepta, se reembolsa tu depósito de 25 \$.',
        ),
      ),
      (
        _pick(
          locale,
          'Comment devenir chauffeur ?',
          'How do I become a driver?',
          '¿Cómo me hago conductor?',
        ),
        _pick(
          locale,
          'Vous avez un pickup, une fourgonnette ou un camion cube ? Inscrivez-vous depuis la page « Devenir chauffeur » et envoyez vos documents. Vous recevrez des demandes une fois votre dossier approuvé.',
          'Do you have a pickup, a van or a box truck? Sign up from the “Become a Driver” page and send your documents. You will receive requests once your file is approved.',
          '¿Tienes una camioneta pickup, una furgoneta o un camión de caja? Inscríbete desde la página «Convertirse en conductor» y envía tus documentos. Recibirás solicitudes una vez aprobado tu expediente.',
        ),
      ),
];
