import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/locale_provider.dart';

/// Charge l'équilibre d'une période (callable `getMarketBalance`).
typedef MarketBalanceLoader =
    Future<Map<String, dynamic>> Function(DateTime from, DateTime to);

/// Lundi 0 h (heure locale) de la semaine qui contient [day].
DateTime startOfWeek(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _int(Object? value) => value is num ? value.toInt() : 0;
double? _double(Object? value) => value is num ? value.toDouble() : null;

class CityBalanceView {
  CityBalanceView.fromJson(Map<String, dynamic> json)
    : key = json['key'] as String? ?? '',
      label = json['label'] as String? ?? '',
      verdict = json['verdict'] as String? ?? 'not_enough_data',
      reasons = [
        for (final r in (json['reasons'] as List? ?? const [])) r.toString(),
      ],
      requests = _int(json['requests']),
      accepted = _int(json['accepted']),
      noDriver = _int(json['noDriver']),
      pending = _int(json['pending']),
      acceptanceRate = _double(json['acceptanceRate']),
      medianAcceptMinutes = _double(json['medianAcceptMinutes']),
      completed = _int(json['completed']),
      activeDrivers = _int(json['activeDrivers']),
      approvedDrivers = _int(json['approvedDrivers']),
      onlineDriversNow = _int(json['onlineDriversNow']),
      jobsPerDriverPerWeek = _double(json['jobsPerDriverPerWeek']),
      availableHours = _double(json['availableHours']),
      offersSent = _int(_map(json['offers'])['sent']),
      offersDeclined = _int(_map(json['offers'])['declined']),
      offersExpired = _int(_map(json['offers'])['expired']),
      declineReasons = _map(
        json['declineReasons'],
      ).map((k, v) => MapEntry(k, _int(v))),
      quotesNotBooked = _int(json['quotesNotBooked']);

  final String key;
  final String label;
  final String verdict;
  final List<String> reasons;
  final int requests;
  final int accepted;
  final int noDriver;
  final int pending;
  final double? acceptanceRate;
  final double? medianAcceptMinutes;
  final int completed;
  final int activeDrivers;
  final int approvedDrivers;
  final int onlineDriversNow;
  final double? jobsPerDriverPerWeek;
  final double? availableHours;
  final int offersSent;
  final int offersDeclined;
  final int offersExpired;
  final Map<String, int> declineReasons;
  final int quotesNotBooked;
}

class MarketBalanceReport {
  MarketBalanceReport.fromJson(Map<String, dynamic> json)
    : availabilityMeasured = json['availabilityMeasured'] == true,
      truncated = json['truncated'] == true,
      total = CityBalanceView.fromJson(_map(json['total'])),
      cities = [
        for (final c in (json['cities'] as List? ?? const []))
          CityBalanceView.fromJson(_map(c)),
      ],
      minAcceptanceRate =
          _double(_map(json['thresholds'])['minAcceptanceRate']) ?? 0.85,
      minJobsPerDriverPerWeek =
          _double(_map(json['thresholds'])['minJobsPerDriverPerWeek']) ?? 2;

  final bool availabilityMeasured;
  final bool truncated;
  final CityBalanceView total;
  final List<CityBalanceView> cities;
  final double minAcceptanceRate;
  final double minJobsPerDriverPerWeek;
}

/// Tableau Admin : chauffeurs et clients ville par ville, pour une semaine.
class AdminMarketBalanceScreen extends StatefulWidget {
  const AdminMarketBalanceScreen({super.key, this.loader, this.clock});

  final MarketBalanceLoader? loader;
  final DateTime Function()? clock;

  @override
  State<AdminMarketBalanceScreen> createState() =>
      _AdminMarketBalanceScreenState();
}

class _AdminMarketBalanceScreenState extends State<AdminMarketBalanceScreen> {
  late DateTime _weekStart;
  late Future<MarketBalanceReport> _report;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _weekStart = startOfWeek(_now());
    _report = _load();
  }

  DateTime get _weekEnd =>
      DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);

  Future<MarketBalanceReport> _load() async {
    final from = _weekStart;
    final to = _weekEnd;
    final Map<String, dynamic> data;
    if (widget.loader != null) {
      data = await widget.loader!(from, to);
    } else {
      final response = await FirebaseFunctions.instance
          .httpsCallable('getMarketBalance')
          .call({
            'fromMillis': from.millisecondsSinceEpoch,
            'toMillis': to.millisecondsSinceEpoch,
          });
      data = _map(response.data);
    }
    return MarketBalanceReport.fromJson(data);
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _weekStart = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + 7 * weeks,
      );
      _report = _load();
    });
  }

  void _reload() {
    setState(() {
      _report = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final fr = locale != 'en';
    final canGoForward = _weekEnd.isBefore(_now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: fr ? 'Retour' : 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/$locale/admin'),
        ),
        title: Text(fr ? 'Équilibre par ville' : 'Balance by city'),
        actions: [
          IconButton(
            tooltip: fr ? 'Actualiser' : 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WeekPicker(
                    label: _weekLabel(fr),
                    fr: fr,
                    onPrevious: () => _shiftWeek(-1),
                    onNext: canGoForward ? () => _shiftWeek(1) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fr
                        ? 'Deux signaux par ville : le taux d’acceptation (s’il baisse, il manque des chauffeurs) et les livraisons par chauffeur (si elles baissent, il manque des clients).'
                        : 'Two signals per city: the acceptance rate (when it drops, drivers are short) and deliveries per driver (when they drop, customers are short).',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<MarketBalanceReport>(
                    future: _report,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return _Message(
                          icon: Icons.error_outline,
                          text: fr
                              ? 'Impossible de charger l’équilibre. Réessayez.'
                              : 'Could not load the balance. Please retry.',
                          action: TextButton(
                            onPressed: _reload,
                            child: Text(fr ? 'Réessayer' : 'Retry'),
                          ),
                        );
                      }
                      return _ReportView(report: snapshot.data!, fr: fr);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekLabel(bool fr) {
    const frMonths = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final last = DateTime(_weekEnd.year, _weekEnd.month, _weekEnd.day - 1);
    String day(DateTime d) => fr
        ? '${d.day} ${frMonths[d.month - 1]}'
        : '${enMonths[d.month - 1]} ${d.day}';
    return fr
        ? 'Semaine du ${day(_weekStart)} au ${day(last)} ${last.year}'
        : 'Week of ${day(_weekStart)} – ${day(last)}, ${last.year}';
  }
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.label,
    required this.fr,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool fr;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: fr ? 'Semaine précédente' : 'Previous week',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        tooltip: fr ? 'Semaine suivante' : 'Next week',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report, required this.fr});

  final MarketBalanceReport report;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.truncated)
          _Message(
            icon: Icons.warning_amber_outlined,
            text: fr
                ? 'Beaucoup de données cette semaine : une partie seulement a été lue.'
                : 'Lots of data this week: only part of it was read.',
          ),
        if (!report.availabilityMeasured)
          _Message(
            icon: Icons.info_outline,
            text: fr
                ? 'Les heures en ligne des chauffeurs se mesurent à partir de la mise en service de ce tableau : elles apparaîtront pour les semaines suivantes.'
                : 'Driver online hours are measured from the day this dashboard went live: they will show for the following weeks.',
          ),
        _CityCard(city: report.total, fr: fr, isTotal: true),
        const SizedBox(height: 14),
        if (report.cities.isEmpty)
          _Message(
            icon: Icons.inbox_outlined,
            text: fr
                ? 'Aucune demande ni aucun chauffeur approuvé pour cette semaine.'
                : 'No requests and no approved drivers for this week.',
          )
        else
          for (final city in report.cities) ...[
            _CityCard(city: city, fr: fr),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 8),
        Text(
          fr
              ? 'Seuils de départ : il manque des chauffeurs sous ${(report.minAcceptanceRate * 100).round()} % d’acceptation ou dès qu’un client reste sans chauffeur ; il manque des clients sous ${_number(report.minJobsPerDriverPerWeek, fr)} livraisons par chauffeur par semaine. À ajuster après le pilote.'
              : 'Starting thresholds: drivers are short below ${(report.minAcceptanceRate * 100).round()}% acceptance or as soon as a customer is left without a driver; customers are short below ${_number(report.minJobsPerDriverPerWeek, fr)} deliveries per driver per week. To be tuned after the pilot.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

String _number(double value, bool fr) {
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return fr ? text.replaceAll('.', ',') : text;
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.city, required this.fr, this.isTotal = false});

  final CityBalanceView city;
  final bool fr;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final verdict = _verdict(city.verdict, fr);
    final rate = city.acceptanceRate;
    final lines = <String>[
      fr
          ? '${city.requests} demande(s) · ${city.accepted} prise(s)${rate == null ? '' : ' (${(rate * 100).round()} %)'} · ${city.noDriver} sans chauffeur${city.pending > 0 ? ' · ${city.pending} en recherche' : ''}'
          : '${city.requests} request(s) · ${city.accepted} taken${rate == null ? '' : ' (${(rate * 100).round()}%)'} · ${city.noDriver} without a driver${city.pending > 0 ? ' · ${city.pending} searching' : ''}',
      if (city.medianAcceptMinutes != null)
        fr
            ? 'Délai médian avant qu’un chauffeur accepte : ${_duration(city.medianAcceptMinutes!, fr)}'
            : 'Median time before a driver accepts: ${_duration(city.medianAcceptMinutes!, fr)}',
      fr
          ? '${city.approvedDrivers} chauffeur(s) approuvé(s) · ${city.onlineDriversNow} en ligne maintenant · ${city.activeDrivers} actif(s) cette semaine'
          : '${city.approvedDrivers} approved driver(s) · ${city.onlineDriversNow} online now · ${city.activeDrivers} active this week',
      fr
          ? '${city.completed} livraison(s)${city.jobsPerDriverPerWeek == null ? '' : ' · ${_number(city.jobsPerDriverPerWeek!, fr)} par chauffeur par semaine'}'
          : '${city.completed} deliver(ies)${city.jobsPerDriverPerWeek == null ? '' : ' · ${_number(city.jobsPerDriverPerWeek!, fr)} per driver per week'}',
      if (city.availableHours != null)
        fr
            ? 'Heures en ligne des chauffeurs : ${_number(city.availableHours!, fr)} h'
            : 'Driver online hours: ${_number(city.availableHours!, fr)} h',
      if (city.offersSent > 0)
        fr
            ? 'Offres : ${city.offersSent} envoyée(s), ${city.offersDeclined} refusée(s), ${city.offersExpired} expirée(s)'
            : 'Offers: ${city.offersSent} sent, ${city.offersDeclined} declined, ${city.offersExpired} expired',
      if (city.declineReasons.isNotEmpty)
        '${fr ? 'Raisons de refus' : 'Decline reasons'} : ${city.declineReasons.entries.map((e) => '${_reason(e.key, fr)} ${e.value}').join(', ')}',
      if (city.quotesNotBooked > 0)
        fr
            ? 'Prix vus sans réservation : ${city.quotesNotBooked}'
            : 'Prices seen without booking: ${city.quotesNotBooked}',
    ];
    return Container(
      key: ValueKey('market-city-${city.key}'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTotal ? AppColors.primary : AppColors.border,
          width: isTotal ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isTotal ? (fr ? 'Toutes les villes' : 'All cities') : city.label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: verdict.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  verdict.label,
                  style: TextStyle(
                    color: verdict.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
          if (verdict.action != null) ...[
            const SizedBox(height: 8),
            Text(
              verdict.action!,
              style: TextStyle(
                color: verdict.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _duration(double minutes, bool fr) {
  if (minutes < 60) return '${minutes.round()} min';
  final hours = minutes / 60;
  return '${_number((hours * 10).round() / 10, fr)} h';
}

String _reason(String key, bool fr) => switch (key) {
  'too_far' => fr ? 'trop loin' : 'too far',
  'price_too_low' => fr ? 'prix trop bas' : 'price too low',
  'no_space' => fr ? 'pas de place' : 'no room',
  'not_available' => fr ? 'pas disponible' : 'not available',
  'other' => fr ? 'autre' : 'other',
  _ => fr ? 'sans raison' : 'no reason',
};

class _Verdict {
  const _Verdict(this.label, this.color, this.action);
  final String label;
  final Color color;
  final String? action;
}

_Verdict _verdict(String code, bool fr) => switch (code) {
  'drivers_short' => _Verdict(
    fr ? 'Il manque des chauffeurs' : 'Drivers are short',
    AppColors.error,
    fr
        ? 'À faire : recruter des chauffeurs dans ce secteur.'
        : 'To do: recruit drivers in this area.',
  ),
  'customers_short' => _Verdict(
    fr ? 'Il manque des clients' : 'Customers are short',
    AppColors.info,
    fr
        ? 'À faire : de la pub pour attirer des clients.'
        : 'To do: advertise to bring in customers.',
  ),
  'balanced' => _Verdict(
    fr ? 'En équilibre' : 'Balanced',
    AppColors.success,
    fr ? 'On ne touche à rien.' : 'Leave it as is.',
  ),
  _ => _Verdict(
    fr ? 'Pas assez de données' : 'Not enough data',
    AppColors.textSecondary,
    null,
  ),
};

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}
