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

    // 2026-11-13 (propriétaire) : la page s'ouvre sur le gain. Fourchette
    // annoncée aux recrues ; la paye exacte est sur chaque offre.
    final earnings = [
      (
        Icons.attach_money,
        tr(
          'Environ 80 \$ à 120 \$ par livraison',
          'About \$80 to \$120 per delivery',
          'Unos 80 \$ a 120 \$ por entrega',
        ),
        tr(
          'Pour 2 à 4 articles. Chaque offre affiche votre paye avant que vous acceptiez.',
          'For 2 to 4 items. Every offer shows your pay before you accept.',
          'Por 2 a 4 artículos. Cada oferta muestra tu pago antes de que aceptes.',
        ),
      ),
      (
        Icons.volunteer_activism_outlined,
        tr('100 % des pourboires', '100% of tips', '100 % de las propinas'),
        tr(
          'Chaque dollar de pourboire vous revient.',
          'Every tip dollar goes to you.',
          'Cada dólar de propina es para ti.',
        ),
      ),
      (
        Icons.account_balance_outlined,
        tr(
          'Payé dans votre compte bancaire',
          'Paid into your bank account',
          'Pagado en tu cuenta bancaria',
        ),
        tr(
          'Stripe dépose votre paye. Movi‑K ne voit jamais votre numéro de compte.',
          'Stripe deposits your pay. Movi‑K never sees your account number.',
          'Stripe deposita tu pago. Movi‑K nunca ve tu número de cuenta.',
        ),
      ),
    ];

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
          'Vous recevez seulement les livraisons dans le rayon que vous choisissez.',
          'You only receive deliveries within the radius you choose.',
          'Solo recibes entregas dentro del radio que elijas.',
        ),
      ),
    ];

    final steps = [
      (
        tr('Créez votre compte', 'Create your account', 'Crea tu cuenta'),
        tr(
          'Votre nom, votre courriel et votre téléphone.',
          'Your name, email and phone.',
          'Tu nombre, tu correo y tu teléfono.',
        ),
      ),
      (
        tr(
          'Ajoutez votre véhicule et vos documents',
          'Add your vehicle and your documents',
          'Añade tu vehículo y tus documentos',
        ),
        tr(
          'Permis de conduire recto verso, immatriculation, assurance et photos du véhicule.',
          'Driver’s licence front and back, registration, insurance and photos of the vehicle.',
          'Licencia de conducir por ambos lados, matrícula, seguro y fotos del vehículo.',
        ),
      ),
      (
        tr(
          'Activez vos paiements avec Stripe',
          'Turn on your payments with Stripe',
          'Activa tus pagos con Stripe',
        ),
        tr(
          'Stripe vérifie votre identité et votre compte bancaire, pour y déposer votre paye.',
          'Stripe verifies your identity and your bank account, to deposit your pay there.',
          'Stripe verifica tu identidad y tu cuenta bancaria, para depositar allí tu pago.',
        ),
      ),
      (
        tr(
          'Movi‑K approuve votre dossier',
          'Movi‑K approves your application',
          'Movi‑K aprueba tu expediente',
        ),
        tr(
          'Ensuite, vous recevez des offres et vous acceptez celles qui vous conviennent.',
          'Then you receive offers and accept the ones that suit you.',
          'Luego recibes ofertas y aceptas las que te convengan.',
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

    Widget cards(List<(IconData, String, String)> items) => LayoutBuilder(
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
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final b in items)
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
    );

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
                    key: const ValueKey('driver-landing-earnings'),
                    title: tr(
                      'Ce que vous gagnez',
                      'What you earn',
                      'Lo que ganas',
                    ),
                  ),
                  const SizedBox(height: 24),
                  cards(earnings),
                  const SizedBox(height: 48),
                  SectionTitle(
                    title: tr(
                      'Comment ça marche',
                      'How it works',
                      'Cómo funciona',
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      key: ValueKey('driver-landing-step-${i + 1}'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  steps[i].$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  steps[i].$2,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
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
                  cards(benefits),
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
                          Icons.info_outline,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(
                              'Les montants sont des exemples. Votre paye dépend de la distance, des objets et du nombre de demandes dans votre secteur. Votre véhicule doit être assuré, à vos frais. Aucun revenu n’est garanti.',
                              'Amounts are examples. Your pay depends on the distance, the items and the number of requests in your area. Your vehicle must be insured, at your expense. No income is guaranteed.',
                              'Los montos son ejemplos. Tu pago depende de la distancia, los objetos y la cantidad de solicitudes en tu zona. Tu vehículo debe estar asegurado, a tu cargo. No se garantiza ningún ingreso.',
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
