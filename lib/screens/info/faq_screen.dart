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

    final items = <(String, String)>[
      (
        tr(
          'Comment obtenir un devis ?',
          'How do I get a quote?',
          '¿Cómo obtengo un presupuesto?',
        ),
        tr(
          'Décrivez vos objets, leurs dimensions et leur poids, puis sélectionnez les adresses et l’aide nécessaire. Movi‑K vérifie les catégories de véhicule compatibles et calcule le devis officiel après connexion. Vous consultez le prix et sa ventilation avant confirmation. Les renseignements incomplets peuvent nécessiter une vérification.',
          'Describe your items, dimensions and weight, then select addresses and required assistance. Movi‑K checks compatible vehicle categories and calculates the official quote after sign-in. You review the price and breakdown before confirming. Incomplete details may require a review.',
          'Describe los objetos, sus dimensiones y peso, y selecciona las direcciones y la ayuda necesaria. Movi‑K verifica las categorías de vehículo compatibles y calcula el presupuesto oficial tras iniciar sesión. Revisas el precio y el desglose antes de confirmar. Los datos incompletos pueden requerir revisión.',
        ),
      ),
      (
        tr(
          'Puis-je commencer sans compte ?',
          'Can I start without an account?',
          '¿Puedo empezar sin una cuenta?',
        ),
        tr(
          'Oui. Vous pouvez préparer la demande avant de vous connecter. Une connexion est requise lorsque vous demandez le devis officiel. Les informations déjà saisies sont conservées localement pour reprendre le parcours après la connexion.',
          'Yes. You can prepare the request before signing in. Sign-in is required when you request the official quote. Information already entered is kept locally so you can resume after signing in.',
          'Sí. Puedes preparar la solicitud antes de iniciar sesión. Debes iniciar sesión al solicitar el presupuesto oficial. Los datos ya ingresados se conservan localmente para continuar después.',
        ),
      ),
      (
        tr(
          'Est-ce que je choisis mon chauffeur ?',
          'Do I choose my driver?',
          '¿Elijo al conductor?',
        ),
        tr(
          'Non. Après confirmation d’une demande admissible, Movi‑K recherche un chauffeur disponible et admissible. L’attribution dépend de la disponibilité réelle et aucun chauffeur n’est garanti au moment du devis.',
          'No. After an eligible request is confirmed, Movi‑K looks for an available, eligible driver. Assignment depends on actual availability and no driver is guaranteed at quote time.',
          'No. Después de confirmar una solicitud admisible, Movi‑K busca un conductor disponible y apto. La asignación depende de la disponibilidad real y ningún conductor está garantizado al cotizar.',
        ),
      ),
      (
        tr(
          'Puis-je choisir une heure ou un créneau ?',
          'Can I choose a time slot?',
          '¿Puedo elegir una franja horaria?',
        ),
        tr(
          'Vous pouvez indiquer une date et une heure souhaitées dans votre demande. Ce souhait dépend de la disponibilité et de l’acceptation du chauffeur : il ne constitue pas un créneau confirmé.',
          'You can enter a preferred date and time in your request. This preference depends on driver availability and acceptance; it is not a confirmed time slot.',
          'Puedes indicar una fecha y una hora deseadas en tu solicitud. Dependen de la disponibilidad y aceptación del conductor; no constituyen un horario confirmado.',
        ),
      ),
      (
        tr(
          'Comment fonctionne le suivi ?',
          'How does tracking work?',
          '¿Cómo funciona el seguimiento?',
        ),
        tr(
          'Le client peut suivre les étapes de la mission dans son espace. Le suivi GPS en direct est conçu pour les phases actives de la livraison; sa validation sur appareils réels fait encore partie des vérifications de lancement. Le site ne promet donc pas une carte GPS pour chaque situation.',
          'Customers can follow mission status in their account. Live GPS is designed for active delivery phases; real-device validation is still part of launch checks. The site therefore does not promise a live map in every situation.',
          'El cliente puede seguir las etapas de la misión en su cuenta. El GPS en directo está diseñado para las fases activas; la validación en dispositivos reales sigue siendo parte de las pruebas de lanzamiento. Por eso no se promete un mapa en vivo en todas las situaciones.',
        ),
      ),
      (
        tr(
          'Quels objets peuvent être livrés ?',
          'What items can be delivered?',
          '¿Qué objetos se pueden transportar?',
        ),
        tr(
          'Le formulaire propose notamment meubles, électroménagers, achats Marketplace, matériaux, boîtes, téléviseurs et petits déménagements, ainsi que d’autres catégories compatibles. Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus.',
          'The form includes furniture, appliances, Marketplace purchases, materials, boxes, large TVs and small moves, plus other compatible categories. Hazardous materials, illegal goods, live animals and items requiring special permits are excluded.',
          'El formulario incluye muebles, electrodomésticos, compras Marketplace, materiales, cajas, televisores grandes y pequeñas mudanzas, además de otras categorías compatibles. Se excluyen materiales peligrosos, bienes ilegales, animales vivos y objetos que requieren permisos especiales.',
        ),
      ),
      (
        tr('Comment puis-je payer ?', 'How can I pay?', '¿Cómo puedo pagar?'),
        tr(
          'Les modalités de paiement en production sont encore en validation pour le lancement à Granby. Le parcours affichera le moyen de paiement réellement disponible lorsqu’il sera activé. Le site ne promet pas de paiement comptant ou Interac.',
          'Production payment methods are still being validated for the Granby launch. The flow will show the payment method that is actually available once activated. The site does not promise cash or Interac.',
          'Los métodos de pago en producción siguen en validación para el lanzamiento en Granby. El proceso mostrará el método realmente disponible cuando esté activado. El sitio no promete efectivo ni Interac.',
        ),
      ),
      (
        tr(
          'Comment les chauffeurs sont-ils vérifiés?',
          'How are drivers reviewed?',
          '¿Cómo se revisan los conductores?',
        ),
        tr(
          'Le parcours chauffeur demande un profil, un véhicule et les documents requis, notamment permis, assurance et éléments de vérification. Le dossier doit être approuvé avant l’activation.',
          'The driver flow requires a profile, vehicle and required documents, including licence, insurance and verification items. The application must be approved before activation.',
          'El proceso del conductor requiere perfil, vehículo y documentos, incluidos licencia, seguro y elementos de verificación. El expediente debe aprobarse antes de activarse.',
        ),
      ),
      (
        tr(
          'Quelles sont les règles d’annulation?',
          'What are the cancellation rules?',
          '¿Cuáles son las reglas de cancelación?',
        ),
        tr(
          'Les délais et frais commerciaux d’annulation ne sont pas encore approuvés pour publication. La page d’annulation indique donc actuellement que la politique est en révision plutôt que d’inventer un délai ou des frais.',
          'Commercial cancellation windows and fees are not yet approved for publication. The cancellation page therefore states that the policy is under review rather than inventing a window or fee.',
          'Los plazos y cargos comerciales de cancelación todavía no están aprobados para publicación. La página de cancelación indica que la política está en revisión en lugar de inventar un plazo o cargo.',
        ),
      ),
      (
        tr(
          'Où le service sera-t-il lancé?',
          'Where will service launch?',
          '¿Dónde se lanzará el servicio?',
        ),
        tr(
          'Le lancement est prévu à Granby et dans les environs. La disponibilité dépendra des chauffeurs actifs, de leur rayon d’action et du véhicule requis.',
          'The launch is planned for Granby and surrounding areas. Availability will depend on active drivers, their service areas and the required vehicle.',
          'El lanzamiento está previsto en Granby y alrededores. La disponibilidad dependerá de los conductores activos, sus zonas de servicio y el vehículo necesario.',
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
                  'Réponses alignées sur le parcours actuellement construit et sur l’état de préparation du lancement.',
                  'Answers aligned with the flow currently built and the launch-readiness state.',
                  'Respuestas alineadas con el proceso construido y el estado de preparación del lanzamiento.',
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
                          'Pré-lancement à Granby et dans les environs : une demande ou un devis ne garantit pas encore qu’un chauffeur sera disponible.',
                          'Pre-launch in Granby and surrounding areas: a request or quote does not yet guarantee driver availability.',
                          'Prelanzamiento en Granby y alrededores: una solicitud o presupuesto aún no garantiza la disponibilidad de un conductor.',
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
