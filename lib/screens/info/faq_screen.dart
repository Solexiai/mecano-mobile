import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class FaqScreen extends StatelessWidget {
  final String locale;
  const FaqScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();

    // Answers match what the product does on 2026-10-26: photo + AI (#73),
    // 20 item types (#79), driver confirms the load, hours and days set in
    // the admin (#85), difficult-conditions supplement (#88), card saved,
    // held at acceptance, charged at delivery, cancellation fees
    // (missionFees.ts). No hours, days or zone radius are hard-coded here
    // because the admin can change them.
    final items = <(String, String)>[
      (
        tr(
          'Comment obtenir un prix ?',
          'How do I get a price?',
          '¿Cómo obtengo un precio?',
        ),
        tr(
          'Prenez une photo de vos objets : on les reconnaît pour vous. Ajoutez les adresses de ramassage et de livraison, le moment voulu et l’aide nécessaire. Le prix exact s’affiche, taxes et détail inclus, avant que vous confirmiez.',
          'Snap a photo of your items and we recognize them for you. Add the pickup and delivery addresses, the time you want and the help you need. The exact price is shown, taxes and breakdown included, before you confirm.',
          'Toma una foto de tus objetos y los reconocemos por ti. Añade las direcciones de recogida y entrega, el momento deseado y la ayuda necesaria. El precio exacto se muestra, con impuestos y desglose, antes de confirmar.',
        ),
      ),
      (
        tr(
          'Dois-je créer un compte ?',
          'Do I need an account?',
          '¿Necesito una cuenta?',
        ),
        tr(
          'Vous pouvez commencer sans compte. La connexion est demandée pour obtenir votre prix et réserver. Ce que vous avez déjà rempli est gardé 24 heures.',
          'You can start without an account. Sign-in is required to get your price and book. What you have already filled in is kept for 24 hours.',
          'Puedes empezar sin cuenta. Se pide iniciar sesión para obtener tu precio y reservar. Lo que ya completaste se guarda 24 horas.',
        ),
      ),
      (
        tr(
          'Quels objets pouvez-vous livrer ?',
          'What items can you deliver?',
          '¿Qué objetos pueden transportar?',
        ),
        tr(
          'Meubles (divan, lit, commode, table…), électroménagers (réfrigérateur, laveuse, cuisinière…), téléviseurs, pneus, souffleuse ou tondeuse, meubles de patio et BBQ, vélos, boîtes et matériaux de construction. Votre objet n’est pas dans la liste ? Choisissez « Autre objet ». Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus.',
          'Furniture (sofa, bed, dresser, table…), appliances (refrigerator, washer, stove…), TVs, tires, snow blower or lawn mower, patio furniture and BBQ, bikes, boxes and construction materials. Item not in the list? Choose “Other item”. Hazardous materials, illegal goods, live animals and items requiring special permits are excluded.',
          'Muebles (sofá, cama, cómoda, mesa…), electrodomésticos (refrigerador, lavadora, estufa…), televisores, neumáticos, quitanieves o cortacésped, muebles de patio y parrilla, bicicletas, cajas y materiales de construcción. ¿Tu objeto no está en la lista? Elige «Otro objeto». Se excluyen materiales peligrosos, bienes ilegales, animales vivos y objetos que requieren permisos especiales.',
        ),
      ),
      (
        tr(
          'Dois-je mesurer mes objets ?',
          'Do I need to measure my items?',
          '¿Debo medir mis objetos?',
        ),
        tr(
          'Non. Le chauffeur voit vos photos et confirme que tout entre dans son véhicule avant d’accepter votre demande.',
          'No. The driver sees your photos and confirms everything fits in their vehicle before accepting your request.',
          'No. El conductor ve tus fotos y confirma que todo cabe en su vehículo antes de aceptar tu solicitud.',
        ),
      ),
      (
        tr(
          'Quand ma livraison peut-elle avoir lieu ?',
          'When can my delivery happen?',
          '¿Cuándo puede hacerse mi entrega?',
        ),
        tr(
          'Choisissez « Dès que possible », ou un jour et une heure parmi les créneaux offerts, quelques jours à l’avance. L’heure est confirmée quand un chauffeur accepte votre demande.',
          'Choose “As soon as possible”, or a day and a time among the slots offered, a few days ahead. The time is confirmed when a driver accepts your request.',
          'Elige «Lo antes posible», o un día y una hora entre las franjas ofrecidas, con unos días de antelación. La hora se confirma cuando un conductor acepta tu solicitud.',
        ),
      ),
      (
        tr(
          'Est-ce que je choisis mon chauffeur ?',
          'Do I choose my driver?',
          '¿Elijo al conductor?',
        ),
        tr(
          'Non. Votre demande est envoyée aux chauffeurs vérifiés de la région. Le premier qui accepte s’occupe de votre livraison.',
          'No. Your request is sent to verified drivers in the area. The first one to accept handles your delivery.',
          'No. Tu solicitud se envía a los conductores verificados de la zona. El primero que acepta se encarga de tu entrega.',
        ),
      ),
      (
        tr(
          'Comment et quand vais-je payer ?',
          'How and when do I pay?',
          '¿Cómo y cuándo pago?',
        ),
        tr(
          'Par carte. Vous l’enregistrez en confirmant, sans être débité. Le montant est réservé quand un chauffeur accepte, puis débité à la livraison. Les paiements ouvriront au lancement du service à Granby.',
          'By card. You save it when you confirm, without being charged. The amount is held when a driver accepts, then charged at delivery. Payments will open when the service launches in Granby.',
          'Con tarjeta. La registras al confirmar, sin cobro. El importe se reserva cuando un conductor acepta y se cobra en la entrega. Los pagos se abrirán con el lanzamiento del servicio en Granby.',
        ),
      ),
      (
        tr(
          'Le prix peut-il changer ?',
          'Can the price change?',
          '¿Puede cambiar el precio?',
        ),
        tr(
          'Non, une fois que vous l’avez accepté. Par mauvais temps (tempête, verglas), un supplément peut s’ajouter au prix : il est indiqué, avec sa raison, avant que vous confirmiez.',
          'No, once you have accepted it. In bad weather (storm, freezing rain), a supplement may be added to the price: it is shown, with its reason, before you confirm.',
          'No, una vez que lo aceptas. Con mal tiempo (tormenta, hielo), puede añadirse un suplemento al precio: se indica, con su motivo, antes de confirmar.',
        ),
      ),
      (
        tr(
          'Et si aucun chauffeur n’accepte ?',
          'What if no driver accepts?',
          '¿Y si ningún conductor acepta?',
        ),
        tr(
          'Votre carte n’est pas débitée : le montant n’est réservé qu’au moment où un chauffeur accepte. Vous pouvez annuler votre demande sans frais.',
          'Your card is not charged: the amount is only held when a driver accepts. You can cancel your request at no cost.',
          'No se cobra tu tarjeta: el importe solo se reserva cuando un conductor acepta. Puedes cancelar tu solicitud sin costo.',
        ),
      ),
      (
        tr(
          'Puis-je annuler ?',
          'Can I cancel?',
          '¿Puedo cancelar?',
        ),
        tr(
          'Oui, gratuitement avant qu’un chauffeur accepte, et aussi après si le ramassage est dans plus de 2 heures. Sinon, des frais de 30 \$ s’appliquent. Les mêmes frais s’appliquent si le chauffeur se déplace pour rien. Le montant est affiché avant que vous confirmiez.',
          'Yes, free of charge before a driver accepts, and also afterwards if pickup is more than 2 hours away. Otherwise, a \$30 fee applies. The same fee applies if the driver makes a wasted trip. The amount is shown before you confirm.',
          'Sí, gratis antes de que un conductor acepte, y también después si la recogida es en más de 2 horas. Si no, se aplica un cargo de 30 \$. El mismo cargo se aplica si el conductor se desplaza en vano. El importe se muestra antes de confirmar.',
        ),
      ),
      (
        tr(
          'Comment suivre ma livraison ?',
          'How do I follow my delivery?',
          '¿Cómo sigo mi entrega?',
        ),
        tr(
          'Dans votre espace, vous voyez chaque étape, la position du chauffeur sur la carte pendant la livraison, puis les photos prises au ramassage et à la livraison.',
          'In your account, you see each step, the driver’s position on the map during the delivery, then the photos taken at pickup and delivery.',
          'En tu cuenta ves cada etapa, la ubicación del conductor en el mapa durante la entrega y luego las fotos tomadas al recoger y al entregar.',
        ),
      ),
      (
        tr(
          'Comment les chauffeurs sont-ils vérifiés ?',
          'How are drivers verified?',
          '¿Cómo se verifican los conductores?',
        ),
        tr(
          'Chaque chauffeur fournit son permis de conduire, son assurance et les informations de son véhicule. L’équipe Movi‑K approuve son dossier avant qu’il puisse recevoir des demandes.',
          'Every driver provides their driver’s licence, insurance and vehicle details. The Movi‑K team approves their file before they can receive requests.',
          'Cada conductor presenta su licencia de conducir, su seguro y los datos de su vehículo. El equipo de Movi‑K aprueba su expediente antes de que pueda recibir solicitudes.',
        ),
      ),
      (
        tr(
          'Où le service est-il offert ?',
          'Where is the service offered?',
          '¿Dónde se ofrece el servicio?',
        ),
        tr(
          'À Granby et dans les environs. Le parcours vous indique tout de suite si vos adresses sont dans la zone desservie.',
          'In Granby and surrounding areas. The request flow tells you right away whether your addresses are in the service area.',
          'En Granby y alrededores. El proceso te indica enseguida si tus direcciones están en la zona de servicio.',
        ),
      ),
      (
        tr(
          'Comment devenir chauffeur ?',
          'How do I become a driver?',
          '¿Cómo me hago conductor?',
        ),
        tr(
          'Vous avez un pickup, une fourgonnette ou un camion cube ? Inscrivez-vous depuis la page « Devenir chauffeur » et envoyez vos documents. Vous recevrez des demandes une fois votre dossier approuvé.',
          'Do you have a pickup, a van or a box truck? Sign up from the “Become a Driver” page and send your documents. You will receive requests once your file is approved.',
          '¿Tienes una camioneta pickup, una furgoneta o un camión de caja? Inscríbete desde la página «Convertirse en conductor» y envía tus documentos. Recibirás solicitudes una vez aprobado tu expediente.',
        ),
      ),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: tr(
                  'Questions fréquentes',
                  'Frequently asked questions',
                  'Preguntas frecuentes',
                ),
                subtitle: tr(
                  'Tout ce qu’il faut savoir avant de réserver.',
                  'Everything you need to know before booking.',
                  'Todo lo que necesitas saber antes de reservar.',
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: .2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          'Lancement à Granby et dans les environs. La disponibilité d’un chauffeur est confirmée quand il accepte votre demande.',
                          'Launching in Granby and surrounding areas. Driver availability is confirmed when a driver accepts your request.',
                          'Lanzamiento en Granby y alrededores. La disponibilidad de un conductor se confirma cuando acepta tu solicitud.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    title: Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$2,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
