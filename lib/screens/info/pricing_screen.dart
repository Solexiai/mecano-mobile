import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
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

    final factors = [
      (
        Icons.route_outlined,
        tr('Trajet', 'Route', 'Trayecto'),
        tr(
          'La distance et la durée de l’itinéraire sont calculées côté serveur.',
          'Route distance and duration are calculated on the server.',
          'La distancia y la duración de la ruta se calculan en el servidor.',
        ),
      ),
      (
        Icons.local_shipping_outlined,
        tr('Véhicule requis', 'Required vehicle', 'Vehículo necesario'),
        tr(
          'Le type de véhicule sélectionné fait partie du calcul du devis.',
          'The selected vehicle type is part of the quote calculation.',
          'El tipo de vehículo seleccionado forma parte del cálculo.',
        ),
      ),
      (
        Icons.inventory_2_outlined,
        tr(
          'Objet et manutention',
          'Item and handling',
          'Objeto y manipulación',
        ),
        tr(
          'Les options déclarées, comme les escaliers, l’aide à la manutention ou les contraintes d’accès, peuvent influencer le devis.',
          'Declared options such as stairs, handling assistance or access constraints may affect the quote.',
          'Las opciones declaradas, como escaleras, ayuda de manipulación o restricciones de acceso, pueden influir en el presupuesto.',
        ),
      ),
      (
        Icons.receipt_long_outlined,
        tr(
          'Ventilation avant confirmation',
          'Breakdown before confirmation',
          'Desglose antes de confirmar',
        ),
        tr(
          'Le prix officiel et sa ventilation sont présentés avant que vous confirmiez la demande.',
          'The official price and its breakdown are shown before you confirm the request.',
          'El precio oficial y su desglose se muestran antes de confirmar la solicitud.',
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
                title: tr('Tarifs', 'Pricing', 'Precios'),
                subtitle: tr(
                  'Le devis officiel est calculé par Movi‑K à partir des renseignements de votre demande.',
                  'The official quote is calculated by Movi‑K from the information in your request.',
                  'El presupuesto oficial lo calcula Movi‑K a partir de los datos de tu solicitud.',
                ),
              ),
              const SizedBox(height: 28),
              _Notice(
                icon: Icons.calculate_outlined,
                title: tr(
                  'Un devis calculé par Movi‑K',
                  'A quote calculated by Movi‑K',
                  'Un presupuesto calculado por Movi‑K',
                ),
                body: tr(
                  'Le montant n’est pas fixé manuellement par le chauffeur. Le calcul officiel est effectué côté serveur et le client peut vérifier le prix avant de confirmer.',
                  'The amount is not manually set by the driver. The official calculation runs on the server and the customer can review the price before confirming.',
                  'El importe no lo fija manualmente el conductor. El cálculo oficial se realiza en el servidor y el cliente puede revisar el precio antes de confirmar.',
                ),
                tone: AppColors.primary,
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final columns = constraints.maxWidth >= 780 && scale <= 1.35
                      ? 2
                      : 1;
                  final gap = 16.0;
                  final width = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final factor in factors)
                        SizedBox(
                          width: width,
                          child: _FactorCard(
                            icon: factor.$1,
                            title: factor.$2,
                            body: factor.$3,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _Notice(
                icon: Icons.credit_card_outlined,
                title: tr(
                  'Paiement au lancement',
                  'Payment at launch',
                  'Pago en el lanzamiento',
                ),
                body: tr(
                  'Les modalités de paiement en production sont encore en validation pour le lancement à Granby. Cette page n’annonce donc ni paiement comptant, ni Interac, ni disponibilité publique de Stripe tant que l’activation réelle n’a pas été confirmée.',
                  'Production payment methods are still being validated for the Granby launch. This page therefore does not advertise cash, Interac or public Stripe availability until live activation has been confirmed.',
                  'Los métodos de pago en producción siguen en validación para el lanzamiento en Granby. Por eso esta página no anuncia efectivo, Interac ni disponibilidad pública de Stripe hasta confirmar la activación real.',
                ),
                tone: AppColors.warning,
              ),
              const SizedBox(height: 18),
              _Notice(
                icon: Icons.account_balance_wallet_outlined,
                title: tr(
                  'Rémunération et commission',
                  'Driver compensation and platform fees',
                  'Remuneración y comisión',
                ),
                body: tr(
                  'Les règles financières applicables sont déterminées par la configuration serveur et les conditions approuvées. Aucun taux de commission non approuvé n’est publié ici.',
                  'Applicable financial rules are determined by server configuration and approved terms. No unapproved commission rate is published here.',
                  'Las reglas financieras aplicables se determinan mediante la configuración del servidor y las condiciones aprobadas. Aquí no se publica ninguna comisión no aprobada.',
                ),
                tone: AppColors.primary,
              ),
              const SizedBox(height: 22),
              Text(
                tr(
                  'Lancement prévu à Granby et dans les environs. La disponibilité d’un chauffeur et l’ouverture des transactions doivent être confirmées dans le parcours.',
                  'Launch planned for Granby and surrounding areas. Driver availability and transaction availability must be confirmed in the flow.',
                  'Lanzamiento previsto en Granby y alrededores. La disponibilidad de conductor y de transacciones debe confirmarse en el proceso.',
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
