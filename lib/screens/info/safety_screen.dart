import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

/// Safety & Incident Management page.
/// Covers provider verification, customer responsibilities, safe roadside
/// and workspace procedures, prohibited items/work, cancellation rules,
/// incident/damage reporting categories, dispute process and emergency
/// contact guidance — as required by the platform trust & safety spec.
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
        _tr(fr: 'Vérification des fournisseurs', en: 'Provider verification', es: 'Verificación de proveedores'),
        _tr(
          fr: "Chaque chauffeur et mécanicien mobile fournit une pièce d'identité et les documents requis (permis, assurance, immatriculation) qui sont examinés avant l'activation du profil. Le statut de vérification est affiché publiquement sur chaque profil.",
          en: 'Every driver and mobile mechanic submits an ID and the required documents (licence, insurance, registration), which are reviewed before the profile is activated. Verification status is displayed publicly on every profile.',
          es: 'Cada conductor y mecánico móvil presenta una identificación y los documentos requeridos (licencia, seguro, matrícula), que se revisan antes de activar el perfil. El estado de verificación se muestra públicamente en cada perfil.',
        ),
        AppColors.primary,
      ),
      (
        Icons.person_outline,
        _tr(fr: 'Responsabilités du client', en: 'Customer responsibilities', es: 'Responsabilidades del cliente'),
        _tr(
          fr: "Fournissez une description honnête de l'objet ou du problème mécanique, soyez présent (ou joignable) au moment convenu, et assurez un accès sécuritaire au lieu de collecte, de livraison ou d'intervention.",
          en: 'Provide an honest description of the item or mechanical problem, be present (or reachable) at the agreed time, and ensure safe access to the pickup, delivery or service location.',
          es: 'Proporcione una descripción honesta del artículo o problema mecánico, esté presente (o disponible) en el horario acordado y garantice un acceso seguro al lugar de recogida, entrega o servicio.',
        ),
        AppColors.primary,
      ),
      (
        Icons.warning_amber_outlined,
        _tr(fr: 'Procédures sécuritaires en bord de route', en: 'Safe roadside procedures', es: 'Procedimientos seguros en carretera'),
        _tr(
          fr: "En cas d'intervention en bord de route: activez vos feux de détresse, stationnez loin de la circulation, restez visible et attendez le fournisseur dans un endroit sécuritaire et bien éclairé.",
          en: 'For roadside service: turn on your hazard lights, park away from traffic, stay visible and wait for the provider in a safe, well-lit location.',
          es: 'Para servicio en carretera: encienda las luces de emergencia, estacione lejos del tráfico, permanezca visible y espere al proveedor en un lugar seguro y bien iluminado.',
        ),
        AppColors.success,
      ),
      (
        Icons.build_circle_outlined,
        _tr(fr: 'Exigences pour un espace de travail sécuritaire', en: 'Safe workspace requirements', es: 'Requisitos de espacio de trabajo seguro'),
        _tr(
          fr: "Le mécanicien mobile doit disposer d'un sol stable et plat, d'un éclairage adéquat et d'un espace hors des voies de circulation pour effectuer le travail en toute sécurité.",
          en: 'The mobile mechanic needs stable, flat ground, adequate lighting and space away from traffic lanes to safely carry out the work.',
          es: 'El mecánico móvil necesita un suelo estable y plano, iluminación adecuada y espacio fuera de los carriles de tráfico para realizar el trabajo con seguridad.',
        ),
        AppColors.success,
      ),
      (
        Icons.block,
        _tr(fr: 'Objets et travaux interdits', en: 'Prohibited items & work', es: 'Artículos y trabajos prohibidos'),
        _tr(
          fr: "Matières dangereuses, biens illégaux, animaux vivants et objets nécessitant un permis spécial sont exclus de la livraison. Les réparations majeures nécessitant un atelier équipé (ex.: remplacement de moteur) sont hors du cadre du service mobile.",
          en: 'Hazardous materials, illegal goods, live animals and items requiring special permits are excluded from delivery. Major repairs requiring a fully equipped shop (e.g. engine replacement) are outside the scope of mobile service.',
          es: 'Materiales peligrosos, bienes ilegales, animales vivos y artículos que requieren permisos especiales quedan excluidos de la entrega. Las reparaciones mayores que requieren un taller equipado (ej. reemplazo de motor) quedan fuera del alcance del servicio móvil.',
        ),
        AppColors.error,
      ),
      (
        Icons.event_busy_outlined,
        _tr(fr: "Règles d'annulation", en: 'Cancellation rules', es: 'Reglas de cancelación'),
        _tr(
          fr: "L'annulation est gratuite jusqu'à 2 heures avant le rendez-vous convenu. Une annulation tardive ou une absence peut entraîner des frais déterminés par le fournisseur.",
          en: 'Cancellation is free up to 2 hours before the agreed appointment. A late cancellation or no-show may result in a fee set by the provider.',
          es: 'La cancelación es gratuita hasta 2 horas antes de la cita acordada. Una cancelación tardía o ausencia puede generar un cargo determinado por el proveedor.',
        ),
        AppColors.warning,
      ),
      (
        Icons.report_problem_outlined,
        _tr(fr: "Signalement d'incident", en: 'Incident reporting', es: 'Reporte de incidentes'),
        _tr(
          fr: "Signalez tout problème de sécurité, comportement non professionnel, absence ou situation dangereuse via le bouton ci-dessous. Notre équipe examine chaque signalement manuellement.",
          en: 'Report any safety concern, unprofessional conduct, no-show or dangerous situation using the button below. Our team manually reviews every report.',
          es: 'Reporte cualquier problema de seguridad, conducta no profesional, ausencia o situación peligrosa con el botón de abajo. Nuestro equipo revisa manualmente cada reporte.',
        ),
        AppColors.error,
      ),
      (
        Icons.photo_camera_outlined,
        _tr(fr: 'Signalement de dommages', en: 'Damage reporting', es: 'Reporte de daños'),
        _tr(
          fr: "En cas de dommage à un bien ou un véhicule, prenez des photos immédiatement et signalez-le dans les 24 heures suivant le service pour permettre un traitement rapide.",
          en: 'In case of damage to property or a vehicle, take photos immediately and report it within 24 hours of the service to allow for prompt handling.',
          es: 'En caso de daño a una propiedad o vehículo, tome fotos inmediatamente y reporte dentro de las 24 horas posteriores al servicio para un manejo rápido.',
        ),
        AppColors.error,
      ),
      (
        Icons.gavel_outlined,
        _tr(fr: 'Processus de résolution de litige', en: 'Dispute resolution process', es: 'Proceso de resolución de disputas'),
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
                  fr: 'La confiance et la sécurité sont au cœur de chaque réservation Movi-k.',
                  en: 'Trust and safety are at the heart of every Movi-k booking.',
                  es: 'La confianza y la seguridad son el centro de cada reserva de Movi-k.',
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _tr(
                          fr: 'Un problème pendant une réservation? Signalez-le immédiatement.',
                          en: 'An issue during a booking? Report it right away.',
                          es: '¿Un problema durante una reserva? Repórtelo de inmediato.',
                        ),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                      onPressed: () => _showReportDialog(context),
                      child: Text(_tr(fr: 'Signaler un problème', en: 'Report an issue', es: 'Reportar un problema')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ...sections.map((s) => _SafetySectionCard(icon: s.$1, title: s.$2, description: s.$3, color: s.$4)),
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
        title: Text(_tr(fr: 'Signaler un problème', en: 'Report an issue', es: 'Reportar un problema')),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(fr: 'Annuler', en: 'Cancel', es: 'Cancelar'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tr(
                    fr: "Signalement enregistré (démo). Notre équipe vous contactera.",
                    en: 'Report recorded (demo). Our team will contact you.',
                    es: 'Reporte registrado (demo). Nuestro equipo se pondrá en contacto.',
                  )),
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
  const _SafetySectionCard({required this.icon, required this.title, required this.description, required this.color});

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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
