// Carte d'estimation par codes postaux (Daniel, 2026-11-26), partagée par
// l'accueil, la page Tarifs et les pages par objet, enseigne et ville.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../l10n/home_copy.dart';
import '../providers/locale_provider.dart';
import '../seo/estimate_page.dart';
import '../seo/seo_pages.dart' show seoSiteUrl;

/// Opens the estimate page at [path] ('/fr/estimation?de=…&a=…&poids=…').
typedef EstimateOpener = Future<void> Function(String path);

/// Estimate by postal codes (Daniel, 2026-11-26): two postal codes and a
/// weight open the lightweight estimate page, which shows a price range
/// with no account. On the home page, the pricing page and the pages by
/// item, store and city.
class EstimateCard extends StatefulWidget {
  /// Tests inject a recorder; the app opens the lightweight estimate page.
  final EstimateOpener? onEstimate;

  /// Start of the widget keys, so each page keeps its own.
  final String keyPrefix;

  /// Language of the page; the language of the app when absent.
  final String? locale;

  /// Wide layout (home page on a computer): the two postal codes side by
  /// side, the photo link beside the button. The caller decides from the
  /// screen width: the card sits inside an IntrinsicHeight there, which a
  /// LayoutBuilder would not allow.
  final bool wide;
  const EstimateCard({
    super.key,
    this.onEstimate,
    this.keyPrefix = 'estimate',
    this.locale,
    this.wide = false,
  });

  /// The estimate page is plain HTML served next to the app: same tab on
  /// the web, the site in the browser from the Android app.
  static Future<void> openPage(String path) async {
    final uri = kIsWeb ? Uri.base.resolve(path) : Uri.parse('$seoSiteUrl$path');
    await launchUrl(
      uri,
      webOnlyWindowName: '_self',
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  @override
  State<EstimateCard> createState() => _EstimateCardState();
}

class _EstimateCardState extends State<EstimateCard> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _weight = 'medium';
  bool _invalid = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _submit(String locale) {
    final from = normalizePostalCode(_from.text);
    final to = normalizePostalCode(_to.text);
    if (from == null || to == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    (widget.onEstimate ?? EstimateCard.openPage)(
      estimateLink(locale, from: from, to: to, weight: _weight),
    );
  }

  /// "Not sure? Add a photo": the estimate page, where an AI recognizes the
  /// item on the photo and picks the weight (2026-11-26). What is already
  /// typed follows.
  void _photo(String locale) {
    (widget.onEstimate ?? EstimateCard.openPage)(
      estimatePhotoLink(
        locale,
        from: normalizePostalCode(_from.text),
        to: normalizePostalCode(_to.text),
        weight: _weight,
      ),
    );
  }

  // The label is a separate text above the field: it wraps at large text
  // sizes instead of being cut inside the field.
  Widget _field(String label, TextEditingController controller, Key key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF21436F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: label,
            child: TextField(
              key: key,
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(7)],
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                isDense: true,
                // The card is white in both themes.
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale ?? context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);
    final fromField = _field(
      h('estimate_from'),
      _from,
      Key('${widget.keyPrefix}-from'),
    );
    final toField = _field(
      h('estimate_to'),
      _to,
      Key('${widget.keyPrefix}-to'),
    );
    final photoButton = TextButton.icon(
      key: Key('${widget.keyPrefix}-photo'),
      onPressed: () => _photo(locale),
      icon: const Icon(Icons.photo_camera_outlined, size: 20),
      label: Text(h('estimate_photo')),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF075FC4),
        minimumSize: const Size.fromHeight(52),
      ),
    );
    final submitButton = ElevatedButton(
      key: Key('${widget.keyPrefix}-submit'),
      onPressed: () => _submit(locale),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(h('estimate_button')),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEBFA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              h('estimate_title'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fromField),
                  const SizedBox(width: 12),
                  Expanded(child: toField),
                ],
              )
            else ...[
              fromField,
              const SizedBox(height: 12),
              toField,
            ],
            const SizedBox(height: 12),
            Text(
              h('estimate_what'),
              style: const TextStyle(
                color: Color(0xFF21436F),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final weight in estimateWeights) ...[
                  if (weight != estimateWeights.first) const SizedBox(width: 8),
                  Expanded(
                    child: _WeightOption(
                      key: Key('${widget.keyPrefix}-$weight'),
                      title: h('estimate_$weight'),
                      subtitle: h('estimate_${weight}_sub'),
                      selected: _weight == weight,
                      onTap: () => setState(() => _weight = weight),
                    ),
                  ),
                ],
              ],
            ),
            if (_invalid) ...[
              const SizedBox(height: 8),
              Text(
                h('estimate_invalid'),
                key: Key('${widget.keyPrefix}-invalid'),
                style: const TextStyle(
                  color: Color(0xFFA33A2F),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (widget.wide)
              Row(
                children: [
                  Expanded(child: photoButton),
                  const SizedBox(width: 12),
                  Expanded(child: submitButton),
                ],
              )
            else ...[
              photoButton,
              const SizedBox(height: 8),
              submitButton,
            ],
            const SizedBox(height: 10),
            Text(
              h('estimate_card_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightOption extends StatelessWidget {
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _WeightOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6EDFA) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryDark : const Color(0xFF8A96AD),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3D4A66),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
