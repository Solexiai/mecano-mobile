// ---------------------------------------------------------------------------
// PricingGridDraft — brouillon modifiable de la grille de tarifs admin
// (Centre financier > Tarifs).
//
// Construit à partir d'une `pricing_versions/{v}` publiée, modifié dans
// l'écran, puis envoyé tel quel à `previewPricingConfiguration` (simulateur)
// et à `updatePricingConfiguration` (publication). Le serveur revalide
// TOUT : ce modèle ne fait que porter les valeurs.
//
// Ce qui n'est PAS modifiable ici, et donc recopié tel quel :
//   - les taxes et les pourboires (le serveur ne les accepte jamais) ;
//   - les frais « objet lourd » (retiré) et « objet encombrant » (doit rester
//     à 0 $ tant que le parcours de réservation ne l'applique pas) ;
//   - l'attente et les majorations, que le parcours « prix avant chauffeur »
//     n'applique pas ;
//   - les tarifs des véhicules hors pilote.
// ---------------------------------------------------------------------------

/// Véhicules tarifés ensemble par le parcours « prix avant chauffeur ».
const List<String> kPilotPricingCategories = [
  'pickup_truck',
  'cargo_van',
  'cube_truck',
];

/// Frais d'annulation par défaut (décision du 23 octobre 2026).
const int kDefaultMissionFeeTotalMinor = 3000;
const int kDefaultMissionFeeDriverMinor = 2500;

String normalizeVehicleCategory(String value) {
  return value
      .trim()
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m.group(1)}_${m.group(2)}',
      )
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
}

double _num(Object? v, [double fallback = 0]) =>
    v is num && v.isFinite ? v.toDouble() : fallback;

int _int(Object? v, int fallback) => v is num ? v.round() : fallback;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class PricingGridDraft {
  PricingGridDraft({
    required this.basedOnVersion,
    required this.pilotCategoryNames,
    required this.otherVehicleRules,
    required this.baseFare,
    required this.ratePerKm,
    required this.ratePerMinute,
    required this.minimumCharge,
    required this.loadingFee,
    required this.unloadingFee,
    required this.stairsFee,
    required this.noElevatorFee,
    required this.secondHandlerFee,
    required this.specialEquipmentFee,
    required this.heavyItemFee,
    required this.bulkyItemFee,
    required this.feePerStop,
    required this.waitingFee,
    required this.surcharges,
    required this.serviceFeeRate,
    required this.minimumServiceFee,
    required this.commissionRate,
    required this.minimumCommission,
    required this.maximumEffectiveCommissionRate,
    required this.quoteValidityMinutes,
    required this.feeTotalMinor,
    required this.feeDriverMinor,
    required this.taxRate,
  });

  /// Version active à l'ouverture de la grille (contrôle de concurrence).
  final String? basedOnVersion;

  /// Noms exacts des catégories pilote telles que stockées (ex.
  /// `pickup_truck` ou l'ancien `pickupTruck`).
  final List<String> pilotCategoryNames;

  /// Règles des véhicules hors pilote, recopiées sans modification.
  final List<Map<String, dynamic>> otherVehicleRules;

  // Prix de la course (véhicules du pilote).
  double baseFare;
  double ratePerKm;
  double ratePerMinute;
  double minimumCharge;

  // Manutention.
  double loadingFee;
  double unloadingFee;
  double stairsFee;
  double noElevatorFee;
  double secondHandlerFee;
  double specialEquipmentFee;
  final double heavyItemFee;
  final double bulkyItemFee;
  double feePerStop;

  // Non utilisés par le parcours actuel : recopiés.
  final Map<String, dynamic> waitingFee;
  final List<Map<String, dynamic>> surcharges;

  // Part Movi-K (taux entre 0 et 1).
  double serviceFeeRate;
  double minimumServiceFee;
  double commissionRate;
  double minimumCommission;
  double maximumEffectiveCommissionRate;

  int quoteValidityMinutes;

  // Frais d'annulation tardive / déplacement inutile (cents).
  int feeTotalMinor;
  int feeDriverMinor;
  int get feePlatformMinor => feeTotalMinor - feeDriverMinor;

  /// Affichage seulement : jamais envoyé au serveur.
  final double? taxRate;

  /// Construit le brouillon depuis un document `pricing_versions/{v}`.
  factory PricingGridDraft.fromVersion(
    Map<String, dynamic> version, {
    String? versionId,
  }) {
    final rules = (version['vehicle_rules'] is List)
        ? (version['vehicle_rules'] as List).map(_map).toList()
        : <Map<String, dynamic>>[];
    final pilot = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];
    for (final rule in rules) {
      final category = (rule['category'] as String?) ?? '';
      if (kPilotPricingCategories.contains(normalizeVehicleCategory(category))) {
        pilot.add(rule);
      } else {
        others.add(rule);
      }
    }
    final reference = pilot.isNotEmpty
        ? pilot.first
        : (rules.isNotEmpty ? rules.first : <String, dynamic>{});
    final pilotNames = <String>[
      for (final r in pilot) (r['category'] as String?) ?? '',
    ];
    for (final category in kPilotPricingCategories) {
      final present = pilotNames.any(
        (n) => normalizeVehicleCategory(n) == category,
      );
      if (!present) pilotNames.add(category);
    }

    final handling = _map(version['handling_fees']);
    final service = _map(version['customer_service_fee']);
    final commission = _map(version['commission']);
    final fee = _map(version['mission_fee_policy']);
    final feeTotal = _int(fee['total_minor'], kDefaultMissionFeeTotalMinor);
    final feeDriver = _int(fee['driver_minor'], kDefaultMissionFeeDriverMinor);

    return PricingGridDraft(
      basedOnVersion: versionId ?? version['pricing_version'] as String?,
      pilotCategoryNames: pilotNames,
      otherVehicleRules: others,
      baseFare: _num(reference['base_fare']),
      ratePerKm: _num(reference['rate_per_km']),
      ratePerMinute: _num(reference['rate_per_minute']),
      minimumCharge: _num(reference['minimum_charge']),
      loadingFee: _num(handling['loading_fee']),
      unloadingFee: _num(handling['unloading_fee']),
      stairsFee: _num(handling['stairs_fee']),
      noElevatorFee: _num(handling['no_elevator_fee']),
      secondHandlerFee: _num(handling['second_handler_fee']),
      specialEquipmentFee: _num(handling['special_equipment_fee']),
      heavyItemFee: _num(handling['heavy_item_fee']),
      bulkyItemFee: _num(handling['bulky_item_fee']),
      feePerStop: _num(_map(version['additional_stop_fee'])['fee_per_stop']),
      waitingFee: _map(version['waiting_fee']),
      surcharges: (version['surcharges'] is List)
          ? (version['surcharges'] as List).map(_map).toList()
          : <Map<String, dynamic>>[],
      serviceFeeRate: _num(service['service_fee_rate']),
      minimumServiceFee: _num(service['minimum_service_fee']),
      commissionRate: _num(commission['standard_commission_rate']),
      minimumCommission: _num(commission['minimum_platform_commission']),
      maximumEffectiveCommissionRate: _num(
        commission['maximum_effective_commission_rate'],
        1,
      ),
      quoteValidityMinutes: _int(
        _map(version['quote_config'])['quote_validity_minutes'],
        15,
      ),
      feeTotalMinor: feeTotal,
      feeDriverMinor: feeDriver,
      taxRate: version['tax_rate'] is num
          ? (version['tax_rate'] as num).toDouble()
          : null,
    );
  }

  /// Copie pour comparer le brouillon à son point de départ.
  PricingGridDraft copy() => PricingGridDraft.fromVersion(
    {...toServerConfig(), 'tax_rate': taxRate},
    versionId: basedOnVersion,
  );

  /// Corps `config` attendu par les fonctions serveur.
  Map<String, dynamic> toServerConfig() {
    Map<String, dynamic> pilotRule(String category) => {
      'category': category,
      'base_fare': baseFare,
      'rate_per_km': ratePerKm,
      'rate_per_minute': ratePerMinute,
      'minimum_charge': minimumCharge,
    };
    return {
      'vehicle_rules': [
        for (final name in pilotCategoryNames) pilotRule(name),
        for (final rule in otherVehicleRules) Map<String, dynamic>.from(rule),
      ],
      'handling_fees': {
        'loading_fee': loadingFee,
        'unloading_fee': unloadingFee,
        'heavy_item_fee': heavyItemFee,
        'bulky_item_fee': bulkyItemFee,
        'stairs_fee': stairsFee,
        'no_elevator_fee': noElevatorFee,
        'second_handler_fee': secondHandlerFee,
        'special_equipment_fee': specialEquipmentFee,
      },
      'waiting_fee': Map<String, dynamic>.from(waitingFee),
      'additional_stop_fee': {'fee_per_stop': feePerStop},
      'surcharges': [
        for (final s in surcharges) Map<String, dynamic>.from(s),
      ],
      'customer_service_fee': {
        'service_fee_rate': serviceFeeRate,
        'minimum_service_fee': minimumServiceFee,
      },
      'commission': {
        'standard_commission_rate': commissionRate,
        'minimum_platform_commission': minimumCommission,
        'maximum_effective_commission_rate': maximumEffectiveCommissionRate,
      },
      'quote_config': {'quote_validity_minutes': quoteValidityMinutes},
      'mission_fee_policy': {
        'total_minor': feeTotalMinor,
        'driver_minor': feeDriverMinor,
        'platform_minor': feePlatformMinor,
      },
    };
  }

  /// Empreinte stable du brouillon : sert à savoir si la simulation affichée
  /// correspond encore aux valeurs saisies.
  String get fingerprint => _stable(toServerConfig());

  /// Les frais d'annulation diffèrent de [other].
  bool feeDiffersFrom(PricingGridDraft other) =>
      feeTotalMinor != other.feeTotalMinor ||
      feeDriverMinor != other.feeDriverMinor;
}

String _stable(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '$k:${_stable(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_stable).join(',')}]';
  return '$value';
}
