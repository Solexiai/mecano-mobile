import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class SafetyScreen extends StatelessWidget {
  final String locale;
  const SafetyScreen({super.key, required this.locale});

  String _tr({required String fr, required String en, required String es}) {
    switch (locale) {
      case 'en':
        return en;
      case 'es':
        return es;
      default:
        return fr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final sections = <(IconData, String, String, Color)>[
      (
        Icons.verified_user_outlined,
        _tr(
          fr: 'Vérification des chauffeurs',
          en: 'Driver verification',
          es: 'Verificación de conductores',
        ),
        _tr(
          fr: "Chaque chauffeur fournit une pièce d'identité et les documents requis, notamment le permis, l'assurance et les informations du véhicule. Le dossier est examiné avant l'activation du profil.",
          en: 'Every driver submits an ID and the required documents, including a licence, insurance and vehicle information. The application is reviewed before the profile is activated.',
          es: 'Cada conductor presenta una identificación y los documentos requeridos, incluida la licencia, el seguro y la información del vehículo. La solicitud se revisa antes de activar el perfil.',
        ),
        AppColors.primary,
      ),
      (
        Icons.person_outline,
        _tr(
          fr: 'Responsabilités du client',
          en: 'Customer responsibilities',
          es: 'Responsabilidades del cliente',
        ),
        _tr(
          fr: "Fournissez une description honnête de l'objet, ses dimensions et les conditions d'accès. Soyez présent ou joignable au moment convenu et assurez un accès sécuritaire aux lieux de collecte et de livraison.",
          en: 'Provide an honest description of the item, its dimensions and access conditions. Be present or reachable at the agreed time and ensure safe access to pickup and delivery locations.',
          es: 'Proporcione una descripción honesta del artículo, sus dimensiones y las condiciones de acceso. Esté presente o disponible en el horario acordado y garantice un acceso seguro a los lugares de recogida y entrega.',
        ),
        AppColors.primary,
      ),
      (
        Icons.block,
        _tr(
          fr: 'Objets interdits',
          en: 'Prohibited items',
          es: 'Artículos prohibidos',
        ),
        _tr(
          fr: 'Les matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus du service de livraison.',
          en: 'Hazardous materials, illegal goods, live animals and items requiring special permits are excluded from the delivery service.',
          es: 'Los materiales peligrosos, bienes ilegales, animales vivos y artículos que requieren permisos especiales están excluidos del servicio de entrega.',
        ),
        AppColors.error,
      ),
      (
        Icons.event_busy_outlined,
        _tr(
          fr: "Règles d'annulation",
          en: 'Cancellation rules',
          es: 'Reglas de cancelación',
        ),
        _tr(
          fr: "L'annulation est gratuite jusqu'à 2 heures avant le rendez-vous convenu. Une annulation tardive ou une absence peut entraîner des frais déterminés par le fournisseur.",
          en: 'Cancellation is free up to 2 hours before the agreed appointment. A late cancellation or no-show may result in a fee set by the provider.',
          es: 'La cancelación es gratuita hasta 2 horas antes de la cita acordada. Una cancelación tardía o ausencia puede generar un cargo determinado por el proveedor.',
        ),
        AppColors.warning,
      ),
      (
        Icons.report_problem_outlined,
        _tr(
          fr: "Signalement d'incident",
          en: 'Incident reporting',
          es: 'Reporte de incidentes',
        ),
        _tr(
          fr: "Signalez tout problème de sécurité, comportement non professionnel, absence ou situation dangereuse. Notre équipe examine chaque signalement manuellement.",
          en: 'Report any safety concern, unprofessional conduct, no-show or dangerous situation. Our team manually reviews every report.',
          es: 'Reporte cualquier problema de seguridad, conducta no profesional, ausencia o situación peligrosa. Nuestro equipo revisa manualmente cada reporte.',
        ),
        AppColors.error,
      ),
      (
        Icons.photo_camera_outlined,
        _tr(
          fr: 'Signalement de dommages',
          en: 'Damage reporting',
          es: 'Reporte de daños',
        ),
        _tr(
          fr: "En cas de dommage à un bien ou un véhicule, prenez des photos immédiatement et signalez-le dans les 24 heures suivant la livraison pour permettre un traitement rapide.",
          en: 'In case of damage to property or a vehicle, take photos immediately and report it within 24 hours of the delivery to allow for prompt handling.',
          es: 'En caso de daño a una propiedad o vehículo, tome fotos inmediatamente y repórtelo dentro de las 24 horas posteriores a la entrega para permitir una gestión rápida.',
        ),
        AppColors.error,
      ),
      (
        Icons.gavel_outlined,
        _tr(
          fr: 'Processus de résolution de litige',
          en: 'Dispute resolution process',
          es: 'Proceso de resolución de disputas',
        ),
        _tr(
          fr: "En cas de désaccord, contactez le soutien Movi-k avec les détails de la réservation. Un agent examine la situation et propose une résolution basée sur les preuves fournies par les deux parties.",
          en: 'If there is a disagreement, contact Movi-k support with the booking details. An agent reviews the situation and proposes a resolution based on evidence from both parties.',
          es: 'En caso de desacuerdo, contacte al soporte de Movi-k con los detalles de la reserva. Un agente revisa la situación y propone una resolución basada en la evidencia de ambas partes.',
        ),
        AppColors.primary,
      ),
      (
        Icons.local_hospital_outlined,
        _tr(fr: 'Urgences', en: 'Emergencies', es: 'Emergencias'),
        _tr(
          fr: "Movi-k n'est pas un service d'urgence. En cas de danger immédiat, d'accident ou de problème médical, composez le 911 avant de contacter la plateforme.",
          en: 'Movi-k is not an emergency service. In case of immediate danger, an accident or a medical issue, call 911 before contacting the platform.',
          es: 'Movi-k no es un servicio de emergencia. En caso de peligro inmediato, accidente o problema médico, llame al 911 antes de contactar la plataforma.',
        ),
        AppColors.error,
      ),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: t('nav_safety'),
                subtitle: _tr(
                  fr: 'La confiance et la sécurité sont au cœur de chaque livraison Movi-k.',
                  en: 'Trust and safety are at the heart of every Movi-k delivery.',
                  es: 'La confianza y la seguridad son el centro de cada entrega de Movi-k.',
                ),
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final isNarrow = MediaQuery.of(context).size.width < 480;
                  final icon = const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 28,
                  );
                  final message = Text(
                    _tr(
                      fr: 'Un problème pendant une livraison? Signalez-le immédiatement.',
                      en: 'An issue during a delivery? Report it right away.',
                      es: '¿Un problema durante una entrega? Repórtelo de inmediato.',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                  final reportButton = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => _showReportDialog(context),
                    child: Text(
                      _tr(
                        fr: 'Signaler un problème',
                        en: 'Report an issue',
                        es: 'Reportar un problema',
                      ),
                    ),
                  );

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  icon,
                                  const SizedBox(width: 16),
                                  Expanded(child: message),
                                ],
                              ),
                              const SizedBox(height: 16),
                              reportButton,
                            ],
                          )
                        : Row(
                            children: [
                              icon,
                              const SizedBox(width: 16),
                              Expanded(child: message),
                              const SizedBox(width: 12),
                              reportButton,
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 40),
              ...sections.map(
                (s) => _SafetySectionCard(
                  icon: s.$1,
                  title: s.$2,
                  description: s.$3,
                  color: s.$4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _tr(
            fr: 'Signaler un problème',
            en: 'Report an issue',
            es: 'Reportar un problema',
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: _tr(
              fr: 'Décrivez la situation…',
              en: 'Describe the situation…',
              es: 'Describa la situación…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr(fr: 'Annuler', en: 'Cancel', es: 'Cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _tr(
                      fr: "Signalement enregistré (démo). Notre équipe vous contactera.",
                      en: 'Report recorded (demo). Our team will contact you.',
                      es: 'Reporte registrado (demo). Nuestro equipo se pondrá en contacto.',
                    ),
                  ),
                ),
              );
            },
            child: Text(_tr(fr: 'Envoyer', en: 'Submit', es: 'Enviar')),
          ),
        ],
      ),
    );
  }
}

class _SafetySectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _SafetySectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
}
