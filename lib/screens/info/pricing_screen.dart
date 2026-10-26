import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class PricingScreen extends StatelessWidget {
  final String locale;
  const PricingScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();

    // What makes the price. No amounts here (owner decision 2026-10-26):
    // the exact price is shown in the request flow, from the live grid.
    final factors = [
      (
        Icons.route_outlined,
        tr('Le trajet', 'The route', 'El trayecto'),
        tr(
          'La distance et la durée entre le ramassage et la livraison.',
          'The distance and time between pickup and delivery.',
          'La distancia y la duración entre la recogida y la entrega.',
        ),
      ),
      (
        Icons.weekend_outlined,
        tr('Le type d’objet', 'The type of item', 'El tipo de objeto'),
        tr(
          'Un supplément de manutention peut s’ajouter pour les objets lourds, comme un réfrigérateur ou un divan.',
          'A handling supplement may apply to heavy items, such as a refrigerator or a sofa.',
          'Puede añadirse un suplemento de manipulación para objetos pesados, como un refrigerador o un sofá.',
        ),
      ),
      (
        Icons.stairs_outlined,
        tr('Les options', 'Options', 'Las opciones'),
        tr(
          'L’aide au chargement, les escaliers ou un 2e déménageur, seulement si vous les demandez.',
          'Loading help, stairs or a second mover, only if you ask for them.',
          'Ayuda con la carga, escaleras o un segundo mozo, solo si los pides.',
        ),
      ),
      (
        Icons.receipt_long_outlined,
        tr(
          'Frais de service et taxes',
          'Service fee and taxes',
          'Cargo de servicio e impuestos',
        ),
        tr(
          'Les frais de service, la TPS et la TVQ sont affichés dans le détail du prix.',
          'The service fee, GST and QST are shown in the price breakdown.',
          'El cargo de servicio, la TPS y la TVQ se muestran en el desglose del precio.',
        ),
      ),
    ];

    final payment = [
      (
        Icons.credit_card_outlined,
        tr('1. Vous confirmez', '1. You confirm', '1. Confirmas'),
        tr(
          'Vous enregistrez votre carte. Rien n’est débité.',
          'You save your card. Nothing is charged.',
          'Registras tu tarjeta. No se cobra nada.',
        ),
      ),
      (
        Icons.local_shipping_outlined,
        tr(
          '2. Un chauffeur accepte',
          '2. A driver accepts',
          '2. Un conductor acepta',
        ),
        tr(
          'Le montant est réservé sur votre carte. C’est une autorisation, pas un débit.',
          'The amount is held on your card. It is an authorization, not a charge.',
          'El importe se reserva en tu tarjeta. Es una autorización, no un cobro.',
        ),
      ),
      (
        Icons.check_circle_outline,
        tr(
          '3. Livraison terminée',
          '3. Delivery completed',
          '3. Entrega completada',
        ),
        tr(
          'Seul le prix accepté est débité. Le reste de la réservation est libéré.',
          'Only the accepted price is charged. The rest of the hold is released.',
          'Solo se cobra el precio aceptado. El resto de la reserva se libera.',
        ),
      ),
    ];

    TextStyle sectionStyle() => const TextStyle(
      color: AppColors.primaryDark,
      fontSize: 22,
      fontWeight: FontWeight.w900,
    );

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
                  'Un prix clair, avant de réserver',
                  'A clear price, before you book',
                  'Un precio claro, antes de reservar',
                ),
                subtitle: tr(
                  'Prenez une photo, entrez vos adresses : vous voyez le prix exact, taxes et détail inclus, avant de confirmer.',
                  'Snap a photo, enter your addresses: you see the exact price, taxes and breakdown included, before you confirm.',
                  'Toma una foto, indica tus direcciones: ves el precio exacto, con impuestos y desglose, antes de confirmar.',
                ),
              ),
              const SizedBox(height: 28),
              Text(
                tr('Ce qui fait le prix', 'What makes the price', 'Qué forma el precio'),
                style: sectionStyle(),
              ),
              const SizedBox(height: 14),
              _CardGrid(maxColumns: 2, items: factors),
              const SizedBox(height: 20),
              _Notice(
                icon: Icons.lock_outline,
                title: tr(
                  'Votre prix ne bouge pas',
                  'Your price does not change',
                  'Tu precio no cambia',
                ),
                body: tr(
                  'Le prix que vous acceptez est figé : il ne change pas après la réservation. Si vous attendez trop longtemps avant de confirmer, un nouveau prix est calculé.',
                  'The price you accept is locked: it does not change after booking. If you wait too long before confirming, a new price is calculated.',
                  'El precio que aceptas queda fijado: no cambia después de reservar. Si esperas demasiado antes de confirmar, se calcula un nuevo precio.',
                ),
                tone: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                tr(
                  'Quand votre carte est-elle débitée ?',
                  'When is your card charged?',
                  '¿Cuándo se cobra tu tarjeta?',
                ),
                style: sectionStyle(),
              ),
              const SizedBox(height: 14),
              _CardGrid(maxColumns: 3, items: payment),
              const SizedBox(height: 10),
              Text(
                tr(
                  'Les paiements ouvriront au lancement du service à Granby.',
                  'Payments will open when the service launches in Granby.',
                  'Los pagos se abrirán con el lanzamiento del servicio en Granby.',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              _Notice(
                icon: Icons.event_busy_outlined,
                title: tr('Annulation', 'Cancellation', 'Cancelación'),
                body: tr(
                  'Gratuite avant qu’un chauffeur accepte, et aussi après si le ramassage est dans plus de 2 heures. Sinon, des frais de 30 $ s’appliquent. Les mêmes frais s’appliquent si le chauffeur se déplace pour rien. Le montant est toujours affiché avant de confirmer.',
                  'Free before a driver accepts, and also afterwards if pickup is more than 2 hours away. Otherwise, a $30 fee applies. The same fee applies if the driver makes a wasted trip. The amount is always shown before you confirm.',
                  'Gratuita antes de que un conductor acepte, y también después si la recogida es en más de 2 horas. Si no, se aplica un cargo de 30 $. El mismo cargo se aplica si el conductor se desplaza en vano. El importe siempre se muestra antes de confirmar.',
                ),
                tone: AppColors.warning,
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                key: const Key('pricing-start-request'),
                onPressed: () => context.go(DeliveryRequestIntent.path(locale)),
                icon: const Icon(Icons.request_quote_outlined),
                label: Text(
                  tr('Obtenir mon prix', 'Get my price', 'Obtener mi precio'),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr(
                  'Lancement prévu à Granby et dans les environs. La disponibilité d’un chauffeur est confirmée dans le parcours.',
                  'Launch planned for Granby and surrounding areas. Driver availability is confirmed in the request flow.',
                  'Lanzamiento previsto en Granby y alrededores. La disponibilidad de un conductor se confirma en el proceso.',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cards in 1 to [maxColumns] columns depending on width and text size.
class _CardGrid extends StatelessWidget {
  final int maxColumns;
  final List<(IconData, String, String)> items;
  const _CardGrid({required this.maxColumns, required this.items});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final roomy = scale <= 1.35;
      final columns = !roomy || constraints.maxWidth < 780
          ? 1
          : maxColumns >= 3 && constraints.maxWidth >= 980
          ? 3
          : maxColumns >= 2
          ? 2
          : 1;
      const gap = 16.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: _FactorCard(icon: item.$1, title: item.$2, body: item.$3),
            ),
        ],
      );
    },
  );
}

class _FactorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _FactorCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 14),
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
                body,
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

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color tone;
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: tone.withValues(alpha: .25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tone),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
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
