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

    // Only what the product really does today (checked 2026-10-26):
    // driver approval, pickup/delivery photos (#75), card on Stripe's hosted
    // page, driver position readable by the customer only during their
    // active mission (firestore.rules, driver_locations). No insurance
    // coverage and no claim deadline are promised.
    final sections = <(IconData, String, String, Color)>[
      (
        Icons.verified_user_outlined,
        tr('Chauffeurs vérifiés', 'Verified drivers', 'Conductores verificados'),
        tr(
          'Chaque chauffeur fournit son permis de conduire, son assurance et les informations de son véhicule. L’équipe Movi‑K approuve son dossier avant qu’il puisse recevoir des demandes.',
          'Every driver provides their driver’s licence, insurance and vehicle details. The Movi‑K team approves their file before they can receive requests.',
          'Cada conductor presenta su licencia de conducir, su seguro y los datos de su vehículo. El equipo de Movi‑K aprueba su expediente antes de que pueda recibir solicitudes.',
        ),
        AppColors.primary,
      ),
      (
        Icons.photo_camera_outlined,
        tr(
          'Photos au ramassage et à la livraison',
          'Photos at pickup and delivery',
          'Fotos al recoger y al entregar',
        ),
        tr(
          'Le chauffeur prend une photo de vos objets au ramassage, puis à la livraison. Vous les voyez dans votre espace : elles servent de preuve en cas de problème.',
          'The driver takes a photo of your items at pickup, then at delivery. You see them in your account: they serve as proof if something goes wrong.',
          'El conductor toma una foto de tus objetos al recogerlos y al entregarlos. Las ves en tu cuenta: sirven de prueba si hay un problema.',
        ),
        AppColors.primary,
      ),
      (
        Icons.lock_outline,
        tr('Paiement protégé', 'Protected payment', 'Pago protegido'),
        tr(
          'Votre carte est enregistrée sur la page sécurisée de Stripe : Movi‑K ne voit jamais votre numéro de carte. Le montant n’est débité qu’à la livraison.',
          'Your card is saved on Stripe’s secure page: Movi‑K never sees your card number. The amount is only charged at delivery.',
          'Tu tarjeta se guarda en la página segura de Stripe: Movi‑K nunca ve tu número de tarjeta. El importe solo se cobra en la entrega.',
        ),
        AppColors.primary,
      ),
      (
        Icons.gps_fixed,
        tr(
          'Position partagée pendant la livraison',
          'Location shared during the delivery',
          'Ubicación compartida durante la entrega',
        ),
        tr(
          'Vous voyez la position de votre chauffeur seulement pendant votre livraison en cours. Une fois la livraison terminée, elle n’est plus visible.',
          'You see your driver’s location only during your delivery in progress. Once the delivery is completed, it is no longer visible.',
          'Ves la ubicación de tu conductor solo durante tu entrega en curso. Una vez terminada la entrega, deja de ser visible.',
        ),
        AppColors.primary,
      ),
      (
        Icons.person_outline,
        tr('Votre part', 'Your part', 'Tu parte'),
        tr(
          'Prenez des photos fidèles de vos objets, indiquez les escaliers et les accès difficiles, et assurez un passage sécuritaire (entrée déneigée l’hiver). Soyez présent, ou quelqu’un pour vous, au ramassage et à la livraison.',
          'Take accurate photos of your items, mention stairs and difficult access, and make sure the way is safe (cleared of snow in winter). Be there, or have someone there for you, at pickup and delivery.',
          'Toma fotos fieles de tus objetos, indica las escaleras y los accesos difíciles, y asegura un paso seguro (entrada sin nieve en invierno). Está presente, o alguien por ti, al recoger y al entregar.',
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
        Icons.report_outlined,
        tr('En cas de problème', 'If something goes wrong', 'Si hay un problema'),
        tr(
          'Signalez-le rapidement depuis la page Contact, avec le numéro de votre livraison et vos photos. Nous examinons chaque signalement.',
          'Report it quickly from the Contact page, with your delivery number and your photos. We review every report.',
          'Infórmalo rápidamente desde la página de Contacto, con el número de tu entrega y tus fotos. Revisamos cada reporte.',
        ),
        AppColors.warning,
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
                  'Comment Movi‑K protège vos objets, votre paiement et vos données.',
                  'How Movi‑K protects your items, your payment and your data.',
                  'Cómo Movi‑K protege tus objetos, tu pago y tus datos.',
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
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.support_agent_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(
                              'Une question sur la sécurité ou une livraison ? Écrivez-nous depuis la page Contact.',
                              'A question about safety or a delivery? Write to us from the Contact page.',
                              '¿Una pregunta sobre seguridad o una entrega? Escríbenos desde la página de Contacto.',
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/$locale/contact'),
                        child: Text(tr('Contact', 'Contact', 'Contacto')),
                      ),
                    ),
                  ],
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
