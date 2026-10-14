import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class DriverLandingScreen extends StatelessWidget {
  final String locale;
  const DriverLandingScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final benefits = [
      (
        Icons.schedule,
        tr('Horaire flexible', 'Flexible schedule', 'Horario flexible'),
        tr(
          'Passez en ligne lorsque vous êtes disponible.',
          'Go online when you are available.',
          'Conéctate cuando estés disponible.',
        ),
      ),
      (
        Icons.attach_money,
        tr(
          'Rémunération par mission',
          'Per-mission compensation',
          'Remuneración por misión',
        ),
        tr(
          'L’offre et les règles de rémunération sont présentées selon la configuration approuvée.',
          'The offer and compensation rules are presented according to the approved configuration.',
          'La oferta y las reglas de remuneración se presentan según la configuración aprobada.',
        ),
      ),
      (
        Icons.check_circle_outline,
        tr(
          'Choisissez vos demandes',
          'Choose your requests',
          'Elige tus solicitudes',
        ),
        tr(
          'N’acceptez que les livraisons qui vous conviennent.',
          'Accept only deliveries that suit you.',
          'Acepta solo las entregas que te convengan.',
        ),
      ),
      (
        Icons.map_outlined,
        tr('Définissez votre zone', 'Set your service area', 'Define tu zona'),
        tr(
          'Indiquez votre rayon de service dans votre profil chauffeur.',
          'Set your service radius in your driver profile.',
          'Indica tu radio de servicio en tu perfil de conductor.',
        ),
      ),
      (
        Icons.verified_user_outlined,
        tr(
          'Dossier à approuver',
          'Application review required',
          'Expediente sujeto a aprobación',
        ),
        tr(
          'Le profil, le véhicule et les documents requis doivent être approuvés avant l’activation.',
          'Your profile, vehicle and required documents must be approved before activation.',
          'El perfil, el vehículo y los documentos requeridos deben aprobarse antes de la activación.',
        ),
      ),
      (
        Icons.support_agent,
        tr(
          'Demandes via Movi‑K',
          'Requests through Movi‑K',
          'Solicitudes mediante Movi‑K',
        ),
        tr(
          'Les demandes admissibles peuvent être proposées aux chauffeurs disponibles.',
          'Eligible requests may be offered to available drivers.',
          'Las solicitudes admisibles pueden ofrecerse a conductores disponibles.',
        ),
      ),
    ];

    final vehicles = [
      tr('Camionnette', 'Pickup truck', 'Camioneta'),
      tr('Fourgon cargo', 'Cargo van', 'Furgón de carga'),
      tr('Camion cube', 'Box truck', 'Camión caja'),
      tr('Remorque', 'Trailer', 'Remolque'),
      tr('VUS avec remorque', 'SUV with trailer', 'SUV con remolque'),
      tr(
        'Véhicule commercial léger',
        'Light commercial vehicle',
        'Vehículo comercial ligero',
      ),
    ];

    return AppShell(
      locale: locale,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.deliveryGradient,
            ),
            child: ResponsivePadding(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 48),
                child: Column(
                  crossAxisAlignment: isDesktop
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(
                      t('driver_hero_headline'),
                      textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 42 : 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Text(
                        t('driver_hero_sub'),
                        textAlign: isDesktop
                            ? TextAlign.left
                            : TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: () =>
                          context.go('/$locale/devenir-chauffeur/inscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryLight,
                      ),
                      child: Text(
                        tr(
                          "S'inscrire comme chauffeur",
                          'Sign up as a driver',
                          'Registrarse como conductor',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ResponsivePadding(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    title: tr(
                      'Véhicules admissibles',
                      'Eligible vehicles',
                      'Vehículos admisibles',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: vehicles
                        .map(
                          (v) => Chip(
                            avatar: const Icon(
                              Icons.directions_car_filled_outlined,
                              size: 16,
                            ),
                            label: Text(v),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 48),
                  SectionTitle(title: tr('Avantages', 'Benefits', 'Ventajas')),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final columns = scale > 1.35
                          ? 1
                          : isDesktop
                          ? 3
                          : constraints.maxWidth > 600
                          ? 2
                          : 1;
                      const gap = 18.0;
                      final cardWidth = columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final b in benefits)
                            SizedBox(
                              width: cardWidth,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(b.$1, color: AppColors.primary),
                                    const SizedBox(height: 10),
                                    Text(
                                      b.$2,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      b.$3,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calculate_outlined,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(
                              'Les offres et règles de rémunération affichées au chauffeur proviennent de la configuration serveur et des conditions applicables. Aucun revenu n’est garanti.',
                              'Driver offers and compensation rules come from server configuration and applicable terms. No income is guaranteed.',
                              'Las ofertas y reglas de remuneración del conductor provienen de la configuración del servidor y las condiciones aplicables. No se garantiza ningún ingreso.',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/$locale/devenir-chauffeur/inscription'),
                      child: Text(
                        tr(
                          "S'inscrire comme chauffeur",
                          'Sign up as a driver',
                          'Registrarse como conductor',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
