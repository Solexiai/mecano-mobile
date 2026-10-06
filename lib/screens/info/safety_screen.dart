import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class SafetyScreen extends StatelessWidget {
  final String locale;
  const SafetyScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();

    final sections = <(IconData, String, String, Color)>[
      (
        Icons.verified_user_outlined,
        tr(
          'Vérification des chauffeurs',
          'Driver review',
          'Verificación de conductores',
        ),
        tr(
          'Chaque dossier chauffeur comprend un profil, un véhicule et les documents requis, notamment le permis et l’assurance. Le dossier doit être approuvé avant l’activation.',
          'Each driver file includes a profile, vehicle and required documents, including licence and insurance. The file must be approved before activation.',
          'Cada expediente de conductor incluye perfil, vehículo y los documentos requeridos, incluida licencia y seguro. Debe aprobarse antes de la activación.',
        ),
        AppColors.primary,
      ),
      (
        Icons.person_outline,
        tr(
          'Responsabilités du client',
          'Customer responsibilities',
          'Responsabilidades del cliente',
        ),
        tr(
          'Décrivez l’objet et les accès avec exactitude, indiquez les besoins de manutention et assurez un accès sécuritaire aux lieux de départ et d’arrivée.',
          'Describe the item and access conditions accurately, specify handling needs and ensure safe access at pickup and delivery.',
          'Describe con precisión el objeto y los accesos, indica las necesidades de manipulación y garantiza un acceso seguro en recogida y entrega.',
        ),
        AppColors.primary,
      ),
      (
        Icons.block,
        tr('Objets exclus', 'Excluded items', 'Artículos excluidos'),
        tr(
          'Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus du service.',
          'Hazardous materials, illegal goods, live animals and items requiring special permits are excluded from the service.',
          'Se excluyen los materiales peligrosos, bienes ilegales, animales vivos y objetos que requieren permisos especiales.',
        ),
        AppColors.error,
      ),
      (
        Icons.event_busy_outlined,
        tr('Annulation', 'Cancellation', 'Cancelación'),
        tr(
          'Les délais, frais et conditions commerciales d’annulation ne sont pas encore approuvés pour publication. Aucune fenêtre gratuite ni aucun frais fixe n’est donc annoncé à ce stade.',
          'Commercial cancellation windows, fees and conditions are not yet approved for publication. No free-cancellation window or fixed fee is therefore advertised at this stage.',
          'Los plazos, cargos y condiciones comerciales de cancelación aún no están aprobados para publicación. Por eso no se anuncia ningún plazo gratuito ni cargo fijo.',
        ),
        AppColors.warning,
      ),
      (
        Icons.photo_camera_outlined,
        tr('Dommages et preuve', 'Damage and evidence', 'Daños y pruebas'),
        tr(
          'En cas de problème, conservez les photos et renseignements utiles liés à la mission. Aucun délai commercial de réclamation n’est publié tant que la politique finale n’est pas approuvée.',
          'If a problem occurs, keep useful photos and mission details. No commercial claim deadline is published until the final policy is approved.',
          'Si ocurre un problema, conserva fotos y datos útiles de la misión. No se publica ningún plazo comercial de reclamación hasta aprobar la política final.',
        ),
        AppColors.warning,
      ),
      (
        Icons.gps_fixed,
        tr('Localisation', 'Location', 'Ubicación'),
        tr(
          'La position du chauffeur peut être utilisée pour le suivi d’une mission active. La validation GPS sur appareils réels et les textes de consentement font encore partie des prérequis de lancement.',
          'Driver location may be used to track an active mission. Real-device GPS validation and consent disclosures remain launch prerequisites.',
          'La ubicación del conductor puede utilizarse para seguir una misión activa. La validación GPS en dispositivos reales y los textos de consentimiento siguen siendo requisitos previos al lanzamiento.',
        ),
        AppColors.primary,
      ),
      (
        Icons.local_hospital_outlined,
        tr('Urgences', 'Emergencies', 'Emergencias'),
        tr(
          'Movi‑K n’est pas un service d’urgence. En cas de danger immédiat, d’accident ou de problème médical, composez le 911.',
          'Movi‑K is not an emergency service. In case of immediate danger, an accident or a medical issue, call 911.',
          'Movi‑K no es un servicio de emergencia. En caso de peligro inmediato, accidente o problema médico, llama al 911.',
        ),
        AppColors.error,
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
                title: tr('Sécurité', 'Safety', 'Seguridad'),
                subtitle: tr(
                  'Ce que la plateforme vérifie aujourd’hui et ce qui reste à finaliser avant l’ouverture publique.',
                  'What the platform verifies today and what still needs to be finalized before public launch.',
                  'Lo que la plataforma verifica hoy y lo que falta finalizar antes de la apertura pública.',
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: .25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.support_agent_outlined,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          'Le canal officiel de soutien et de signalement est encore en préparation. Cette page ne simule aucun envoi. Consultez la page Contact pour l’état actuel.',
                          'The official support and reporting channel is still being prepared. This page does not simulate a submission. See the Contact page for the current status.',
                          'El canal oficial de soporte y reportes sigue en preparación. Esta página no simula ningún envío. Consulta la página de Contacto para conocer el estado actual.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => context.go('/$locale/contact'),
                      child: Text(tr('Contact', 'Contact', 'Contacto')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ...sections.map(
                (section) => _SafetyCard(
                  icon: section.$1,
                  title: section.$2,
                  description: section.$3,
                  color: section.$4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _SafetyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
