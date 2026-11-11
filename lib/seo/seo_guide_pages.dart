// -----------------------------------------------------------------------------
// Pages par objet et par ville (Daniel, 11 nov. 2026 : « fais déborder mon
// référencement »). Chaque page a un contenu propre (ce qu’on transporte,
// comment le préparer, secteurs voisins) : pas de pages copiées où seul le
// nom change, que Google traite comme des pages satellites.
// Servies par SeoGuideScreen dans l’app et par tool/build_seo_pages.dart pour
// les robots, avec le même texte. Les règles (prix, dépôt, escaliers,
// remboursement) suivent lib/content/faq_content.dart et la page Tarifs.
// Une nouvelle vague de villes : ajouter ici, puis vercel.json et
// web/sitemap.xml (les tests vérifient les trois).
// -----------------------------------------------------------------------------

part of 'seo_pages.dart';

final _guidePrice = SeoSection(
  _l(
      'Le prix exact, avant de réserver',
      'The exact price, before you book',
      'El precio exacto, antes de reservar',
    ),
  _l(
      'Le prix dépend du trajet, du type d’objet et des options. Vous le voyez, taxes et détail inclus, avant de confirmer. Un dépôt de 25 \$ est débité à la réservation et déduit du total ; le solde est débité après la livraison.',
      'The price depends on the route, the type of item and the options. You see it, taxes and breakdown included, before you confirm. A \$25 deposit is charged when you book and deducted from the total; the balance is charged after delivery.',
      'El precio depende del trayecto, del tipo de objeto y de las opciones. Lo ves, con impuestos y desglose, antes de confirmar. Al reservar se cobra un depósito de 25 \$, que se descuenta del total; el saldo se cobra después de la entrega.',
    ),
);

final _guideDriver = SeoSection(
  _l(
      'Un chauffeur vérifié près de chez vous',
      'A verified driver near you',
      'Un conductor verificado cerca de ti',
    ),
  _l(
      'Votre demande est envoyée aux chauffeurs vérifiés près de l’adresse de ramassage. Le chauffeur voit vos photos et confirme que tout entre dans son véhicule avant d’accepter. Si aucun chauffeur n’accepte, votre dépôt est remboursé.',
      'Your request goes to verified drivers near the pickup address. The driver sees your photos and confirms everything fits in their vehicle before accepting. If no driver accepts, your deposit is refunded.',
      'Tu solicitud se envía a los conductores verificados cerca de la dirección de recogida. El conductor ve tus fotos y confirma que todo cabe en su vehículo antes de aceptar. Si ningún conductor acepta, se reembolsa tu depósito.',
    ),
);

final _objectAccess = SeoSection(
  _l(
      'Escaliers et accès',
      'Stairs and access',
      'Escaleras y acceso',
    ),
  _l(
      'Indiquez les étages, les escaliers et les accès difficiles dans votre demande. L’aide au chargement, les escaliers ou un 2e déménageur s’ajoutent au prix seulement si vous les demandez, et vous les voyez avant de confirmer.',
      'Mention floors, stairs and difficult access in your request. Loading help, stairs or a second mover are added to the price only if you ask for them, and you see them before you confirm.',
      'Indica los pisos, las escaleras y los accesos difíciles en tu solicitud. La ayuda con la carga, las escaleras o un segundo mozo se suman al precio solo si los pides, y los ves antes de confirmar.',
    ),
);

final _objectWhatHeading = _l(
      'Ce qu’on transporte',
      'What we move',
      'Lo que transportamos',
    );

final _objectPrepareHeading = _l(
      'Bien le préparer',
      'How to get it ready',
      'Cómo prepararlo',
    );

final _cityAreaHeading = _l(
      'Secteurs desservis',
      'Areas served',
      'Zonas atendidas',
    );

final _cityWhat = _l(
      'Meubles, électroménagers, matelas, téléviseurs, souffleuses et tondeuses, BBQ, matériaux de construction, achats en magasin ou sur Marketplace. Prenez une photo : on reconnaît l’objet pour vous.',
      'Furniture, appliances, mattresses, TVs, snow blowers and mowers, BBQs, construction materials, store or Marketplace purchases. Snap a photo and we recognize the item for you.',
      'Muebles, electrodomésticos, colchones, televisores, quitanieves y cortacéspedes, parrillas, materiales de construcción, compras en tienda o en Marketplace. Toma una foto y reconocemos el objeto por ti.',
    );


/// Une page par type d’objet : /fr/transport/…, /en/transport/…, /es/transporte/….
final List<SeoPage> seoObjectPages = [

  SeoPage(
    id: 'object_fridge',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/refrigerateur', '/en/transport/refrigerator', '/es/transporte/refrigerador'),
    labels: _l(
      'Réfrigérateur',
      'Refrigerator',
      'Refrigerador',
    ),
    titles: _l(
      'Transport de réfrigérateur avec un chauffeur local | Movi-K',
      'Refrigerator delivery with a local driver | Movi-K',
      'Transporte de refrigerador con un conductor local | Movi-K',
    ),
    descriptions: _l(
      'Un réfrigérateur à déplacer, neuf ou acheté sur Marketplace ? Prenez une photo, voyez le prix exact et un chauffeur avec camion le livre chez vous.',
      'A refrigerator to move, new or bought on Marketplace? Snap a photo, see the exact price and a driver with a truck brings it to your door.',
      '¿Un refrigerador que mover, nuevo o comprado en Marketplace? Toma una foto, ve el precio exacto y un conductor con camioneta lo lleva a tu casa.',
    ),
    headings: _l(
      'Transport de réfrigérateur',
      'Refrigerator delivery',
      'Transporte de refrigerador',
    ),
    intros: _l(
      'Un réfrigérateur ne rentre pas dans une auto et pèse lourd. Un chauffeur de la région vient le chercher au magasin, chez le vendeur ou chez vous, et le dépose à la bonne adresse.',
      'A refrigerator won’t fit in a car and it’s heavy. A local driver picks it up at the store, at the seller’s or at your place, and drops it off at the right address.',
      'Un refrigerador no cabe en un auto y pesa mucho. Un conductor de la zona lo recoge en la tienda, en casa del vendedor o en la tuya, y lo deja en la dirección correcta.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Réfrigérateur standard, côte à côte ou à portes françaises, mini-frigo, frigo de bar ou de garage. Ajoutez la cuisinière, le congélateur ou d’autres objets dans la même demande.',
      'Standard, side-by-side or French-door refrigerators, mini fridges, bar or garage fridges. Add the stove, the freezer or other items to the same request.',
      'Refrigerador estándar, de dos puertas o de puertas francesas, minibar, refrigerador de bar o de garaje. Añade la estufa, el congelador u otros objetos en la misma solicitud.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Videz-le et retirez ou fixez les tablettes et les bacs. Débranchez-le la veille pour qu’il dégivre, épongez l’eau et collez les portes avec un ruban qui ne laisse pas de traces. À l’arrivée, attendez avant de le rebrancher, surtout s’il a voyagé couché : suivez le guide du fabricant.',
      'Empty it and remove or secure the shelves and bins. Unplug it the day before so it defrosts, wipe up the water and tape the doors shut with tape that leaves no marks. On arrival, wait before plugging it back in, especially if it travelled lying down: follow the manufacturer’s guide.',
      'Vacíalo y retira o asegura las bandejas y los cajones. Desconéctalo la víspera para que se descongele, seca el agua y cierra las puertas con cinta que no deje marcas. Al llegar, espera antes de volver a enchufarlo, sobre todo si viajó acostado: sigue la guía del fabricante.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_washer',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/laveuse-secheuse', '/en/transport/washer-dryer', '/es/transporte/lavadora-secadora'),
    labels: _l(
      'Laveuse et sécheuse',
      'Washer and dryer',
      'Lavadora y secadora',
    ),
    titles: _l(
      'Transport de laveuse et sécheuse sans louer de camion | Movi-K',
      'Washer and dryer delivery, no truck rental | Movi-K',
      'Transporte de lavadora y secadora sin alquilar camión | Movi-K',
    ),
    descriptions: _l(
      'Une laveuse ou une sécheuse à faire livrer ? Une photo suffit : vous voyez le prix exact, taxes incluses, et un chauffeur vérifié s’occupe du transport.',
      'A washer or dryer to deliver? One photo is enough: you see the exact price, taxes included, and a verified driver handles the move.',
      '¿Una lavadora o secadora que transportar? Basta una foto: ves el precio exacto, con impuestos, y un conductor verificado se encarga del traslado.',
    ),
    headings: _l(
      'Transport de laveuse et de sécheuse',
      'Washer and dryer delivery',
      'Transporte de lavadora y secadora',
    ),
    intros: _l(
      'Une laveuse neuve à rapporter du magasin, une paire laveuse-sécheuse achetée d’occasion ou un déménagement d’appartement : un chauffeur avec le bon véhicule s’en occupe.',
      'A new washer from the store, a used washer-dryer pair or an apartment move: a driver with the right vehicle takes care of it.',
      'Una lavadora nueva de la tienda, un par lavadora-secadora de segunda mano o una mudanza de apartamento: un conductor con el vehículo adecuado se encarga.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Laveuse à chargement frontal ou par le haut, sécheuse, ensemble superposé, laveuse compacte. Les deux appareils peuvent voyager dans la même demande.',
      'Front-load or top-load washers, dryers, stacked sets, compact washers. Both machines can travel in the same request.',
      'Lavadora de carga frontal o superior, secadora, conjunto apilable, lavadora compacta. Los dos aparatos pueden viajar en la misma solicitud.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Fermez l’eau, débranchez les boyaux et videz l’eau qui reste dans la laveuse. Si vous avez gardé les boulons de transport, remettez-les : ils bloquent le tambour pendant la route. Une sécheuse au gaz doit être débranchée par une personne qualifiée.',
      'Turn off the water, disconnect the hoses and drain the water left in the washer. If you kept the shipping bolts, put them back: they lock the drum on the road. A gas dryer must be disconnected by a qualified person.',
      'Cierra el agua, desconecta las mangueras y vacía el agua que queda en la lavadora. Si guardaste los pernos de transporte, vuelve a ponerlos: bloquean el tambor durante el trayecto. Una secadora a gas debe desconectarla una persona calificada.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_stove',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/cuisiniere-lave-vaisselle', '/en/transport/stove-dishwasher', '/es/transporte/estufa-lavavajillas'),
    labels: _l(
      'Cuisinière et lave-vaisselle',
      'Stove and dishwasher',
      'Estufa y lavavajillas',
    ),
    titles: _l(
      'Transport de cuisinière ou de lave-vaisselle | Movi-K',
      'Stove and dishwasher delivery | Movi-K',
      'Transporte de estufa o lavavajillas | Movi-K',
    ),
    descriptions: _l(
      'Cuisinière, four encastrable ou lave-vaisselle à faire livrer ? Prenez une photo, voyez le prix exact avant de réserver et un chauffeur de la région s’en charge.',
      'A stove, wall oven or dishwasher to deliver? Snap a photo, see the exact price before you book and a local driver takes care of it.',
      '¿Una estufa, un horno empotrado o un lavavajillas que transportar? Toma una foto, ve el precio exacto antes de reservar y un conductor local se encarga.',
    ),
    headings: _l(
      'Transport de cuisinière et de lave-vaisselle',
      'Stove and dishwasher delivery',
      'Transporte de estufa y lavavajillas',
    ),
    intros: _l(
      'Une cuisinière neuve, un lave-vaisselle à remplacer ou des électroménagers de cuisine achetés en lot : un chauffeur vient les chercher et les livre à votre porte.',
      'A new stove, a dishwasher to replace or kitchen appliances bought as a set: a driver picks them up and delivers them to your door.',
      'Una estufa nueva, un lavavajillas que reemplazar o electrodomésticos de cocina comprados en lote: un conductor los recoge y los entrega en tu puerta.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Cuisinière électrique ou au gaz, four encastrable, plaque de cuisson, hotte, lave-vaisselle, four à micro-ondes de comptoir.',
      'Electric or gas stoves, wall ovens, cooktops, range hoods, dishwashers, countertop microwaves.',
      'Estufa eléctrica o a gas, horno empotrado, placa de cocina, campana, lavavajillas, microondas de encimera.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Videz le four et retirez les grilles et le tiroir. Une cuisinière électrique se débranche simplement ; une cuisinière au gaz doit être débranchée par une personne qualifiée. Pour un lave-vaisselle, fermez l’eau, débranchez le boyau et videz l’eau qui reste.',
      'Empty the oven and remove the racks and drawer. An electric stove simply unplugs; a gas stove must be disconnected by a qualified person. For a dishwasher, turn off the water, disconnect the hose and drain the remaining water.',
      'Vacía el horno y retira las rejillas y el cajón. Una estufa eléctrica simplemente se desenchufa; una estufa a gas debe desconectarla una persona calificada. Para un lavavajillas, cierra el agua, desconecta la manguera y vacía el agua que queda.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_freezer',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/congelateur', '/en/transport/freezer', '/es/transporte/congelador'),
    labels: _l(
      'Congélateur',
      'Freezer',
      'Congelador',
    ),
    titles: _l(
      'Transport de congélateur coffre ou vertical | Movi-K',
      'Chest or upright freezer delivery | Movi-K',
      'Transporte de congelador horizontal o vertical | Movi-K',
    ),
    descriptions: _l(
      'Un congélateur coffre ou vertical à déménager ou à aller chercher ? Prenez une photo, voyez le prix exact et réservez un chauffeur avec le bon véhicule.',
      'A chest or upright freezer to move or pick up? Snap a photo, see the exact price and book a driver with the right vehicle.',
      '¿Un congelador horizontal o vertical que mudar o recoger? Toma una foto, ve el precio exacto y reserva un conductor con el vehículo adecuado.',
    ),
    headings: _l(
      'Transport de congélateur',
      'Freezer delivery',
      'Transporte de congelador',
    ),
    intros: _l(
      'Un congélateur pour le sous-sol, le garage ou le chalet est lourd et encombrant. Un chauffeur de la région le transporte pour vous, du magasin ou du vendeur jusqu’à chez vous.',
      'A freezer for the basement, garage or cottage is heavy and bulky. A local driver moves it for you, from the store or the seller to your home.',
      'Un congelador para el sótano, el garaje o la cabaña es pesado y voluminoso. Un conductor de la zona lo transporta por ti, de la tienda o del vendedor hasta tu casa.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Congélateur coffre, congélateur vertical, congélateur de garage, réfrigérateur-congélateur d’appoint.',
      'Chest freezers, upright freezers, garage freezers, backup fridge-freezers.',
      'Congelador horizontal, congelador vertical, congelador de garaje, refrigerador-congelador de apoyo.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Videz-le, débranchez-le la veille et laissez-le dégivrer, puis épongez l’eau. Fixez le couvercle ou les portes avec du ruban. À l’arrivée, attendez avant de le rebrancher et laissez-le refroidir avant de le remplir, selon le guide du fabricant.',
      'Empty it, unplug it the day before and let it defrost, then wipe up the water. Tape the lid or doors shut. On arrival, wait before plugging it back in and let it cool down before filling it, as the manufacturer’s guide says.',
      'Vacíalo, desconéctalo la víspera y deja que se descongele; luego seca el agua. Asegura la tapa o las puertas con cinta. Al llegar, espera antes de volver a enchufarlo y deja que se enfríe antes de llenarlo, según la guía del fabricante.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_sofa',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/divan-sofa', '/en/transport/sofa', '/es/transporte/sofa'),
    labels: _l(
      'Divan et sectionnel',
      'Sofa and sectional',
      'Sofá y seccional',
    ),
    titles: _l(
      'Livraison de divan, sofa ou sectionnel | Movi-K',
      'Sofa and sectional delivery | Movi-K',
      'Entrega de sofá o seccional | Movi-K',
    ),
    descriptions: _l(
      'Un divan, un sofa-lit ou un sectionnel trop gros pour votre auto ? Prenez une photo, voyez le prix exact et un chauffeur vérifié le livre chez vous.',
      'A sofa, sofa bed or sectional too big for your car? Snap a photo, see the exact price and a verified driver delivers it to your home.',
      '¿Un sofá, sofá cama o seccional demasiado grande para tu auto? Toma una foto, ve el precio exacto y un conductor verificado lo lleva a tu casa.',
    ),
    headings: _l(
      'Livraison de divan et de sectionnel',
      'Sofa and sectional delivery',
      'Entrega de sofá y seccional',
    ),
    intros: _l(
      'Le divan parfait trouvé sur Marketplace, un sectionnel que le magasin ne livre pas assez vite ou un sofa à donner à un proche : un chauffeur de la région le transporte pour vous.',
      'The perfect sofa found on Marketplace, a sectional the store can’t deliver soon enough or a couch to give to a relative: a local driver moves it for you.',
      'El sofá perfecto encontrado en Marketplace, un seccional que la tienda no entrega a tiempo o un sofá para regalar a un familiar: un conductor de la zona lo transporta por ti.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Divan, causeuse, sofa-lit, sectionnel en plusieurs morceaux, fauteuil inclinable, futon.',
      'Sofas, loveseats, sofa beds, multi-piece sectionals, recliners, futons.',
      'Sofá, sofá de dos plazas, sofá cama, seccional de varias piezas, sillón reclinable, futón.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Retirez les coussins et les pattes qui se dévissent : un sectionnel voyage mieux en morceaux. Selon le véhicule du chauffeur, la boîte peut être ouverte : s’il pleut ou s’il neige, emballez le divan dans du plastique. Mesurez les portes et les cages d’escalier à l’arrivée.',
      'Remove the cushions and any legs that unscrew: a sectional travels better in pieces. Depending on the driver’s vehicle, the box may be open: if it rains or snows, wrap the sofa in plastic. Measure the doors and stairwells at the destination.',
      'Retira los cojines y las patas que se desatornillan: un seccional viaja mejor en piezas. Según el vehículo del conductor, la caja puede ir abierta: si llueve o nieva, envuelve el sofá en plástico. Mide las puertas y las escaleras en el destino.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_bed',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/lit-matelas', '/en/transport/bed-mattress', '/es/transporte/cama-colchon'),
    labels: _l(
      'Lit et matelas',
      'Bed and mattress',
      'Cama y colchón',
    ),
    titles: _l(
      'Livraison de matelas, lit ou sommier | Movi-K',
      'Mattress, bed and box spring delivery | Movi-K',
      'Entrega de colchón, cama o somier | Movi-K',
    ),
    descriptions: _l(
      'Un matelas, un sommier ou un lit complet à faire livrer, neuf ou usagé ? Prenez une photo, voyez le prix exact et réservez un chauffeur de la région.',
      'A mattress, box spring or full bed to deliver, new or used? Snap a photo, see the exact price and book a local driver.',
      '¿Un colchón, un somier o una cama completa que entregar, nuevos o usados? Toma una foto, ve el precio exacto y reserva un conductor local.',
    ),
    headings: _l(
      'Livraison de lit et de matelas',
      'Bed and mattress delivery',
      'Entrega de cama y colchón',
    ),
    intros: _l(
      'Un matelas roulé dans sa boîte rentre parfois dans l’auto ; un matelas king, un sommier ou une base de lit, rarement. Un chauffeur s’en charge, du magasin ou du vendeur jusqu’à chez vous.',
      'A rolled mattress in its box sometimes fits in a car; a king mattress, a box spring or a bed frame rarely does. A driver takes care of it, from the store or the seller to your home.',
      'Un colchón enrollado en su caja a veces cabe en el auto; un colchón king, un somier o una base de cama, casi nunca. Un conductor se encarga, de la tienda o del vendedor hasta tu casa.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Matelas de toutes tailles, sommier, base de lit, lit superposé, lit de bébé, tête de lit, lit ajustable.',
      'Mattresses of every size, box springs, bed frames, bunk beds, cribs, headboards, adjustable beds.',
      'Colchones de todos los tamaños, somier, base de cama, litera, cuna, cabecero, cama ajustable.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Glissez le matelas dans une housse ou un grand sac de plastique pour le garder propre et au sec. Démontez la base du lit et gardez les vis dans un sac collé au cadre.',
      'Slip the mattress into a cover or a large plastic bag to keep it clean and dry. Take the bed frame apart and keep the screws in a bag taped to the frame.',
      'Mete el colchón en una funda o una bolsa grande de plástico para mantenerlo limpio y seco. Desarma la base de la cama y guarda los tornillos en una bolsa pegada al marco.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_dresser',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/commode-armoire', '/en/transport/dresser-wardrobe', '/es/transporte/comoda-armario'),
    labels: _l(
      'Commode et armoire',
      'Dresser and wardrobe',
      'Cómoda y armario',
    ),
    titles: _l(
      'Transport de commode, armoire ou bibliothèque | Movi-K',
      'Dresser, wardrobe and bookcase delivery | Movi-K',
      'Transporte de cómoda, armario o librero | Movi-K',
    ),
    descriptions: _l(
      'Une commode, une armoire, une bibliothèque ou une table à déplacer ? Prenez une photo, voyez le prix exact et un chauffeur de la région la livre chez vous.',
      'A dresser, wardrobe, bookcase or table to move? Snap a photo, see the exact price and a local driver delivers it to your home.',
      '¿Una cómoda, un armario, un librero o una mesa que mover? Toma una foto, ve el precio exacto y un conductor local la lleva a tu casa.',
    ),
    headings: _l(
      'Transport de commode, d’armoire et de bibliothèque',
      'Dresser, wardrobe and bookcase delivery',
      'Transporte de cómoda, armario y librero',
    ),
    intros: _l(
      'Un meuble en bois massif trouvé sur Marketplace, l’armoire de grand-maman ou la nouvelle bibliothèque du magasin : un chauffeur de la région les transporte pour vous.',
      'Solid wood furniture found on Marketplace, grandma’s wardrobe or the new bookcase from the store: a local driver moves them for you.',
      'Un mueble de madera maciza de Marketplace, el armario de la abuela o el librero nuevo de la tienda: un conductor de la zona los transporta por ti.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Commode, armoire, bibliothèque, buffet, meuble télé, table et chaises, bureau, coiffeuse.',
      'Dressers, wardrobes, bookcases, sideboards, TV stands, tables and chairs, desks, vanities.',
      'Cómoda, armario, librero, aparador, mueble de TV, mesa y sillas, escritorio, tocador.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Videz les tiroirs ou fixez-les avec du ruban ou une pellicule plastique. Retirez les miroirs et le verre et emballez-les à part. Une bibliothèque haute voyage mieux vide et, si possible, démontée.',
      'Empty the drawers or secure them with tape or plastic wrap. Remove mirrors and glass and wrap them separately. A tall bookcase travels better empty and, if possible, taken apart.',
      'Vacía los cajones o asegúralos con cinta o film plástico. Retira los espejos y el vidrio y envuélvelos aparte. Un librero alto viaja mejor vacío y, si es posible, desarmado.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_tv',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/televiseur', '/en/transport/tv', '/es/transporte/televisor'),
    labels: _l(
      'Téléviseur',
      'TV',
      'Televisor',
    ),
    titles: _l(
      'Transport de téléviseur grand écran | Movi-K',
      'Big-screen TV delivery | Movi-K',
      'Transporte de televisor de pantalla grande | Movi-K',
    ),
    descriptions: _l(
      'Un grand téléviseur ou un meuble télé à faire livrer ? Prenez une photo, voyez le prix exact et réservez un chauffeur de la région en quelques minutes.',
      'A big TV or TV stand to deliver? Snap a photo, see the exact price and book a local driver in a few minutes.',
      '¿Un televisor grande o un mueble de TV que entregar? Toma una foto, ve el precio exacto y reserva un conductor local en pocos minutos.',
    ),
    headings: _l(
      'Transport de téléviseur',
      'TV delivery',
      'Transporte de televisor',
    ),
    intros: _l(
      'Un téléviseur de 65 pouces voyage mal sur la banquette arrière. Un chauffeur vient le chercher au magasin ou chez le vendeur et le livre chez vous.',
      'A 65-inch TV doesn’t travel well on the back seat. A driver picks it up at the store or the seller’s and delivers it to your home.',
      'Un televisor de 65 pulgadas no viaja bien en el asiento trasero. Un conductor lo recoge en la tienda o en casa del vendedor y lo entrega en tu casa.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Téléviseur de toutes tailles, meuble télé, barre de son et caisson, écran de projection, moniteur.',
      'TVs of every size, TV stands, sound bars and subwoofers, projector screens, monitors.',
      'Televisores de todos los tamaños, muebles de TV, barras de sonido y subwoofers, pantallas de proyección, monitores.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Utilisez la boîte d’origine si vous l’avez gardée ; sinon, protégez l’écran avec une couverture épaisse. Retirez le pied ou le support mural et gardez les vis avec la télé. Un écran plat voyage debout, jamais à plat sur l’écran.',
      'Use the original box if you kept it; otherwise protect the screen with a thick blanket. Remove the stand or wall mount and keep the screws with the TV. A flat screen travels upright, never lying on its screen.',
      'Usa la caja original si la guardaste; si no, protege la pantalla con una manta gruesa. Retira el pie o el soporte de pared y guarda los tornillos con el televisor. Una pantalla plana viaja de pie, nunca acostada sobre la pantalla.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_yard',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/souffleuse-tondeuse', '/en/transport/snow-blower-lawn-mower', '/es/transporte/quitanieves-cortacesped'),
    labels: _l(
      'Souffleuse et tondeuse',
      'Snow blower and mower',
      'Quitanieves y cortacésped',
    ),
    titles: _l(
      'Transport de souffleuse à neige ou de tondeuse | Movi-K',
      'Snow blower and lawn mower delivery | Movi-K',
      'Transporte de quitanieves o cortacésped | Movi-K',
    ),
    descriptions: _l(
      'Une souffleuse à neige, une tondeuse ou un tracteur à pelouse à aller chercher, à faire réparer ou à vendre ? Une photo, le prix exact et un chauffeur avec camion.',
      'A snow blower, lawn mower or lawn tractor to pick up, take for repair or sell? One photo, the exact price and a driver with a truck.',
      '¿Un quitanieves, un cortacésped o un tractor de césped que recoger, llevar a reparar o vender? Una foto, el precio exacto y un conductor con camioneta.',
    ),
    headings: _l(
      'Transport de souffleuse et de tondeuse',
      'Snow blower and lawn mower delivery',
      'Transporte de quitanieves y cortacésped',
    ),
    intros: _l(
      'Avant la première bordée de neige ou au printemps, une souffleuse ou une tondeuse doit souvent changer d’adresse : un achat, une réparation ou une vente. Un chauffeur avec le bon véhicule s’en occupe.',
      'Before the first snowfall or in spring, a snow blower or mower often has to change places: a purchase, a repair or a sale. A driver with the right vehicle takes care of it.',
      'Antes de la primera nevada o en primavera, un quitanieves o un cortacésped a menudo tiene que cambiar de lugar: una compra, una reparación o una venta. Un conductor con el vehículo adecuado se encarga.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Souffleuse à neige, tondeuse à pousser ou autotractée, tracteur à pelouse, coupe-bordure, génératrice, laveuse à pression.',
      'Snow blowers, push or self-propelled mowers, lawn tractors, trimmers, generators, pressure washers.',
      'Quitanieves, cortacésped de empuje o autopropulsado, tractor de césped, desbrozadora, generador, hidrolavadora.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Videz le réservoir d’essence ou laissez-le presque vide, et fermez bien le bouchon : les bidons d’essence ne voyagent pas avec l’appareil. Précisez dans la demande si l’appareil roule et s’il démarre : le chauffeur prévoit mieux le chargement.',
      'Empty the fuel tank or leave it nearly empty, and close the cap tightly: fuel cans don’t travel with the machine. Say in the request whether the machine rolls and starts: the driver can plan the loading better.',
      'Vacía el tanque de gasolina o déjalo casi vacío, y cierra bien el tapón: los bidones de gasolina no viajan con el aparato. Indica en la solicitud si el aparato rueda y si arranca: así el conductor prepara mejor la carga.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_patio',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/meubles-patio-bbq', '/en/transport/patio-furniture-bbq', '/es/transporte/muebles-patio-parrilla'),
    labels: _l(
      'Patio et BBQ',
      'Patio and BBQ',
      'Patio y parrilla',
    ),
    titles: _l(
      'Transport de BBQ et de meubles de patio | Movi-K',
      'BBQ and patio furniture delivery | Movi-K',
      'Transporte de parrilla y muebles de patio | Movi-K',
    ),
    descriptions: _l(
      'Un BBQ, un ensemble de patio ou des chaises Adirondack à faire livrer ? Prenez une photo, voyez le prix exact et un chauffeur de la région s’en charge.',
      'A BBQ, a patio set or Adirondack chairs to deliver? Snap a photo, see the exact price and a local driver takes care of it.',
      '¿Una parrilla, un juego de patio o sillas Adirondack que entregar? Toma una foto, ve el precio exacto y un conductor local se encarga.',
    ),
    headings: _l(
      'Transport de BBQ et de meubles de patio',
      'BBQ and patio furniture delivery',
      'Transporte de parrilla y muebles de patio',
    ),
    intros: _l(
      'Un BBQ assemblé ne rentre dans aucune auto, et un ensemble de patio non plus. Un chauffeur le transporte du magasin, du vendeur ou du chalet jusqu’à chez vous.',
      'An assembled BBQ won’t fit in any car, and neither will a patio set. A driver moves it from the store, the seller or the cottage to your home.',
      'Una parrilla armada no cabe en ningún auto, y un juego de patio tampoco. Un conductor lo transporta de la tienda, del vendedor o de la cabaña hasta tu casa.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'BBQ au gaz, au charbon ou à granules, ensemble de patio, chaises, parasol, foyer extérieur, remise en kit.',
      'Gas, charcoal or pellet BBQs, patio sets, chairs, umbrellas, outdoor fire pits, shed kits.',
      'Parrillas de gas, carbón o pellets, juegos de patio, sillas, sombrillas, fogatas exteriores, cobertizos en kit.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Pour un BBQ au propane, retirez la bonbonne : les matières dangereuses sont exclues du transport. Videz le bac à graisse et fixez le couvercle. Empilez les chaises et retirez les coussins.',
      'For a propane BBQ, remove the tank: hazardous materials are excluded from transport. Empty the grease tray and secure the lid. Stack the chairs and remove the cushions.',
      'Para una parrilla de propano, retira el tanque: los materiales peligrosos están excluidos del transporte. Vacía la bandeja de grasa y asegura la tapa. Apila las sillas y retira los cojines.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_materials',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/materiaux-construction', '/en/transport/construction-materials', '/es/transporte/materiales-construccion'),
    labels: _l(
      'Matériaux de construction',
      'Construction materials',
      'Materiales de construcción',
    ),
    titles: _l(
      'Livraison de matériaux de construction | Movi-K',
      'Construction materials delivery | Movi-K',
      'Entrega de materiales de construcción | Movi-K',
    ),
    descriptions: _l(
      'Bois, gypse, contreplaqué ou sacs de béton à faire livrer de la quincaillerie au chantier ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Lumber, drywall, plywood or bags of concrete to bring from the hardware store to the job site? Snap a photo, see the exact price and book a driver.',
      '¿Madera, paneles de yeso, contrachapado o sacos de cemento de la ferretería a la obra? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de matériaux de construction',
      'Construction materials delivery',
      'Entrega de materiales de construcción',
    ),
    intros: _l(
      'Pour une rénovation ou un petit chantier, pas besoin de louer un camion pour quelques planches et des sacs de béton : un chauffeur avec camionnette ou remorque vient les chercher pour vous.',
      'For a renovation or a small project, no need to rent a truck for a few boards and bags of concrete: a driver with a pickup or a trailer picks them up for you.',
      'Para una renovación o una obra pequeña, no hace falta alquilar un camión por unas tablas y sacos de cemento: un conductor con camioneta o remolque los recoge por ti.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Bois d’œuvre, panneaux de gypse, contreplaqué, sacs de béton ou de terre, revêtement de plancher, portes et fenêtres, isolant, palettes de matériaux.',
      'Lumber, drywall panels, plywood, bags of concrete or soil, flooring, doors and windows, insulation, pallets of materials.',
      'Madera, paneles de yeso, contrachapado, sacos de cemento o tierra, revestimiento de suelo, puertas y ventanas, aislante, palés de materiales.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Regroupez tout au même endroit, prêt à charger. Indiquez la longueur des pièces les plus longues et le nombre de sacs dans la description : le chauffeur voit vos photos et confirme que tout entre dans son véhicule avant d’accepter.',
      'Gather everything in one spot, ready to load. Give the length of the longest pieces and the number of bags in the description: the driver sees your photos and confirms everything fits in their vehicle before accepting.',
      'Reúne todo en un mismo lugar, listo para cargar. Indica el largo de las piezas más largas y el número de sacos en la descripción: el conductor ve tus fotos y confirma que todo cabe en su vehículo antes de aceptar.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_marketplace',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/achats-marketplace', '/en/transport/marketplace-purchases', '/es/transporte/compras-marketplace'),
    labels: _l(
      'Achats Marketplace',
      'Marketplace purchases',
      'Compras de Marketplace',
    ),
    titles: _l(
      'Livraison d’achats Marketplace et Kijiji | Movi-K',
      'Marketplace and Kijiji purchase delivery | Movi-K',
      'Entrega de compras de Marketplace y Kijiji | Movi-K',
    ),
    descriptions: _l(
      'Vous avez trouvé un meuble ou un électroménager sur Marketplace mais pas de camion ? Prenez une photo, voyez le prix exact et un chauffeur va le chercher.',
      'Found furniture or an appliance on Marketplace but have no truck? Snap a photo of the item, see the exact price and a driver picks it up for you.',
      '¿Encontraste un mueble o un electrodoméstico en Marketplace pero no tienes camioneta? Toma una foto, ve el precio exacto y un conductor lo recoge.',
    ),
    headings: _l(
      'Livraison de vos achats Marketplace',
      'Delivery for your Marketplace purchases',
      'Entrega de tus compras de Marketplace',
    ),
    intros: _l(
      'La bonne affaire est à l’autre bout de la ville et elle ne rentre pas dans votre auto. Un chauffeur de la région va la chercher chez le vendeur et vous la livre.',
      'The great deal is across town and it won’t fit in your car. A local driver picks it up at the seller’s and delivers it to you.',
      'La gran oferta está al otro lado de la ciudad y no cabe en tu auto. Un conductor de la zona la recoge en casa del vendedor y te la entrega.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Meubles, électroménagers, matériaux, équipement de sport ou de jardin achetés sur Facebook Marketplace, Kijiji ou dans une vente de garage.',
      'Furniture, appliances, materials, sports or garden equipment bought on Facebook Marketplace, Kijiji or at a garage sale.',
      'Muebles, electrodomésticos, materiales, equipo deportivo o de jardín comprados en Facebook Marketplace, Kijiji o en una venta de garaje.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Entendez-vous avec le vendeur sur l’heure du ramassage et réglez l’achat directement avec lui : Movi-K s’occupe seulement du transport. Prenez une photo de l’objet ou de l’annonce pour votre demande et donnez l’adresse exacte du vendeur.',
      'Agree on a pickup time with the seller and settle the purchase directly with them: Movi-K only handles the transport. Take a photo of the item or the listing for your request and give the seller’s exact address.',
      'Acuerda con el vendedor la hora de recogida y paga la compra directamente: Movi-K solo se encarga del transporte. Toma una foto del objeto o del anuncio para tu solicitud y da la dirección exacta del vendedor.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'object_store',
    kind: SeoPageKind.object,
    paths: _l('/fr/transport/achats-en-magasin', '/en/transport/store-purchases', '/es/transporte/compras-en-tienda'),
    labels: _l(
      'Achats en magasin',
      'Store purchases',
      'Compras en tienda',
    ),
    titles: _l(
      'Livraison de vos achats en magasin | Movi-K',
      'Delivery for your store purchases | Movi-K',
      'Entrega de tus compras en tienda | Movi-K',
    ),
    descriptions: _l(
      'Votre achat chez IKEA, Costco, Canadian Tire ou à la quincaillerie ne rentre pas dans l’auto ? Prenez une photo, voyez le prix exact et un chauffeur le livre.',
      'Your purchase from IKEA, Costco, Canadian Tire or the hardware store won’t fit in the car? Snap a photo, see the exact price and a driver brings it home.',
      '¿Tu compra en IKEA, Costco, Canadian Tire o la ferretería no cabe en el auto? Toma una foto, ve el precio exacto y un conductor la lleva a tu casa.',
    ),
    headings: _l(
      'Livraison de vos achats en magasin',
      'Delivery for your store purchases',
      'Entrega de tus compras en tienda',
    ),
    intros: _l(
      'À la caisse, c’est trop tard pour se demander si ça rentre dans l’auto. Réservez un chauffeur : il passe au magasin et livre votre achat chez vous.',
      'At the checkout, it’s too late to wonder whether it fits in the car. Book a driver: they stop by the store and deliver your purchase to your home.',
      'En la caja ya es tarde para preguntarse si cabe en el auto. Reserva un conductor: pasa por la tienda y entrega tu compra en tu casa.',
    ),
    sections: [
      SeoSection(_objectWhatHeading, _l(
      'Meubles en boîte, électroménagers, matelas, matériaux de quincaillerie, achats en entrepôt-club : grandes surfaces comme IKEA, Costco, Canadian Tire ou Home Depot, magasins de meubles et quincailleries. Movi-K est un service indépendant, non affilié à ces magasins.',
      'Flat-pack furniture, appliances, mattresses, hardware supplies, warehouse-club purchases: big-box stores such as IKEA, Costco, Canadian Tire or Home Depot, furniture stores and hardware stores. Movi-K is an independent service, not affiliated with these stores.',
      'Muebles en caja, electrodomésticos, colchones, materiales de ferretería, compras en tiendas de almacén: grandes superficies como IKEA, Costco, Canadian Tire o Home Depot, tiendas de muebles y ferreterías. Movi-K es un servicio independiente, sin afiliación con estas tiendas.',
    )),
      SeoSection(_objectPrepareHeading, _l(
      'Payez votre achat et gardez la facture à portée de main. Donnez l’adresse du magasin comme adresse de ramassage et précisez dans la description la porte ou le comptoir de cueillette et le nom au dossier.',
      'Pay for your purchase and keep the receipt handy. Enter the store address as the pickup address and add the pickup door or counter and the name on the order in the description.',
      'Paga tu compra y ten la factura a mano. Indica la dirección de la tienda como dirección de recogida y precisa en la descripción la puerta o el mostrador de entrega y el nombre del pedido.',
    )),
      _objectAccess,
      _guidePrice,
      _guideDriver,
    ],
  ),

];


/// Une page par ville, par vagues : /fr/villes/…, /en/cities/…, /es/ciudades/….
final List<SeoPage> seoCityPages = [

  SeoPage(
    id: 'city_bromont',
    kind: SeoPageKind.city,
    city: 'Bromont',
    paths: _l('/fr/villes/bromont', '/en/cities/bromont', '/es/ciudades/bromont'),
    labels: _l(
      'Bromont',
      'Bromont',
      'Bromont',
    ),
    titles: _l(
      'Livraison de meubles à Bromont | Movi-K',
      'Furniture delivery in Bromont | Movi-K',
      'Entrega de muebles en Bromont | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Bromont et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Bromont? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Bromont o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Bromont',
      'Furniture and appliance delivery in Bromont',
      'Entrega de muebles y electrodomésticos en Bromont',
    ),
    intros: _l(
      'Entre la montagne et le parc scientifique, Bromont déménage souvent : un divan pour le condo, une laveuse pour le chalet ou un achat fait à Granby, un chauffeur de la région s’en occupe.',
      'Between the mountain and the science park, Bromont moves a lot: a sofa for the condo, a washer for the chalet or something bought in Granby, a local driver takes care of it.',
      'Entre la montaña y el parque científico, en Bromont siempre hay algo que mover: un sofá para el condominio, una lavadora para la cabaña o una compra hecha en Granby; un conductor de la zona se encarga.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Bromont, Granby, Shefford, Brigham, Cowansville, Lac-Brome et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Bromont, Granby, Shefford, Brigham, Cowansville, Lac-Brome and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Bromont, Granby, Shefford, Brigham, Cowansville, Lac-Brome y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Bromont',
      'What we deliver in Bromont',
      'Lo que entregamos en Bromont',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_cowansville',
    kind: SeoPageKind.city,
    city: 'Cowansville',
    paths: _l('/fr/villes/cowansville', '/en/cities/cowansville', '/es/ciudades/cowansville'),
    labels: _l(
      'Cowansville',
      'Cowansville',
      'Cowansville',
    ),
    titles: _l(
      'Livraison de meubles à Cowansville | Movi-K',
      'Furniture delivery in Cowansville | Movi-K',
      'Entrega de muebles en Cowansville | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Cowansville et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Cowansville? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Cowansville o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Cowansville',
      'Furniture and appliance delivery in Cowansville',
      'Entrega de muebles y electrodomésticos en Cowansville',
    ),
    intros: _l(
      'À Cowansville et partout dans Brome-Missisquoi, un réfrigérateur, un lit ou des matériaux pour la rénovation se rendent chez vous sans camion à louer.',
      'In Cowansville and throughout Brome-Missisquoi, a refrigerator, a bed or renovation materials get to your home without renting a truck.',
      'En Cowansville y en todo Brome-Missisquoi, un refrigerador, una cama o materiales de renovación llegan a tu casa sin alquilar un camión.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Cowansville, Bromont, Brigham, Dunham, Sutton, Lac-Brome, Farnham et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Cowansville, Bromont, Brigham, Dunham, Sutton, Lac-Brome, Farnham and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Cowansville, Bromont, Brigham, Dunham, Sutton, Lac-Brome, Farnham y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Cowansville',
      'What we deliver in Cowansville',
      'Lo que entregamos en Cowansville',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_waterloo',
    kind: SeoPageKind.city,
    city: 'Waterloo',
    paths: _l('/fr/villes/waterloo', '/en/cities/waterloo', '/es/ciudades/waterloo'),
    labels: _l(
      'Waterloo',
      'Waterloo',
      'Waterloo',
    ),
    titles: _l(
      'Livraison de meubles à Waterloo | Movi-K',
      'Furniture delivery in Waterloo | Movi-K',
      'Entrega de muebles en Waterloo | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Waterloo et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Waterloo? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Waterloo o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Waterloo',
      'Furniture and appliance delivery in Waterloo',
      'Entrega de muebles y electrodomésticos en Waterloo',
    ),
    intros: _l(
      'Au bord de son lac, entre Granby et les Cantons-de-l’Est, Waterloo se fait livrer meubles, électroménagers et achats Marketplace sans emprunter de camion.',
      'On the shore of its lake, between Granby and the Eastern Townships, Waterloo gets furniture, appliances and Marketplace purchases delivered without borrowing a truck.',
      'A orillas de su lago, entre Granby y los Cantones del Este, Waterloo recibe muebles, electrodomésticos y compras de Marketplace sin pedir prestado un camión.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Waterloo, Shefford, Granby, Warden, Saint-Joachim-de-Shefford et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Waterloo, Shefford, Granby, Warden, Saint-Joachim-de-Shefford and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Waterloo, Shefford, Granby, Warden, Saint-Joachim-de-Shefford y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Waterloo',
      'What we deliver in Waterloo',
      'Lo que entregamos en Waterloo',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_saint_hyacinthe',
    kind: SeoPageKind.city,
    city: 'Saint-Hyacinthe',
    paths: _l('/fr/villes/saint-hyacinthe', '/en/cities/saint-hyacinthe', '/es/ciudades/saint-hyacinthe'),
    labels: _l(
      'Saint-Hyacinthe',
      'Saint-Hyacinthe',
      'Saint-Hyacinthe',
    ),
    titles: _l(
      'Livraison de meubles à Saint-Hyacinthe | Movi-K',
      'Furniture delivery in Saint-Hyacinthe | Movi-K',
      'Entrega de muebles en Saint-Hyacinthe | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Saint-Hyacinthe et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Saint-Hyacinthe? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Saint-Hyacinthe o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Saint-Hyacinthe',
      'Furniture and appliance delivery in Saint-Hyacinthe',
      'Entrega de muebles y electrodomésticos en Saint-Hyacinthe',
    ),
    intros: _l(
      'À Saint-Hyacinthe, la technopole agroalimentaire, un électroménager acheté en ville ou un meuble trouvé sur Marketplace arrive chez vous avec un chauffeur de la région.',
      'In Saint-Hyacinthe, the agri-food technopole, an appliance bought in town or furniture found on Marketplace reaches your home with a local driver.',
      'En Saint-Hyacinthe, la tecnópolis agroalimentaria, un electrodoméstico comprado en la ciudad o un mueble de Marketplace llega a tu casa con un conductor de la zona.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Saint-Hyacinthe, Saint-Dominique, Saint-Pie, Sainte-Madeleine, Saint-Damase, Saint-Simon et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Saint-Hyacinthe, Saint-Dominique, Saint-Pie, Sainte-Madeleine, Saint-Damase, Saint-Simon and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Saint-Hyacinthe, Saint-Dominique, Saint-Pie, Sainte-Madeleine, Saint-Damase, Saint-Simon y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Saint-Hyacinthe',
      'What we deliver in Saint-Hyacinthe',
      'Lo que entregamos en Saint-Hyacinthe',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_saint_jean_sur_richelieu',
    kind: SeoPageKind.city,
    city: 'Saint-Jean-sur-Richelieu',
    paths: _l('/fr/villes/saint-jean-sur-richelieu', '/en/cities/saint-jean-sur-richelieu', '/es/ciudades/saint-jean-sur-richelieu'),
    labels: _l(
      'Saint-Jean-sur-Richelieu',
      'Saint-Jean-sur-Richelieu',
      'Saint-Jean-sur-Richelieu',
    ),
    titles: _l(
      'Livraison de meubles à Saint-Jean-sur-Richelieu | Movi-K',
      'Furniture delivery in Saint-Jean-sur-Richelieu | Movi-K',
      'Entrega de muebles en Saint-Jean-sur-Richelieu | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Saint-Jean-sur-Richelieu et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Saint-Jean-sur-Richelieu? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Saint-Jean-sur-Richelieu o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Saint-Jean-sur-Richelieu',
      'Furniture and appliance delivery in Saint-Jean-sur-Richelieu',
      'Entrega de muebles y electrodomésticos en Saint-Jean-sur-Richelieu',
    ),
    intros: _l(
      'Le long du Richelieu, de Saint-Jean à Iberville : un divan, une laveuse ou des boîtes à déplacer se réservent en quelques minutes, sans louer de camion.',
      'Along the Richelieu, from Saint-Jean to Iberville: a sofa, a washer or boxes to move can be booked in a few minutes, without renting a truck.',
      'A lo largo del Richelieu, de Saint-Jean a Iberville: un sofá, una lavadora o cajas que mover se reservan en pocos minutos, sin alquilar un camión.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Saint-Jean-sur-Richelieu, Iberville, Chambly, Carignan, Mont-Saint-Grégoire, Saint-Alexandre et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Saint-Jean-sur-Richelieu, Iberville, Chambly, Carignan, Mont-Saint-Grégoire, Saint-Alexandre and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Saint-Jean-sur-Richelieu, Iberville, Chambly, Carignan, Mont-Saint-Grégoire, Saint-Alexandre y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Saint-Jean-sur-Richelieu',
      'What we deliver in Saint-Jean-sur-Richelieu',
      'Lo que entregamos en Saint-Jean-sur-Richelieu',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_sherbrooke',
    kind: SeoPageKind.city,
    city: 'Sherbrooke',
    paths: _l('/fr/villes/sherbrooke', '/en/cities/sherbrooke', '/es/ciudades/sherbrooke'),
    labels: _l(
      'Sherbrooke',
      'Sherbrooke',
      'Sherbrooke',
    ),
    titles: _l(
      'Livraison de meubles à Sherbrooke | Movi-K',
      'Furniture delivery in Sherbrooke | Movi-K',
      'Entrega de muebles en Sherbrooke | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Sherbrooke et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Sherbrooke? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Sherbrooke o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Sherbrooke',
      'Furniture and appliance delivery in Sherbrooke',
      'Entrega de muebles y electrodomésticos en Sherbrooke',
    ),
    intros: _l(
      'Capitale de l’Estrie et ville étudiante : un frigo pour l’appartement, un lit pour la rentrée ou un divan acheté sur Marketplace, autour du 1er juillet comme le reste de l’année.',
      'Capital of the Eastern Townships and a student city: a fridge for the apartment, a bed for the new school year or a sofa bought on Marketplace, around July 1st and all year long.',
      'Capital de la Estrie y ciudad universitaria: un refrigerador para el apartamento, una cama para el inicio de clases o un sofá de Marketplace, alrededor del 1 de julio y todo el año.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Sherbrooke, Fleurimont, Lennoxville, Rock Forest, Magog, Ascot Corner, Compton et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Sherbrooke, Fleurimont, Lennoxville, Rock Forest, Magog, Ascot Corner, Compton and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Sherbrooke, Fleurimont, Lennoxville, Rock Forest, Magog, Ascot Corner, Compton y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Sherbrooke',
      'What we deliver in Sherbrooke',
      'Lo que entregamos en Sherbrooke',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_magog',
    kind: SeoPageKind.city,
    city: 'Magog',
    paths: _l('/fr/villes/magog', '/en/cities/magog', '/es/ciudades/magog'),
    labels: _l(
      'Magog',
      'Magog',
      'Magog',
    ),
    titles: _l(
      'Livraison de meubles à Magog | Movi-K',
      'Furniture delivery in Magog | Movi-K',
      'Entrega de muebles en Magog | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Magog et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Magog? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Magog o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Magog',
      'Furniture and appliance delivery in Magog',
      'Entrega de muebles y electrodomésticos en Magog',
    ),
    intros: _l(
      'Entre le lac Memphrémagog et le mont Orford : faites livrer les meubles du chalet, les électroménagers ou les meubles de patio sans vous casser le dos.',
      'Between Lake Memphremagog and Mount Orford: get cottage furniture, appliances or patio furniture delivered without breaking your back.',
      'Entre el lago Memphrémagog y el monte Orford: haz entregar los muebles de la cabaña, los electrodomésticos o los muebles de patio sin romperte la espalda.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Magog, Orford, Austin, Eastman, Sainte-Catherine-de-Hatley, Sherbrooke et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Magog, Orford, Austin, Eastman, Sainte-Catherine-de-Hatley, Sherbrooke and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Magog, Orford, Austin, Eastman, Sainte-Catherine-de-Hatley, Sherbrooke y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Magog',
      'What we deliver in Magog',
      'Lo que entregamos en Magog',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_drummondville',
    kind: SeoPageKind.city,
    city: 'Drummondville',
    paths: _l('/fr/villes/drummondville', '/en/cities/drummondville', '/es/ciudades/drummondville'),
    labels: _l(
      'Drummondville',
      'Drummondville',
      'Drummondville',
    ),
    titles: _l(
      'Livraison de meubles à Drummondville | Movi-K',
      'Furniture delivery in Drummondville | Movi-K',
      'Entrega de muebles en Drummondville | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Drummondville et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Drummondville? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Drummondville o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Drummondville',
      'Furniture and appliance delivery in Drummondville',
      'Entrega de muebles y electrodomésticos en Drummondville',
    ),
    intros: _l(
      'Au Centre-du-Québec, à mi-chemin entre Montréal et Québec : un réfrigérateur, une commode ou des matériaux arrivent chez vous avec un chauffeur de la région.',
      'In Centre-du-Québec, halfway between Montreal and Quebec City: a refrigerator, a dresser or materials reach your home with a local driver.',
      'En Centre-du-Québec, a medio camino entre Montreal y Quebec: un refrigerador, una cómoda o materiales llegan a tu casa con un conductor de la zona.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Drummondville, Saint-Cyrille-de-Wendover, Saint-Germain-de-Grantham, Wickham, Saint-Lucien et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Drummondville, Saint-Cyrille-de-Wendover, Saint-Germain-de-Grantham, Wickham, Saint-Lucien and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Drummondville, Saint-Cyrille-de-Wendover, Saint-Germain-de-Grantham, Wickham, Saint-Lucien y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Drummondville',
      'What we deliver in Drummondville',
      'Lo que entregamos en Drummondville',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_longueuil',
    kind: SeoPageKind.city,
    city: 'Longueuil',
    paths: _l('/fr/villes/longueuil', '/en/cities/longueuil', '/es/ciudades/longueuil'),
    labels: _l(
      'Longueuil',
      'Longueuil',
      'Longueuil',
    ),
    titles: _l(
      'Livraison de meubles à Longueuil | Movi-K',
      'Furniture delivery in Longueuil | Movi-K',
      'Entrega de muebles en Longueuil | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Longueuil et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Longueuil? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Longueuil o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Longueuil',
      'Furniture and appliance delivery in Longueuil',
      'Entrega de muebles y electrodomésticos en Longueuil',
    ),
    intros: _l(
      'Sur la Rive-Sud, du Vieux-Longueuil à Saint-Hubert : un achat en grande surface ou un meuble de Marketplace est livré sans louer de camion.',
      'On the South Shore, from Old Longueuil to Saint-Hubert: a big-box store purchase or a Marketplace find is delivered without renting a truck.',
      'En la Rive-Sud, del Viejo Longueuil a Saint-Hubert: una compra en una gran tienda o un mueble de Marketplace se entrega sin alquilar un camión.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Longueuil, Vieux-Longueuil, Saint-Hubert, Greenfield Park, Boucherville, Saint-Lambert et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Longueuil, Vieux-Longueuil, Saint-Hubert, Greenfield Park, Boucherville, Saint-Lambert and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Longueuil, Vieux-Longueuil, Saint-Hubert, Greenfield Park, Boucherville, Saint-Lambert y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Longueuil',
      'What we deliver in Longueuil',
      'Lo que entregamos en Longueuil',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_brossard',
    kind: SeoPageKind.city,
    city: 'Brossard',
    paths: _l('/fr/villes/brossard', '/en/cities/brossard', '/es/ciudades/brossard'),
    labels: _l(
      'Brossard',
      'Brossard',
      'Brossard',
    ),
    titles: _l(
      'Livraison de meubles à Brossard | Movi-K',
      'Furniture delivery in Brossard | Movi-K',
      'Entrega de muebles en Brossard | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Brossard et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Brossard? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Brossard o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Brossard',
      'Furniture and appliance delivery in Brossard',
      'Entrega de muebles y electrodomésticos en Brossard',
    ),
    intros: _l(
      'Brossard et ses grands magasins : ce qui ne rentre pas dans l’auto au Quartier DIX30 ou ailleurs se rend chez vous avec un chauffeur de la région.',
      'Brossard and its big stores: whatever won’t fit in the car at Quartier DIX30 or elsewhere gets to your home with a local driver.',
      'Brossard y sus grandes tiendas: lo que no cabe en el auto en el Quartier DIX30 o en otro lugar llega a tu casa con un conductor de la zona.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Brossard, Saint-Lambert, La Prairie, Candiac, Longueuil, Carignan et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Brossard, Saint-Lambert, La Prairie, Candiac, Longueuil, Carignan and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Brossard, Saint-Lambert, La Prairie, Candiac, Longueuil, Carignan y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Brossard',
      'What we deliver in Brossard',
      'Lo que entregamos en Brossard',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_montreal',
    kind: SeoPageKind.city,
    city: 'Montréal',
    paths: _l('/fr/villes/montreal', '/en/cities/montreal', '/es/ciudades/montreal'),
    labels: _l(
      'Montréal',
      'Montreal',
      'Montreal',
    ),
    titles: _l(
      'Livraison de meubles à Montréal | Movi-K',
      'Furniture delivery in Montreal | Movi-K',
      'Entrega de muebles en Montreal | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Montréal et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Montreal? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Montreal o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Montréal',
      'Furniture and appliance delivery in Montreal',
      'Entrega de muebles y electrodomésticos en Montreal',
    ),
    intros: _l(
      'D’un quartier à l’autre, d’un 3e étage à un rez-de-chaussée : un divan, un frigo ou un achat Marketplace se déplace sans louer de camion ni chercher de stationnement.',
      'From one neighbourhood to another, from a third floor to a ground floor: a sofa, a fridge or a Marketplace purchase moves without renting a truck or hunting for parking.',
      'De un barrio a otro, de un tercer piso a una planta baja: un sofá, un refrigerador o una compra de Marketplace se mueve sin alquilar un camión ni buscar estacionamiento.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Montréal, Plateau-Mont-Royal, Rosemont, Hochelaga-Maisonneuve, Villeray, Verdun, Ahuntsic, Saint-Laurent et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Montreal, Plateau-Mont-Royal, Rosemont, Hochelaga-Maisonneuve, Villeray, Verdun, Ahuntsic, Saint-Laurent and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Montreal, Plateau-Mont-Royal, Rosemont, Hochelaga-Maisonneuve, Villeray, Verdun, Ahuntsic, Saint-Laurent y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Montréal',
      'What we deliver in Montreal',
      'Lo que entregamos en Montreal',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_laval',
    kind: SeoPageKind.city,
    city: 'Laval',
    paths: _l('/fr/villes/laval', '/en/cities/laval', '/es/ciudades/laval'),
    labels: _l(
      'Laval',
      'Laval',
      'Laval',
    ),
    titles: _l(
      'Livraison de meubles à Laval | Movi-K',
      'Furniture delivery in Laval | Movi-K',
      'Entrega de muebles en Laval | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Laval et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Laval? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Laval o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Laval',
      'Furniture and appliance delivery in Laval',
      'Entrega de muebles y electrodomésticos en Laval',
    ),
    intros: _l(
      'De Chomedey à Sainte-Rose : un électroménager neuf, un lit ou un meuble usagé est livré chez vous par un chauffeur de la région.',
      'From Chomedey to Sainte-Rose: a new appliance, a bed or a used piece of furniture is delivered to your home by a local driver.',
      'De Chomedey a Sainte-Rose: un electrodoméstico nuevo, una cama o un mueble usado se entrega en tu casa con un conductor de la zona.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Laval, Chomedey, Sainte-Rose, Vimont, Fabreville, Laval-des-Rapides, Auteuil et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Laval, Chomedey, Sainte-Rose, Vimont, Fabreville, Laval-des-Rapides, Auteuil and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Laval, Chomedey, Sainte-Rose, Vimont, Fabreville, Laval-des-Rapides, Auteuil y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Laval',
      'What we deliver in Laval',
      'Lo que entregamos en Laval',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

  SeoPage(
    id: 'city_quebec',
    kind: SeoPageKind.city,
    city: 'Québec',
    paths: _l('/fr/villes/quebec', '/en/cities/quebec', '/es/ciudades/quebec'),
    labels: _l(
      'Québec',
      'Quebec City',
      'Quebec',
    ),
    titles: _l(
      'Livraison de meubles à Québec | Movi-K',
      'Furniture delivery in Quebec City | Movi-K',
      'Entrega de muebles en Quebec | Movi-K',
    ),
    descriptions: _l(
      'Un meuble, un électroménager ou un achat Marketplace à faire livrer à Québec et dans les environs ? Prenez une photo, voyez le prix exact et réservez un chauffeur.',
      'Furniture, an appliance or a Marketplace purchase to deliver in or around Quebec City? Snap a photo, see the exact price and book a local driver.',
      '¿Un mueble, un electrodoméstico o una compra de Marketplace que entregar en Quebec o sus alrededores? Toma una foto, ve el precio exacto y reserva un conductor.',
    ),
    headings: _l(
      'Livraison de meubles et d’électroménagers à Québec',
      'Furniture and appliance delivery in Quebec City',
      'Entrega de muebles y electrodomésticos en Quebec',
    ),
    intros: _l(
      'De Sainte-Foy à Charlesbourg en passant par Limoilou : un réfrigérateur, un divan ou des boîtes se déplacent sans camion à louer.',
      'From Sainte-Foy to Charlesbourg by way of Limoilou: a refrigerator, a sofa or boxes move without a rental truck.',
      'De Sainte-Foy a Charlesbourg pasando por Limoilou: un refrigerador, un sofá o cajas se mueven sin alquilar un camión.',
    ),
    sections: [
      SeoSection(_cityAreaHeading, _l(
      'Québec, Sainte-Foy, Charlesbourg, Beauport, Limoilou, L’Ancienne-Lorette, Lévis et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
      'Quebec City, Sainte-Foy, Charlesbourg, Beauport, Limoilou, L’Ancienne-Lorette, Lévis and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
      'Quebec, Sainte-Foy, Charlesbourg, Beauport, Limoilou, L’Ancienne-Lorette, Lévis y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
    )),
      SeoSection(_l(
      'Ce qu’on livre à Québec',
      'What we deliver in Quebec City',
      'Lo que entregamos en Quebec',
    ), _cityWhat),
      _guidePrice,
      _guideDriver,
    ],
  ),

];
