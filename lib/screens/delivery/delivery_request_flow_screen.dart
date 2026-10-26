import '../../services/booking/item_types.dart';
import '../../widgets/booking_access_section.dart';
import '../../widgets/booking_simple_steps.dart';
import '../../services/booking/booking_contract.dart';
import '../../widgets/booking_terms_section.dart';
import '../../finance/presentation/money_format.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../../services/delivery_request_draft.dart';

import 'package:flutter/material.dart';
import '../../services/booking/booking_photo_analysis.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../l10n/app_strings.dart';
import '../../services/demo_data_service.dart';
import '../../router/delivery_request_intent.dart';
import '../../services/booking/booking_api.dart';
import '../../services/booking/booking_photos.dart';
import '../../widgets/booking_load_summary.dart';
import '../../widgets/photo_booking_item.dart';
import '../../services/booking/booking_draft.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/app_shell.dart';

/// Four-step booking. Amounts/recommendations are exclusively server responses.
/// No mission is created until the user explicitly confirms the current quote.
class DeliveryRequestFlowScreen extends StatefulWidget {
  const DeliveryRequestFlowScreen({
    super.key,
    required this.locale,
    this.initialCategory,
    this.api,
    this.storage,
    this.photoIntakeEnabled = const bool.fromEnvironment('ENABLE_PHOTO_INTAKE'),
    this.photoUploader,
    this.photoLoader,
  });
  final String locale;
  final String? initialCategory;
  final BookingApi? api;
  final BookingDraftStorage? storage;
  final bool photoIntakeEnabled;
  final BookingPhotoUploader? photoUploader;
  final BookingPhotoLoader? photoLoader;
  @override
  State<DeliveryRequestFlowScreen> createState() =>
      _DeliveryRequestFlowScreenState();
}

class _DeliveryRequestFlowScreenState extends State<DeliveryRequestFlowScreen>
    with WidgetsBindingObserver {
  late BookingDraft _draft;
  late BookingDraftStorage _storage;
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _contactsForm = GlobalKey<FormState>();
  Timer? _debounce;
  Timer? _clock;
  Future<void> _saveQueue = Future.value();
  String? _uid;
  bool _identityKnown = false,
      _loaded = false,
      _busy = false,
      _cardReady = false,
      _configurationChecked = false,
      _internalTestAllowed = false;
  int _epoch = 0;
  final Map<String, BookingPhotoSuggestion> _photoSuggestions = {};
  final Map<String, String> _photoErrors = {};
  String? _message, _saveError;
  Map<String, dynamic>? _policy, _review;
  bool _configurationError = false,
      _bookingEnabled = false,
      _paymentEnabled = false;
  bool get _canBook =>
      _configurationChecked &&
      !_configurationError &&
      _policy != null &&
      _bookingEnabled;
  bool get _assignmentPending => _draft.quote?['assignmentPending'] == true;
  // Since 2026-10-22 a price-first quote (assignmentPending) is a real
  // booking: drivers judge the fit, the card is only authorized when one
  // accepts. It follows the same terms/card/confirmation steps.
  bool get _canPay =>
      _canBook &&
      _paymentEnabled &&
      _policy!['setup_enabled'] == true;
  String get _configurationNotice => _configurationError
      ? tr(
          'Impossible de vérifier la disponibilité du service. Vous pouvez continuer votre brouillon, sans réservation ni paiement.',
          'Service availability could not be checked. You can continue your draft without booking or payment.',
          'No se pudo verificar la disponibilidad. Puedes continuar tu borrador sin reserva ni pago.',
        )
      : !_canBook
      ? _reservationUnavailable
      : tr(
          'Le paiement est temporairement indisponible. Vous pouvez préparer votre demande sans la confirmer.',
          'Payment is temporarily unavailable. You can prepare your request without confirming it.',
          'El pago no está disponible temporalmente. Puedes preparar tu solicitud sin confirmarla.',
        );
  bool get _photoMode => _draft.data['intake_mode'] == 'photo_assisted';
  BookingApi get _api => widget.api ?? FirebaseBookingApi(_uid);
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  void initState() {
    super.initState();
    _draft = BookingDraft(category: widget.initialCategory);
    _storage = widget.storage ?? BookingDraftStorage();
    WidgetsBinding.instance.addObserver(this);
    _pickup.addListener(() => _invalidateAddress('pickup', _pickup));
    _dropoff.addListener(() => _invalidateAddress('dropoff', _dropoff));
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<FirebaseAuthProvider>().effectiveUid;
    if (!_identityKnown || uid != _uid) {
      _identityKnown = true;
      _uid = uid;
      _epoch++;
      _photoSuggestions.clear();
      _photoErrors.clear();
      _loaded = false;
      _debounce?.cancel();
      _restore(_epoch);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _loaded &&
        _draft.quote != null &&
        _uid != null) {
      _loadConfiguration(_epoch).then((_) => _refreshCard());
    }
  }

  String _addressText(String key) {
    final resolved = (_draft.data[key] as Map?)?['formatted_address'];
    final typed = _draft.data['${key}_text'];
    return resolved is String ? resolved : (typed is String ? typed : '');
  }

  void _invalidateAddress(String key, TextEditingController controller) {
    if (!_loaded || _addressText(key) == controller.text) return;
    // Keep unfinished input separately; it never supplies coordinates or stops.
    _draft.data['${key}_text'] = controller.text;
    final address = _draft.data[key] as Map?;
    if (address != null && address['formatted_address'] != controller.text) {
      _draft.data[key] = null;
    }
    _changed();
  }

  Future<void> _restore(int epoch) async {
    final api = _api;
    BookingDraft? restored;
    try {
      restored = await _storage.load(_uid);
    } catch (_) {
      /* Storage may be disabled by the browser. */
    }
    if (restored == null) {
      try {
        final legacy = await DeliveryRequestDraft.load(uid: _uid);
        if (legacy != null) {
          restored = BookingDraft(category: legacy.category);
          restored.items.add({
            'id': const Uuid().v4(),
            'category': legacy.category,
            'label': legacy.description.isEmpty ? 'Objet' : legacy.description,
            'quantity': legacy.quantity,
            'length': null,
            'width': null,
            'height': null,
            'weight': null,
            'dimension_unit': 'cm',
            'weight_unit': 'kg',
            'approximate': true,
            'upright': true,
            'photos': <String>[],
          });
          for (final entry in [
            ('pickup', legacy.pickup),
            ('dropoff', legacy.dropoff),
          ]) {
            final a = entry.$2;
            if (a != null) {
              restored.data[entry.$1] = {
                'line1': a.line1,
                'city': a.city,
                'postal_code': a.postalCode,
                'lat': a.lat,
                'lng': a.lng,
                'formatted_address': a.formattedAddress,
                'place_id': a.placeId,
              };
            }
          }
          (restored.data['contacts'] as Map)['instructions'] = [
            legacy.contactInstructions,
            legacy.accessDetails,
          ].where((v) => v.isNotEmpty).join(' / ');
          restored.data['handlers'] = legacy.needsSecondHandler ? 2 : 1;
          (restored.data['pickup_access'] as Map)['stairs'] =
              legacy.needsStairs;
          (restored.data['dropoff_access'] as Map)['stairs'] =
              legacy.needsStairs;
          await _storage.save(restored, _uid);
          await DeliveryRequestDraft.clear();
        }
      } catch (_) {
        /* An invalid legacy draft cannot restore a price. */
      }
    }
    if (_uid != null) {
      try {
        final saved = await api.call('getBookingDraft');
        if (saved['draft'] is Map) {
          final remote = BookingDraft.fromJson(
            Map<String, dynamic>.from(saved['draft'] as Map),
          );
          if (!remote.expired &&
              (restored == null ||
                  (remote.id == restored.id &&
                      remote.revision > restored.revision))) {
            restored = remote;
          }
        }
      } catch (_) {
        /* The tab copy remains usable offline. */
      }
    }
    if (!mounted || epoch != _epoch) return;
    _draft = restored ?? BookingDraft(category: widget.initialCategory);
    if (restored == null &&
        _catalog.any((entry) => entry.$1 == widget.initialCategory)) {
      _addItem(widget.initialCategory!, notify: false);
    }
    _pickup.text = _addressText('pickup');
    _dropoff.text = _addressText('dropoff');
    _cardReady = false;
    _busy = false;
    _message = null;
    _review = null;
    _policy = null;
    _configurationChecked = false;
    _internalTestAllowed = false;
    _configurationError = false;
    _bookingEnabled = false;
    _paymentEnabled = false;
    setState(() {
      _loaded = true;
    });
    await _loadConfiguration(epoch);
    if (_uid != null && mounted && epoch == _epoch) {
      try {
        final profile = await api.profile();
        if (!mounted || epoch != _epoch) return;
        final values = _draft.contacts;
        for (final entry in Map<String, dynamic>.from(
          profile?['contacts'] as Map? ?? {},
        ).entries) {
          if ((values[entry.key] as String? ?? '').isEmpty) {
            values[entry.key] = entry.value;
          }
        }
        final auth = context.read<FirebaseAuthProvider>();
        if ((values['pickup_name'] as String? ?? '').isEmpty) {
          values['pickup_name'] = auth.effectiveDisplayName ?? '';
        }
        setState(() {
          _draft.data['contacts'] = values;
        });
      } catch (_) {
        /* Manual entry is always available. */
      }
      if (_draft.quote != null) {
        try {
          final official = await api.call('getBookingQuote', {
            'quoteId': _draft.quote!['quoteId'],
          });
          if (!mounted || epoch != _epoch) return;
          setState(() {
            _draft.data['quote'] = official;
            if (official['missionId'] != null) {
              _draft.data['missionId'] = official['missionId'];
            }
          });
          await _refreshCard();
        } catch (_) {
          if (mounted && epoch == _epoch) {
            setState(() {
              _draft.data['quote'] = null;
              // Keep the current preparation step when quote revalidation fails.
            });
          }
        }
      }
    }
  }

  Future<void> _loadConfiguration(int epoch) async {
    Map<String, dynamic>? policy;
    bool error = false, booking = false, payment = false, internalTest = false;
    try {
      final config = await _api.call('getBookingConfiguration');
      internalTest = config['internal_test_request'] == true;
      final availability = config['availability'];
      if (availability is Map) {
        booking = availability['booking_enabled'] == true;
        payment = availability['payment_enabled'] == true;
        error = availability['technical_error'] == true;
      }
      if (config['policy'] is Map) {
        final value = Map<String, dynamic>.from(config['policy'] as Map);
        if (BookingContract.from(value) != null) policy = value;
      }
    } catch (_) {
      error = true;
    }
    if (!mounted || epoch != _epoch) return;
    setState(() {
      if (_draft.data['accepted'] == true &&
          (_draft.data['accepted_contract_hash'] != policy?['contract_hash'] ||
              _draft.data['accepted_quote_id'] != _draft.quote?['quoteId'] ||
              _draft.data['accepted_locale'] != widget.locale)) {
        _draft.data['accepted'] = false;
        _message = tr(
          'Consultez les conditions actuelles et acceptez-les avant de confirmer.',
          'Review and accept the current terms before confirming.',
          'Consulta y acepta las condiciones actuales antes de confirmar.',
        );
      }
      _policy = policy;
      _configurationChecked = true;
      _internalTestAllowed = internalTest;
      _configurationError = error;
      _bookingEnabled = booking;
      _paymentEnabled = payment;
      if (!_canPay) _cardReady = false;
    });
  }

  String get _reservationUnavailable => tr(
    'La réservation et le paiement ne sont pas encore ouverts. Vous pouvez continuer à préparer votre demande et obtenir votre prix : elle reste enregistrée.',
    'Booking and payment are not open yet. You can keep preparing your request and get your price; it stays saved.',
    'La reserva y el pago aún no están abiertos. Puedes seguir preparando tu solicitud y obtener tu precio; queda guardada.',
  );

  void _changed({bool quote = true}) {
    setState(() {
      final hadQuote = _draft.quote != null;
      _draft.changed(affectsQuote: quote);
      if (quote) {
        _review = null;
        if (hadQuote) {
          _message = tr(
            'La livraison a changé : un nouveau prix doit être calculé.',
            'Your delivery changed. A new price must be calculated.',
            'La entrega cambió. Se debe calcular un nuevo precio.',
          );
        }
      }
    });
    // Session storage is synchronous underneath; write every change so a
    // refresh during the debounce cannot lose the latest field.
    _persistLocal();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _persistLocal() async {
    try {
      await _storage.save(_draft, _uid);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = tr(
            'La sauvegarde dans cet onglet est indisponible.',
            'Saving in this tab is unavailable.',
            'No se puede guardar en esta pestaña.',
          );
        });
      }
    }
  }

  Future<void> _save() {
    final snapshot = BookingDraft.fromJson(_draft.data);
    final uid = _uid;
    final api = _api;
    final epoch = _epoch;
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      if (epoch != _epoch) return;
      await _persistLocal();
      if (uid == null) return;
      try {
        await api.call('saveBookingDraft', {
          'ownerUid': uid,
          'draftId': snapshot.id,
          'revision': snapshot.revision,
          'draft': snapshot.data,
        });
        if (mounted && epoch == _epoch) {
          setState(() {
            _saveError = null;
          });
        }
      } catch (_) {
        if (mounted && epoch == _epoch) {
          setState(() {
            _saveError = tr(
              'Synchronisation en attente. Gardez cet onglet ouvert et réessayez.',
              'Sync pending. Keep this tab open and retry.',
              'Sincronización pendiente. Mantén esta pestaña abierta e inténtalo de nuevo.',
            );
          });
        }
      }
    });
    return _saveQueue;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on BookingPhotoFormatException catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _message = switch (e.reason) {
            BookingPhotoFailure.unsupportedFormat => tr(
              'Ce format de photo n’est pas pris en charge. Choisissez une image JPG, PNG ou WebP. Pour une photo HEIC, utilisez une copie JPG.',
              'This photo format is not supported. Choose a JPG, PNG or WebP image. For an HEIC photo, use a JPG copy.',
              'Este formato de foto no es compatible. Elige una imagen JPG, PNG o WebP. Para una foto HEIC, usa una copia JPG.',
            ),
            BookingPhotoFailure.inputTooLarge => tr(
              'Cette photo dépasse 20 Mo. Choisissez une version plus légère.',
              'This photo exceeds 20 MB. Choose a smaller version.',
              'Esta foto supera los 20 MB. Elige una versión más ligera.',
            ),
            BookingPhotoFailure.processingFailed => tr(
              'Le navigateur n’a pas pu préparer cette photo. Réessayez avec une version de résolution plus basse ou une autre photo. Votre demande est conservée.',
              'The browser could not prepare this photo. Try a lower-resolution version or another photo. Your request has been kept.',
              'El navegador no pudo preparar esta foto. Prueba una versión de menor resolución u otra foto. Tu solicitud se conserva.',
            ),
            BookingPhotoFailure.outputTooLarge => tr(
              'Cette photo reste trop volumineuse après préparation. Choisissez une version plus légère.',
              'This photo is still too large after preparation. Choose a smaller version.',
              'Esta foto sigue siendo demasiado grande después de prepararla. Elige una versión más ligera.',
            ),
          };
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _message = e.code == 'invalid-argument'
              ? tr(
                  'Vérifiez les dimensions, les poids, les quantités et les adresses.',
                  'Check dimensions, weights, quantities and addresses.',
                  'Verifica las dimensiones, pesos, cantidades y direcciones.',
                )
              : tr(
                  'Cette opération n’a pas abouti. Vos données sont conservées. Réessayez.',
                  'This action did not complete. Your details are saved. Please retry.',
                  'La operación no se completó. Tus datos se conservaron. Inténtalo de nuevo.',
                );
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _message = tr(
            'Une erreur technique empêche cette opération. Votre brouillon est conservé; vous pouvez continuer à le préparer.',
            'A technical error prevented this action. Your draft is saved; you can keep preparing it.',
            'Un error técnico impidió esta operación. Tu borrador se conserva y puedes seguir preparándolo.',
          );
        });
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _login() async {
    await _save();
    await _storage.handoff();
    if (mounted) {
      context.go(
        DeliveryRequestIntent.loginPath(
          widget.locale,
          category: _draft.data['category'] as String?,
        ),
      );
    }
  }

  bool get _addressesValid => ['pickup', 'dropoff'].every((key) {
    final a = _draft.data[key] as Map?;
    return a != null &&
        (a['city'] as String? ?? '').isNotEmpty &&
        (a['postal_code'] as String? ?? '').isNotEmpty;
  });
  bool get _photoConfirmationNeeded =>
      _photoMode &&
      _draft.items.any((item) => item['identification_confirmed'] != true);

  Set<String> get _reviewReasons =>
      (_review?['reasons'] as List? ?? []).whereType<String>().toSet();

  static const _serviceReviewReasons = {
    'photo_policy_unconfigured',
    'photo_category_unconfigured',
    'capacity_unconfigured',
    'service_area_unconfigured',
  };

  Widget _reviewFeedback() {
    final reasons = _reviewReasons;
    final serviceUnavailable = reasons.any(_serviceReviewReasons.contains);
    final actionable = reasons
        .where((reason) => !_serviceReviewReasons.contains(reason))
        .map(_reason)
        .toSet();
    final messages = <String>[
      if (serviceUnavailable)
        tr(
          'Le calcul du prix en ligne est momentanément indisponible. Votre brouillon est conservé ; aucun prix ni réservation n’est confirmé.',
          'Online pricing is temporarily unavailable. Your draft is saved; no price or booking is confirmed.',
          'El cálculo del precio en línea no está disponible por el momento. Tu borrador está guardado; no se confirma precio ni reserva.',
        ),
      ...actionable,
      if (!serviceUnavailable && actionable.isEmpty)
        tr(
          'Le prix ne peut pas encore être calculé. Votre brouillon est conservé.',
          'The price cannot be calculated yet. Your draft is saved.',
          'El precio aún no se puede calcular. Tu borrador está guardado.',
        ),
    ];
    return _note(messages.join('\n\n'), warning: true);
  }

  Future<void> _quote() async {
    // A server quote does not require payment or approved booking terms.
    // Assignment review is deferred; the server still validates input and owns every price.
    if (_uid == null) {
      await _login();
      return;
    }
    if (_photoConfirmationNeeded) {
      setState(() {
        _review = {
          'status': 'review_required',
          'reasons': ['object_confirmation_required'],
        };
      });
      return;
    }
    if (![
      'pickup_access',
      'dropoff_access',
    ].every((key) => accessAnswersComplete(_draft.data[key] as Map))) {
      setState(() {
        _message = tr(
          'Répondez aux questions sur les escaliers et l’aide pour obtenir votre prix. Votre brouillon est conservé.',
          'Answer the stairs and help questions to get your price. Your draft is saved.',
          'Responde las preguntas sobre escaleras y ayuda para obtener tu precio. Tu borrador está guardado.',
        );
        _draft.step = 0;
        final stairsMissing = ['pickup_access', 'dropoff_access'].any(
          (key) => !((_draft.data[key] as Map)['confirmed_fields'] as List? ??
                  const [])
              .contains('stairs'),
        );
        _draft.part = stairsMissing ? 1 : 2;
      });
      await _save();
      return;
    }
    final revision = _draft.revision, epoch = _epoch;
    // Pricing and driver/capacity assignment are independent operations.
    // Only the server calculates amounts, validates input and freezes the quote.
    late Map<String, dynamic> quote;
    try {
      quote = await _api.call('calculateDeliveryQuote', {
        'quotePurpose': 'price_before_assignment',
        'booking': _draft.load,
        'stops': _draft.stops,
      });
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['quote_reason'] is String) {
        if (mounted && epoch == _epoch && revision == _draft.revision) {
          setState(() {
            _review = {
              'status': 'review_required',
              'reasons': [details['quote_reason']],
            };
          });
        }
        return;
      }
      rethrow;
    }
    if (!mounted || epoch != _epoch || revision != _draft.revision) return;
    // A recalculated price with the same total keeps the terms acceptance:
    // the customer already accepted these terms at this price (2026-10-23).
    // A different total always requires a new acceptance.
    final previous = _draft.quote;
    final keepAcceptance =
        _acceptanceCurrent &&
        previous != null &&
        previous['customerTotal'] == quote['customerTotal'];
    setState(() {
      _review = null;
      _draft.data['quote'] = quote;
      if (keepAcceptance) {
        _draft.data['accepted_quote_id'] = quote['quoteId'];
      } else {
        _draft.data['accepted'] = false;
      }
    });
    await _save();
    await _refreshCard();
  }

  String _moneyText(dynamic n) => formatMajorAmount(
    n is num ? n : null,
    locale: widget.locale,
    currencySymbol: tr(r'$ CA', r'CA$', r'CA$'),
  );

  /// An expired price is recalculated automatically (2026-10-23). Returns
  /// true when the price is valid and unchanged; when the total changed, the
  /// customer sees the new price and must accept again before continuing.
  Future<bool> _ensureFreshQuote() async {
    if (_draft.quoteValid) return true;
    final before = _draft.quote?['customerTotal'];
    await _quote();
    if (!mounted) return false;
    final after = _draft.quote;
    if (after == null || !_draft.quoteValid) return false;
    if (after['customerTotal'] != before) {
      setState(() {
        _message = tr(
          'Le prix a été recalculé : ${_moneyText(after['customerTotal'])} au lieu de ${_moneyText(before)}. Vérifiez le nouveau prix et acceptez de nouveau les conditions.',
          'The price was recalculated: ${_moneyText(after['customerTotal'])} instead of ${_moneyText(before)}. Check the new price and accept the terms again.',
          'El precio se recalculó: ${_moneyText(after['customerTotal'])} en lugar de ${_moneyText(before)}. Revisa el nuevo precio y acepta de nuevo las condiciones.',
        );
      });
      return false;
    }
    return true;
  }

  Future<void> _refreshCard() async {
    if (!_canPay ||
        _draft.quote == null ||
        _uid == null ||
        _draft.data['missionId'] != null) {
      return;
    }
    final epoch = _epoch;
    try {
      final result = await _api.call('getBookingCardStatus', {
        'quoteId': _draft.quote!['quoteId'],
      });
      if (mounted && epoch == _epoch) {
        setState(() {
          _cardReady = result['ready'] == true;
        });
      }
    } catch (_) {
      /* A retry button remains available; never claim success. */
    }
  }

  Future<void> _setupCard() async {
    await _loadConfiguration(_epoch);
    if (!mounted) return;
    if (!await _ensureFreshQuote() || !mounted) return;
    if (!_canPay || !_readyToConfirm(context.read<FirebaseAuthProvider>())) {
      return;
    }
    final epoch = _epoch;
    await _save();
    if (_saveError != null) return;
    final result = await _api.call('startBookingCardSetup', {
      'quoteId': _draft.quote!['quoteId'],
      'locale': widget.locale,
      'consent': _currentConsent,
    });
    if (!mounted || epoch != _epoch) return;
    if (result['ready'] == true) {
      setState(() {
        _cardReady = true;
      });
      return;
    }
    final uri = Uri.parse(result['url'] as String);
    if (uri.scheme != 'https' || uri.host != 'checkout.stripe.com') {
      throw StateError('Invalid checkout origin');
    }
    if (!await launchUrl(
      uri,
      webOnlyWindowName: '_self',
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('Checkout unavailable');
    }
  }

  Future<void> _submitInternalTest() async {
    await _loadConfiguration(_epoch);
    if (!mounted ||
        !_internalTestAllowed ||
        !_assignmentPending ||
        !_draft.quoteValid) {
      return;
    }
    final epoch = _epoch;
    await _save();
    if (_saveError != null) return;
    final q = _draft.quote!;
    final result = await _api.call('createDeliveryRequest', {
      'quoteId': q['quoteId'],
      'booking': _draft.load,
      'contacts': _draft.contacts,
      'stops': _draft.stops,
      'requiredVehicleCategory': q['vehicleCategory'],
      'description': '',
      'itemCategoryKey': '',
      'customerDisplayName': '',
    });
    if (!mounted || epoch != _epoch) return;
    if (result['internalTest'] != true || result['missionId'] is! String) {
      throw StateError('Internal-test response required');
    }
    final oldId = _draft.id;
    setState(() {
      _draft = BookingDraft()..data['missionId'] = result['missionId'];
    });
    await _persistLocal();
    await _api.call('clearBookingDraft', {'draftId': oldId});
  }

  Future<void> _confirm() async {
    await _loadConfiguration(_epoch);
    if (!mounted) return;
    if (!await _ensureFreshQuote() || !mounted) return;
    if (!_canPay ||
        !_cardReady ||
        !_readyToConfirm(context.read<FirebaseAuthProvider>())) {
      return;
    }
    final epoch = _epoch;
    await _save();
    final q = _draft.quote!;
    final result = await _api.call('createDeliveryRequest', {
      'quoteId': q['quoteId'],
      'booking': _draft.load,
      'contacts': _draft.contacts,
      'consent': _currentConsent,
      'stops': _draft.stops,
      'requiredVehicleCategory': q['vehicleCategory'],
      'description': '',
      'itemCategoryKey': '',
      'customerDisplayName': '',
    });
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _draft.data['missionId'] = result['missionId'];
    });
    // Keep a small receipt locally for refresh/retry, clear personal data.
    final missionId = result['missionId'];
    final oldId = _draft.id;
    _draft = BookingDraft()..data['missionId'] = missionId;
    await _persistLocal();
    await _api.call('clearBookingDraft', {'draftId': oldId});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _clock?.cancel();
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  Future<void> _startPhotoItem() async {
    if (_uid == null) {
      await _login();
      return;
    }
    final epoch = _epoch, draftId = _draft.id;
    final existing = _photoMode
        ? _draft.items
              .where((item) => isEmptyPhotoBookingItem(item as Map))
              .firstOrNull
        : null;
    if (existing == null && _draft.items.length >= 20) return;
    _draft.data['intake_mode'] = 'photo_assisted';
    _draft.data.remove('requested_vehicle');
    for (final raw in _draft.items) {
      raw['identification_confirmed'] ??= false;
      raw['special_handling'] ??= false;
    }
    if (existing == null) _addItem('other');
    final item = (existing ?? _draft.items.last) as Map;
    try {
      await _addPhoto(item);
    } finally {
      // Cancel/error only removes the untouched placeholder created by this action.
      if (existing == null &&
          mounted &&
          epoch == _epoch &&
          _draft.id == draftId &&
          _draft.items.contains(item) &&
          isEmptyPhotoBookingItem(item)) {
        _draft.items.remove(item);
        _changed();
        await _save();
      }
    }
  }

  Widget _photoItemAction({bool another = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('photo-new-object'),
        icon: const Icon(Icons.add),
        label: Text(
          another
              ? tr(
                  'Ajouter un autre objet',
                  'Add another item',
                  'Añadir otro objeto',
                )
              : tr(
                  'Commencer par une photo',
                  'Start with a photo',
                  'Empezar con una foto',
                ),
        ),
        onPressed:
            _busy ||
                (_draft.items.length >= 20 &&
                    !_draft.items.any(
                      (item) => isEmptyPhotoBookingItem(item as Map),
                    ))
            ? null
            : () => _run(_startPhotoItem),
      ),
      Text(
        tr(
          'Chaque photo ajoutée est analysée automatiquement par OpenAI pour proposer la catégorie et la description. Vérifiez le résultat.',
          'Each added photo is automatically analyzed by OpenAI to suggest the category and description. Check the result.',
          'OpenAI analiza automáticamente cada foto añadida para sugerir la categoría y la descripción. Revisa el resultado.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Future<void> _addPhoto(Map item) async {
    if (_uid == null) {
      await _login();
      return;
    }
    final uid = _uid!, draftId = _draft.id, epoch = _epoch;
    final photos = item['photos'] as List? ?? <String>[];
    if (photos.length >= 3) return;
    // Safari requires the picker to remain tied to the user's gesture.
    // Select locally first; saving/ownership checks still precede the upload.
    final upload = widget.photoUploader ?? await selectBookingPhotoUpload();
    if (upload == null ||
        !mounted ||
        epoch != _epoch ||
        _uid != uid ||
        draftId != _draft.id ||
        !_draft.items.contains(item)) {
      return;
    }
    await _save();
    if (_saveError != null ||
        !mounted ||
        epoch != _epoch ||
        _uid != uid ||
        draftId != _draft.id ||
        !_draft.items.contains(item)) {
      return;
    }
    final path = await upload(
      uid: uid,
      draftId: draftId,
      itemId: item['id'] as String,
      // Removing an earlier photo must not overwrite a retained slot.
      slot: Iterable<int>.generate(3).firstWhere(
        (slot) => !photos.contains(
          'booking_photos/$uid/$draftId/${item['id']}/$slot.jpg',
        ),
      ),
    );
    if (path == null ||
        !mounted ||
        epoch != _epoch ||
        _uid != uid ||
        _draft.id != draftId ||
        !_draft.items.contains(item)) {
      return;
    }
    photos.add(path);
    item['photos'] = photos;
    item.remove('photo_size_hint');
    _photoSuggestions.remove(item['id']);
    _photoErrors.remove(item['id']);
    item['identification_confirmed'] = false;
    _changed();
    if (_photoMode) await _analyzePhoto(item);
  }

  Future<void> _analyzePhoto(Map item) async {
    if (_uid == null || !_photoMode) return;
    final photos = item['photos'] as List? ?? [];
    if (photos.isEmpty) return;
    final path = photos.last as String;
    final uid = _uid, epoch = _epoch, draftId = _draft.id;
    final itemId = item['id'] as String;
    final fingerprint = jsonEncode(item);
    final locale = widget.locale;
    bool stillCurrent() =>
        mounted &&
        _epoch == epoch &&
        _uid == uid &&
        _draft.id == draftId &&
        widget.locale == locale &&
        _draft.items.contains(item) &&
        jsonEncode(item) == fingerprint;
    setState(() {
      _photoSuggestions.remove(itemId);
      _photoErrors.remove(itemId);
    });
    await _save();
    if (!stillCurrent() || _saveError != null) return;
    try {
      final result = await _api.call('analyzeBookingPhoto', {
        'draftId': draftId,
        'itemId': itemId,
        'photoPath': path,
        'locale': locale,
        'consent': true,
      });
      if (!stillCurrent()) return;
      final suggestion = BookingPhotoSuggestion.fromResponse(result, path);
      suggestion.applyTo(item);
      _photoSuggestions[itemId] = suggestion;
      _changed();
      await _save();
    } catch (_) {
      if (!stillCurrent()) return;
      setState(() {
        _photoErrors[itemId] = tr(
          'Analyse indisponible. Vos informations sont conservées. Réessayez ou choisissez la catégorie vous-même.',
          'Analysis unavailable. Your details are saved. Retry or choose the category yourself.',
          'Análisis no disponible. Tus datos se conservaron. Reintenta o elige la categoría.',
        );
      });
    }
  }

  void _addItem(String category, {bool notify = true}) {
    final entry =
        _catalog.where((e) => e.$1 == category).firstOrNull ?? _catalog.last;
    _draft.items.add({
      'id': const Uuid().v4(),
      'category': category,
      'label': entry.$2,
      'quantity': 1,
      'length': null,
      'width': null,
      'height': null,
      'weight': null,
      'dimension_unit': 'cm',
      'weight_unit': 'kg',
      'approximate': false,
      'upright': true,
      'photos': <String>[],
      if (_photoMode) 'identification_confirmed': false,
      if (_photoMode) 'special_handling': false,
    });
    if (notify) _changed();
  }

  // Shared with the server and the admin screen (2026-10-26).
  List<(String, String, IconData)> get _catalog => [
    for (final type in itemTypes) (type.id, type.label(widget.locale), type.icon),
  ];
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _note(String text, {bool warning = false, Key? key}) => Container(
    key: key,
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? const Color(0xfffff1dd) : const Color(0xffeef5f4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
  Widget _button(String text, VoidCallback? tap, {IconData? icon}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: FilledButton.icon(
      onPressed: _busy ? null : tap,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(text),
    ),
  );
  void _step(int step, {int? part}) {
    final moved = step != _draft.step || (part != null && part != _draft.part);
    setState(() {
      _draft.step = step;
      if (part != null) _draft.part = part;
      _message = null;
    });
    _changed(quote: false);
    // A new screen starts at its question, not where the last one ended.
    if (moved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _stepHeaderKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(target, alignment: 0.1);
        }
      });
    }
  }

  final _stepHeaderKey = GlobalKey();

  /// Screens of step 0, one question each (2026-10-23).
  void _part(int part) => _step(0, part: part);

  /// Shown as "Étape N sur 7": 4 delivery questions, then price, details
  /// and confirmation.
  int get _screenNumber => _draft.step == 0 ? _draft.part + 1 : _draft.step + 4;
  static const _screenCount = 7;

  /// The screen's main action: a full-width button. When it is disabled, the
  /// reason is written right under it.
  Widget _next(String text, VoidCallback? tap, {String? why, Key? key}) =>
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: key,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _busy ? null : tap,
              child: Text(text),
            ),
            if (tap == null && why != null) ...[
              const SizedBox(height: 8),
              Text(
                why,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff9a4a0b),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
  String get _nextLabel => tr('Suivant', 'Next', 'Siguiente');

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    return AppShell(
      locale: widget.locale,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Organisez votre livraison',
                    'Plan your delivery',
                    'Organiza tu entrega',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!_loaded)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  )
                else if (_draft.data['missionId'] != null) ...[
                  _heading(
                    tr(
                      'Votre demande est enregistrée',
                      'Your request is saved',
                      'Tu solicitud está registrada',
                    ),
                  ),
                  _note(
                    tr(
                      'Recherche d’un chauffeur compatible. Le créneau reste demandé, pas encore confirmé.',
                      'Searching for a compatible driver. Your requested time is not confirmed yet.',
                      'Buscando un conductor compatible. El horario solicitado aún no está confirmado.',
                    ),
                  ),
                  Text(
                    '${tr('Référence', 'Reference', 'Referencia')} : ${_draft.data['missionId']}',
                  ),
                  _note(
                    tr(
                      'L’enregistrement de la carte n’est pas un paiement. L’autorisation intervient à l’acceptation du chauffeur ; la capture à la fin de la livraison. Consultez le suivi pour le statut réel.',
                      'Saving a card is not a payment. Authorization occurs when a driver accepts; capture occurs after delivery. See tracking for the actual status.',
                      'Guardar una tarjeta no es un pago. Se autoriza al aceptar el conductor y se cobra al finalizar la entrega. Consulta el estado en el seguimiento.',
                    ),
                  ),
                  _button(
                    tr(
                      'Suivre ma livraison',
                      'Track my delivery',
                      'Seguir mi entrega',
                    ),
                    () => context.go(
                      '/${widget.locale}/livraison/suivi/${_draft.data['missionId']}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '/${widget.locale}/livraison/conditions/${_draft.data['missionId']}',
                    ),
                    child: Text(
                      tr(
                        'Récapitulatif et conditions à conserver',
                        'Save booking summary and terms',
                        'Guardar resumen y condiciones',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/${widget.locale}/contact'),
                    child: Text(
                      tr('Obtenir de l’aide', 'Get support', 'Obtener ayuda'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draft = BookingDraft();
                      });
                      _persistLocal();
                    },
                    child: Text(
                      tr('Nouvelle livraison', 'New delivery', 'Nueva entrega'),
                    ),
                  ),
                ] else ...[
                  if (_draft.step >= 2 && _configurationChecked && !_canPay)
                    _note(_configurationNotice, warning: true),
                  const SizedBox(height: 16),
                  BookingStepHeader(
                    key: _stepHeaderKey,
                    current: _screenNumber,
                    total: _screenCount,
                    locale: widget.locale,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uid == null
                        ? tr(
                            'Brouillon conservé 24 h dans cet onglet. Fermer l’onglet efface le brouillon invité.',
                            'Draft kept in this tab for 24 hours. Closing the tab removes the guest draft.',
                            'Borrador guardado en esta pestaña por 24 h. Al cerrar la pestaña se borra el borrador de invitado.',
                          )
                        : tr(
                            'Brouillon enregistré · 24 h',
                            'Draft saved · 24 hours',
                            'Borrador guardado · 24 h',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_saveError != null) ...[
                    _note(_saveError!, warning: true),
                    TextButton(
                      onPressed: () => _save(),
                      child: Text(
                        tr(
                          'Réessayer la sauvegarde',
                          'Retry saving',
                          'Reintentar guardado',
                        ),
                      ),
                    ),
                  ],
                  if (_message != null)
                    Semantics(
                      liveRegion: true,
                      child: _note(_message!, warning: true),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                  AbsorbPointer(
                    absorbing: _busy,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_draft.step == 0 && _draft.part == 0)
                          ..._emailVerification(auth),
                        if (_draft.step == 0) ..._deliveryPart(),
                        if (_draft.step == 1) ..._price(),
                        if (_draft.step == 2) ..._details(auth),
                        if (_draft.step == 3) ..._confirmation(auth),
                      ],
                    ),
                  ),
                  if (_draft.step > 0 || _draft.part > 0)
                    TextButton.icon(
                      key: const ValueKey('booking-back'),
                      onPressed: _busy
                          ? null
                          : () => _draft.step == 0
                                ? _part(_draft.part - 1)
                                : _step(
                                    _draft.step - 1,
                                    part: _draft.step == 1 ? 3 : null,
                                  ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(tr('Retour', 'Back', 'Volver')),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _deliveryPart() => switch (_draft.part) {
    0 => _itemsPart(),
    1 => _wherePart(),
    2 => _helpPart(),
    _ => _whenPart(),
  };

  /// Screen 1: what is moved. A photo of each item when photo intake is on.
  List<Widget> _itemsPart() {
    final photo = widget.photoIntakeEnabled || _photoMode;
    return [
      BookingQuestion(
        photo
            ? tr(
                'Prenez une photo de chaque article',
                'Take a photo of each item',
                'Toma una foto de cada artículo',
              )
            : tr(
                'Qu’est-ce qu’on transporte ?',
                'What are we moving?',
                '¿Qué transportamos?',
              ),
        hint: photo
            ? tr(
                'On reconnaît l’article. Vous vérifiez, c’est tout. Pas de mesures à prendre pour un objet ordinaire.',
                'We recognize the item. You check it, that’s all. No measuring for an ordinary item.',
                'Reconocemos el artículo. Tú lo verificas, nada más. No hace falta medir un objeto común.',
              )
            : null,
      ),
      if (photo && (!_photoMode || _draft.items.isEmpty)) _photoItemAction(),
      if (DemoDataService.deliveryCategories.contains(_draft.data['category']))
        _note(
          '${tr('Catégorie sélectionnée', 'Selected category', 'Categoría seleccionada')} : '
          '${AppStrings.t(_draft.data['category'] as String, widget.locale)}',
        ),
      if (!_photoMode)
        ExpansionTile(
          key: const ValueKey('manual-item-catalog'),
          initiallyExpanded: !widget.photoIntakeEnabled,
          tilePadding: EdgeInsets.zero,
          title: Text(
            tr(
              'Ou choisir un objet sans photo',
              'Or choose an item without a photo',
              'O elige un objeto sin foto',
            ),
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _catalog
                  .map(
                    (e) => OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _draft.items.length >= 20
                          ? null
                          : () => _addItem(e.$1),
                      icon: Icon(e.$3),
                      label: Text(e.$2),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ..._draft.items.map(
        (item) => _item(Map<String, dynamic>.from(item as Map)),
      ),
      if (_photoMode && _draft.items.isNotEmpty)
        _photoItemAction(another: true),
      _next(
        _nextLabel,
        _draft.items.isEmpty ? null : () => _part(1),
        key: const ValueKey('booking-next-items'),
        why: tr(
          'Ajoutez au moins un article.',
          'Add at least one item.',
          'Añade al menos un artículo.',
        ),
      ),
    ];
  }

  /// Screen 2: both addresses, and the stairs question when it matters.
  List<Widget> _wherePart() {
    final ask = stairsQuestionNeeded(_draft.items);
    final answered =
        !ask ||
        (stairsAnswer(_draft.data, 'pickup') != null &&
            stairsAnswer(_draft.data, 'dropoff') != null);
    return [
      BookingQuestion(
        tr(
          'On le prend où, on le livre où ?',
          'Where do we pick it up and deliver it?',
          '¿Dónde lo recogemos y dónde lo entregamos?',
        ),
      ),
      ..._address(
        'pickup',
        _pickup,
        _draft.data['pickup_shortcut'] == 'marketplace'
            ? tr(
                'Adresse du vendeur',
                'Seller’s address',
                'Dirección del vendedor',
              )
            : tr('On le prend ici', 'We pick it up here', 'Lo recogemos aquí'),
        ask,
      ),
      const SizedBox(height: 12),
      ..._address(
        'dropoff',
        _dropoff,
        tr('On le livre ici', 'We deliver it here', 'Lo entregamos aquí'),
        ask,
      ),
      if (ask)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            tr(
              'On vous pose la question parce que vous avez un meuble ou un électroménager. Pour des boîtes seulement, elle n’apparaît pas.',
              'We ask because you have furniture or an appliance. For boxes only, this question does not appear.',
              'Lo preguntamos porque tienes un mueble o un electrodoméstico. Para cajas solamente, la pregunta no aparece.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      _next(
        _nextLabel,
        _addressesValid && answered
            ? () {
                if (!ask) {
                  // Boxes only: no stairs question and no stairs fee.
                  for (final key in ['pickup', 'dropoff']) {
                    applyStairsAnswer(_draft.data, key, 'no');
                    _draft.data.remove('${key}_stairs_answer');
                  }
                }
                // The common answer is preselected; the customer can change it.
                if (helpChoice(_draft.data) == null) {
                  applyHelpChoice(_draft.data, 'customer_helps');
                }
                _changed();
                _part(2);
              }
            : null,
        key: const ValueKey('booking-next-where'),
        why: !_addressesValid
            ? tr(
                'Choisissez les deux adresses dans les suggestions.',
                'Choose both addresses from the suggestions.',
                'Elige ambas direcciones en las sugerencias.',
              )
            : tr(
                'Répondez à la question sur les escaliers pour chaque adresse.',
                'Answer the stairs question for each address.',
                'Responde la pregunta sobre escaleras para cada dirección.',
              ),
      ),
    ];
  }

  /// Screen 3: who carries.
  List<Widget> _helpPart() {
    final choice = helpChoice(_draft.data);
    void pick(String value) {
      applyHelpChoice(_draft.data, value);
      _changed();
    }

    return [
      BookingQuestion(
        tr(
          'Pouvez-vous aider à porter ?',
          'Can you help carry?',
          '¿Puedes ayudar a cargar?',
        ),
      ),
      BookingBigChoice(
        key: const ValueKey('help-choice-customer_helps'),
        title: tr(
          'Oui, je donne un coup de main',
          'Yes, I can lend a hand',
          'Sí, puedo echar una mano',
        ),
        subtitle: tr(
          'Un chauffeur vient. Vous l’aidez à porter les objets lourds.',
          'One driver comes. You help carry the heavy items.',
          'Viene un conductor. Tú ayudas a cargar los objetos pesados.',
        ),
        selected: choice == 'customer_helps',
        onTap: () => pick('customer_helps'),
      ),
      BookingBigChoice(
        key: const ValueKey('help-choice-two_movers'),
        title: tr('Non, je ne peux pas', 'No, I can’t', 'No, no puedo'),
        subtitle: tr(
          'Deux personnes viennent et s’occupent de tout.',
          'Two people come and handle everything.',
          'Vienen dos personas y se encargan de todo.',
        ),
        selected: choice == 'two_movers',
        onTap: () => pick('two_movers'),
      ),
      Text(
        tr(
          'Le prix s’ajuste à votre choix.',
          'The price adjusts to your choice.',
          'El precio se ajusta a tu elección.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      _next(
        _nextLabel,
        choice == null ? null : () => _part(3),
        key: const ValueKey('booking-next-help'),
        why: tr(
          'Choisissez une réponse.',
          'Choose an answer.',
          'Elige una respuesta.',
        ),
      ),
    ];
  }

  /// Screen 4: when. As soon as possible, or a day and a fixed hour.
  List<Widget> _whenPart() {
    final now = DateTime.now();
    final days = bookingSlotDays(now);
    final dayKey = _draft.data['slot_day'] as String?;
    final day = slotDayFromKey(dayKey);
    final hour = (_draft.data['slot_hour'] as num?)?.toInt();
    final scheduled =
        !_draft.isImmediate &&
        (_draft.data['timing_mode'] == 'scheduled' ||
            _draft.data['requested_at'] != null);
    void applySlot() {
      final d = slotDayFromKey(_draft.data['slot_day'] as String?);
      final h = (_draft.data['slot_hour'] as num?)?.toInt();
      _draft.data['timing_mode'] = 'scheduled';
      _draft.data['requested_at'] =
          d != null && h != null && slotOpen(d, h, DateTime.now())
          ? DateTime(d.year, d.month, d.day, h).toUtc().toIso8601String()
          : null;
      _changed();
    }

    final ready =
        _draft.items.isNotEmpty &&
        _addressesValid &&
        (_draft.isImmediate || _draft.data['requested_at'] != null);
    return [
      BookingQuestion(tr('Quand ?', 'When?', '¿Cuándo?')),
      BookingBigChoice(
        key: const ValueKey('timing-immediate'),
        icon: Icons.bolt,
        title: tr('Dès que possible', 'As soon as possible', 'Lo antes posible'),
        subtitle: tr(
          'On cherche un chauffeur dès votre confirmation.',
          'We look for a driver as soon as you confirm.',
          'Buscamos un conductor en cuanto confirmes.',
        ),
        selected: _draft.isImmediate,
        onTap: () {
          if (_draft.isImmediate) return;
          _draft.data['timing_mode'] = 'immediate';
          _draft.data['requested_at'] = null;
          _changed();
        },
      ),
      BookingBigChoice(
        key: const ValueKey('timing-scheduled'),
        icon: Icons.calendar_today_outlined,
        title: tr(
          'Choisir un jour et une heure',
          'Choose a day and time',
          'Elegir un día y una hora',
        ),
        selected: scheduled,
        onTap: () {
          if (scheduled) return;
          _draft.data['timing_mode'] = 'scheduled';
          _changed();
        },
      ),
      if (scheduled) ...[
        Text(
          tr('Le jour', 'Day', 'Día'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        BookingPills(
          keyPrefix: 'slot-day',
          selected: dayKey,
          options: [
            for (final d in days)
              (slotDayKey(d), slotDayLabel(d, now, widget.locale)),
          ],
          onSelected: (key) {
            _draft.data['slot_day'] = key;
            final d = slotDayFromKey(key);
            final h = (_draft.data['slot_hour'] as num?)?.toInt();
            if (d != null && h != null && !slotOpen(d, h, DateTime.now())) {
              _draft.data['slot_hour'] = null;
            }
            applySlot();
          },
        ),
        if (day != null) ...[
          const SizedBox(height: 16),
          Text(
            tr('L’heure', 'Time', 'Hora'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          BookingPills(
            keyPrefix: 'slot-hour',
            selected: hour?.toString(),
            options: [
              for (final h in bookingSlotHours)
                if (slotOpen(day, h, now))
                  ('$h', slotHourLabel(h, widget.locale)),
            ],
            onSelected: (value) {
              _draft.data['slot_hour'] = int.parse(value);
              applySlot();
            },
          ),
        ],
        if (_draft.data['requested_at'] != null) ...[
          const SizedBox(height: 12),
          _localizedTime(
            _draft.data['requested_at'] as String,
            prefix: tr('Votre choix', 'Your choice', 'Tu elección'),
          ),
        ],
      ],
      _note(
        tr(
          'L’heure est votre souhait. Elle est confirmée quand un chauffeur accepte.',
          'The time is your preference. It is confirmed when a driver accepts.',
          'La hora es tu preferencia. Se confirma cuando un conductor acepta.',
        ),
      ),
      _next(
        tr('Voir mon prix', 'See my price', 'Ver mi precio'),
        ready
            ? () {
                _step(1);
                if (_uid != null) _run(_quote);
              }
            : null,
        key: const ValueKey('booking-see-price'),
        why: tr(
          'Choisissez « Dès que possible », ou un jour et une heure.',
          'Choose “As soon as possible”, or a day and a time.',
          'Elige «Lo antes posible», o un día y una hora.',
        ),
      ),
    ];
  }
  // Display only: preserve the instant and the existing local timezone.
  Widget _localizedTime(String? iso, {String prefix = ''}) {
    final heading = prefix.isEmpty ? '' : '$prefix : ';
    final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    final unknown = tr(
      'Date et heure non précisées',
      'Date and time not specified',
      'Fecha y hora no especificadas',
    );
    if (date == null) return Text('$heading$unknown');
    return FutureBuilder<MaterialLocalizations>(
      future: GlobalMaterialLocalizations.delegate.load(Locale(widget.locale)),
      builder: (context, snapshot) {
        final labels = snapshot.data;
        if (labels == null) return Text('$prefix…');
        final offset = date.timeZoneOffset;
        final minutes = offset.inMinutes.abs();
        final sign = offset.isNegative ? '-' : '+';
        final hours = (minutes ~/ 60).toString().padLeft(2, '0');
        final remainder = (minutes % 60).toString().padLeft(2, '0');
        final time = labels.formatTimeOfDay(
          TimeOfDay.fromDateTime(date),
          alwaysUse24HourFormat: true,
        );
        return Text(
          '$heading${labels.formatFullDate(date)} · $time (UTC$sign$hours:$remainder)',
        );
      },
    );
  }

  String get _tooFarMessage => tr(
    'Choisissez une date dans les 4 prochains jours.',
    'Choose a date within the next 4 days.',
    'Elige una fecha dentro de los próximos 4 días.',
  );

  // Presentation only: never round stored dimensions or quote payloads.
  String? _dimensionText(dynamic value) {
    if (value is! num || !value.isFinite) return value?.toString();
    var text = value.toStringAsFixed(2);
    // A positive measurement must not become a displayed zero.
    if (value != 0 && num.tryParse(text) == 0) {
      text = value.toStringAsPrecision(3);
    }
    if (text.contains('.') && !text.contains('e')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return widget.locale == 'en' ? text : text.replaceFirst('.', ',');
  }

  Widget _item(Map<String, dynamic> copy) {
    final item = _draft.items.firstWhere((i) => i['id'] == copy['id']) as Map;
    if (_photoMode) {
      return PhotoBookingItem(
        item: item,
        locale: widget.locale,
        categories: _catalog.map((e) => (e.$1, e.$2)).toList(),
        photoLoader: widget.photoLoader,
        onChanged: () {
          _photoSuggestions.remove(item['id']);
          _photoErrors.remove(item['id']);
          _changed();
        },
        onAnalyzePhoto: () => _run(() => _analyzePhoto(item)),
        suggestion: _photoSuggestions[item['id']],
        analysisError: _photoErrors[item['id']],
        analysisBusy: _busy,
        onRemove: () {
          _photoSuggestions.remove(item['id']);
          _photoErrors.remove(item['id']);
          _draft.items.remove(item);
          _changed();
        },
        onAddPhoto: () => _run(() => _addPhoto(item)),
      );
    }
    Widget number(String key, String label) => SizedBox(
      width: 145,
      child: TextFormField(
        key: ValueKey(
          '${item['id']}-$key-${item['dimension_unit']}-${item['weight_unit']}',
        ),
        initialValue: key == 'weight'
            ? item[key]?.toString() ?? ''
            : _dimensionText(item[key]) ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: tr('Inconnu', 'Unknown', 'Desconocido'),
        ),
        onChanged: (s) {
          item[key] = num.tryParse(s.replaceAll(',', '.'));
          _changed();
        },
      ),
    );
    return Card(
      key: ValueKey(item['id']),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['label'] as String,
                    decoration: InputDecoration(
                      labelText: tr('Objet', 'Item', 'Objeto'),
                    ),
                    maxLength: 160,
                    onChanged: (v) {
                      item['label'] = v;
                      _changed();
                    },
                  ),
                ),
                IconButton(
                  tooltip: tr(
                    'Retirer cet objet',
                    'Remove item',
                    'Quitar objeto',
                  ),
                  onPressed: () {
                    _draft.items.remove(item);
                    _changed();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: (item['quantity'] as num).toInt(),
                    decoration: InputDecoration(
                      labelText: tr('Quantité', 'Quantity', 'Cantidad'),
                    ),
                    items: List.generate(
                      20,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      item['quantity'] = v;
                      _changed();
                    },
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    initialValue: item['dimension_unit'] as String,
                    decoration: InputDecoration(
                      labelText: tr('Dimensions', 'Dimensions', 'Dimensiones'),
                    ),
                    items: ['cm', 'in']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != item['dimension_unit']) {
                        for (final key in ['length', 'width', 'height']) {
                          if (item[key] != null) {
                            item[key] =
                                (item[key] as num) *
                                (v == 'in' ? 1 / 2.54 : 2.54);
                          }
                        }
                        item['dimension_unit'] = v;
                        _changed();
                      }
                    },
                  ),
                ),
                number('length', tr('Longueur', 'Length', 'Largo')),
                number('width', tr('Largeur', 'Width', 'Ancho')),
                number('height', tr('Hauteur', 'Height', 'Alto')),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Unité de poids', 'Weight unit', 'Unidad de peso'),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: item['weight_unit'] as String,

                        items: ['kg', 'lb']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != item['weight_unit']) {
                            if (item['weight'] != null) {
                              item['weight'] =
                                  (item['weight'] as num) *
                                  (v == 'lb' ? 1 / 0.45359237 : 0.45359237);
                            }
                            item['weight_unit'] = v;
                            _changed();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                number(
                  'weight',
                  tr('Poids / pièce', 'Weight / piece', 'Peso / pieza'),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  'Mesures approximatives',
                  'Approximate measurements',
                  'Medidas aproximadas',
                ),
              ),
              value: item['approximate'] as bool,
              onChanged: (v) {
                item['approximate'] = v;
                _changed();
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  'Doit rester debout',
                  'Must remain upright',
                  'Debe permanecer vertical',
                ),
              ),
              value: item['upright'] as bool,
              onChanged: (v) {
                item['upright'] = v;
                _changed();
              },
            ),
            if (item['approximate'] == true ||
                item['length'] == null ||
                item['weight'] == null)
              Text(
                tr(
                  'Une photo aide à vérifier l’objet, sans en mesurer les dimensions ou le poids.',
                  'A photo helps review the item; it does not measure dimensions or weight.',
                  'Una foto ayuda a revisar el objeto; no mide dimensiones ni peso.',
                ),
              ),
            Wrap(
              spacing: 8,
              children: (item['photos'] as List? ?? [])
                  .map((p) => BookingPhoto(key: ValueKey(p), path: p as String))
                  .toList(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                tr(
                  'Ajouter une photo (facultatif)',
                  'Add a photo (optional)',
                  'Añadir una foto (opcional)',
                ),
              ),
              onPressed: (item['photos'] as List? ?? []).length >= 3
                  ? null
                  : () => _run(() async {
                      if (_uid == null) {
                        await _login();
                        return;
                      }
                      // Picker first (iOS Safari user-gesture rule), then save.
                      final upload = await selectBookingPhotoUpload();
                      if (upload == null) return;
                      await _save();
                      if (_saveError != null || !mounted) return;
                      final photos = item['photos'] as List? ?? <String>[];
                      final path = await upload(
                        uid: _uid!,
                        draftId: _draft.id,
                        itemId: item['id'] as String,
                        slot: photos.length,
                      );
                      if (path != null && mounted) {
                        photos.add(path);
                        item['photos'] = photos;
                        _changed();
                      }
                    }),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _address(
    String key,
    TextEditingController controller,
    String label,
    bool askStairs,
  ) {
    return [
      const SizedBox(height: 8),
      AddressAutocompleteField(
        key: ValueKey('$key-${_draft.id}'),
        controller: controller,
        searchInitialText: _draft.data['${key}_shortcut'] is String,
        resolvedText:
            (_draft.data[key] as Map?)?['formatted_address'] as String?,
        label: label,
        onResolved: (a) {
          _draft.data[key] = {
            'line1': a.line1,
            'city': a.city,
            'postal_code': a.postalCode,
            'lat': a.lat,
            'lng': a.lng,
            'formatted_address': a.formattedAddress,
            'place_id': a.placeId,
          };
          _changed();
        },
        onInvalidated: () {
          _draft.data[key] = null;
          _changed();
        },
      ),
      if (askStairs)
        BookingStairsQuestion(
          key: ValueKey('stairs-$key-${_draft.id}'),
          prefix: key,
          answer: stairsAnswer(_draft.data, key),
          locale: widget.locale,
          onAnswer: (answer) {
            applyStairsAnswer(_draft.data, key, answer);
            _changed();
          },
        ),
    ];
  }

  String _reason(String reason) => switch (reason) {
    'photo_policy_unconfigured' || 'photo_category_unconfigured' => tr(
      'La demande par photo n’est pas encore disponible pour cet objet.',
      'Photo booking is not available for this item yet.',
      'La solicitud por foto aún no está disponible para este objeto.',
    ),
    'photo_required' => tr(
      'Ajoutez une photo de chaque objet.',
      'Add a photo of each item.',
      'Añade una foto de cada objeto.',
    ),
    'object_confirmation_required' => tr(
      'Confirmez la catégorie et l’objet photographié.',
      'Confirm the category and pictured item.',
      'Confirma la categoría y el objeto fotografiado.',
    ),
    // Only sent by a server older than 2026-10-25 (no measurements since):
    // kept so the transition between the two deploys stays explained.
    'special_details_required' => tr(
      'Un article est classé « Autre » ou « Matériaux ». Touchez « Compléter », puis sur l’article : choisissez son type (ex. Laveuse / sécheuse, quantité 2), ou ouvrez « Précisions pour le chauffeur » et indiquez ses mesures et une précaution.',
      'An item is classified as “Other” or “Materials”. Tap “Complete”, then on the item: choose its type (e.g. Washer / dryer, quantity 2), or open “Notes for the driver” and enter its measurements and a precaution.',
      'Un artículo está clasificado como «Otro» o «Materiales». Toca «Completar» y, en el artículo, elige su tipo (p. ej. Lavadora / secadora, cantidad 2), o abre «Detalles para el conductor» e indica sus medidas y una precaución.',
    ),
    'no_eligible_photo_vehicle' => tr(
      'Aucun véhicule configuré ne répond aux informations fournies.',
      'No configured vehicle meets the supplied details.',
      'Ningún vehículo configurado cumple con los datos indicados.',
    ),
    'dimensions_unknown' => tr(
      'Complétez les trois dimensions de chaque objet.',
      'Complete all three dimensions for each item.',
      'Completa las tres dimensiones de cada objeto.',
    ),
    'weight_unknown' => tr(
      'Précisez le poids de chaque pièce.',
      'Enter the weight of each piece.',
      'Indica el peso de cada pieza.',
    ),
    'approximate_measurements' => tr(
      'Les mesures approximatives doivent être vérifiées avant réservation.',
      'Approximate measurements need verification before booking.',
      'Las medidas aproximadas deben verificarse antes de reservar.',
    ),
    'pricing_category_required' => tr(
      'La grille tarifaire nécessite une règle de prix par catégorie. Movi-K doit la configurer avant de calculer ce prix.',
      'The tariff needs a category pricing rule. Movi-K must configure it before this price can be calculated.',
      'La tarifa requiere una regla de precio por categoría. Movi-K debe configurarla antes de calcular el precio.',
    ),
    'pricing_handling_required' => tr(
      'Une condition tarifaire de manutention doit être précisée par Movi-K. Aucun supplément n’a été inventé.',
      'Movi-K must clarify a handling pricing condition. No surcharge has been invented.',
      'Movi-K debe precisar una condición de precio de manipulación. No se ha inventado ningún suplemento.',
    ),
    'object_category_required' => tr(
      'Confirmez la catégorie de votre objet.',
      'Confirm your item category.',
      'Confirma la categoría del objeto.',
    ),
    'capacity_unconfigured' => tr(
      'Les capacités vérifiées des véhicules ne sont pas encore configurées.',
      'Verified vehicle capacities have not been configured yet.',
      'Las capacidades verificadas de los vehículos aún no están configuradas.',
    ),
    'service_area_unconfigured' => tr(
      'La zone de service doit être confirmée par Movi-K.',
      'The service area needs confirmation by Movi-K.',
      'Movi-K debe confirmar la zona de servicio.',
    ),
    'outside_service_area' => tr(
      'Une adresse est hors de la zone desservie.',
      'An address is outside the service area.',
      'Una dirección está fuera de la zona de servicio.',
    ),
    'requested_time_past' => tr(
      'Choisissez une date et une heure futures.',
      'Choose a future date and time.',
      'Elige una fecha y hora futuras.',
    ),
    'requested_time_too_far' => _tooFarMessage,
    _ => tr(
      'Aucun chargement compatible n’est validé. Une vérification est nécessaire.',
      'No compatible loading plan is verified. A review is needed.',
      'No se ha verificado un plan de carga compatible. Se necesita una revisión.',
    ),
  };
  List<Widget> _price() => [
    BookingQuestion(tr('Votre prix', 'Your price', 'Tu precio')),
    if (_uid == null) ...[
      _note(
        tr(
          'Connectez-vous pour obtenir le prix officiel. Votre livraison sera reprise automatiquement. Aucun prix provisoire ne constitue une réservation.',
          'Sign in for your official price. Your delivery details will resume automatically. A provisional price is not a booking.',
          'Inicia sesión para obtener el precio oficial. Tu entrega se retomará automáticamente. Un precio provisional no es una reserva.',
        ),
      ),
      _button(
        tr(
          'Se connecter et obtenir mon prix',
          'Sign in and get my price',
          'Iniciar sesión y ver mi precio',
        ),
        () => _run(_login),
      ),
    ] else ...[
      if (_review != null && _review!['status'] != 'ready') _reviewFeedback(),
      if (_photoConfirmationNeeded) ...[
        if (_review == null)
          _note(
            tr(
              'Vérifiez la catégorie et confirmez chaque objet ci-dessous avant de demander votre prix.',
              'Check the category and confirm each item below before requesting your price.',
              'Revisa la categoría y confirma cada objeto abajo antes de pedir tu precio.',
            ),
          ),
        for (final item in _draft.items)
          if (item['identification_confirmed'] != true)
            _item(Map<String, dynamic>.from(item as Map)),
      ],
      if (_reviewReasons.any(
        (reason) => const {
          'photo_required',
          'special_details_required',
          'dimensions_unknown',
          'weight_unknown',
          'outside_service_area',
          'requested_time_past',
          'requested_time_too_far',
          'requested_time_missing',
        }.contains(reason),
      ))
        _button(
          tr(
            'Compléter les informations de ma livraison',
            'Complete my delivery details',
            'Completar los datos de mi entrega',
          ),
          // Open the screen that holds the missing answer.
          () => _step(
            0,
            part: _reviewReasons.contains('outside_service_area')
                ? 1
                : _reviewReasons.any((r) => r.startsWith('requested_time'))
                ? 3
                : 0,
          ),
        ),
      if (_review?['status'] == 'review_required' &&
          !_reviewReasons.any(_serviceReviewReasons.contains) &&
          _reviewReasons.any(
            (reason) => const {
              'no_verified_fit',
              'no_eligible_photo_vehicle',
              'approximate_measurements',
            }.contains(reason),
          ))
        TextButton.icon(
          icon: const Icon(Icons.support_agent),
          label: Text(
            tr(
              'Demander une vérification',
              'Request a review',
              'Solicitar revisión',
            ),
          ),
          onPressed: () => _run(() async {
            final result = await _api.call('requestBookingReview', {
              'draftId': _draft.id,
              'load': _draft.load,
              'stops': _draft.stops,
            });
            if (mounted) {
              setState(() {
                _message =
                    '${tr('Vérification demandée. Aucune mission ni aucun paiement créé. Référence', 'Review requested. No mission or payment created. Reference', 'Revisión solicitada. No se creó misión ni pago. Referencia')} : ${result['reviewId']}';
              });
            }
          }),
        ),
      if (_draft.quote != null) ...[
        _priceHero(),
        _recap(),
        _priceDetails(),
      ],
      if (!_draft.quoteValid)
        _button(
          _review != null && _review!['status'] != 'ready'
              ? tr(
                  'Réessayer le calcul du prix',
                  'Retry price calculation',
                  'Reintentar el cálculo del precio',
                )
              : tr(
                  'Calculer mon prix officiel',
                  'Calculate my official price',
                  'Calcular mi precio oficial',
                ),
          _photoConfirmationNeeded ? null : () => _run(_quote),
        ),
      if (!_photoMode &&
          (_review?['compatible_categories'] as List? ?? []).length > 1) ...[
        DropdownButtonFormField<String>(
          initialValue: _draft.quote?['vehicleCategory'] as String?,
          decoration: InputDecoration(
            labelText: tr(
              'Autre catégorie compatible',
              'Another compatible category',
              'Otra categoría compatible',
            ),
          ),
          items: (_review!['compatible_categories'] as List)
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v as String,
                  child: Text(_vehicleLabel(v)),
                ),
              )
              .toList(),
          onChanged: (v) {
            _draft.data['requested_vehicle'] = v;
            _changed();
            _run(_quote);
          },
        ),
        Text(
          tr(
            'Chaque changement demande un nouveau prix. La disponibilité d’un chauffeur reste à confirmer.',
            'Each change requires a new price. Driver availability is still to be confirmed.',
            'Cada cambio requiere un nuevo precio. Falta confirmar la disponibilidad del conductor.',
          ),
        ),
      ],
      if (_draft.quoteValid) ...[
        _note(
          _assignmentPending || _photoMode
              ? tr(
                  'Après votre réservation, un chauffeur de la région voit vos photos et accepte la livraison. Votre carte n’est utilisée qu’à ce moment.',
                  'After you book, a driver in the area sees your photos and accepts the delivery. Your card is only used at that point.',
                  'Después de reservar, un conductor de la zona ve tus fotos y acepta la entrega. Tu tarjeta solo se usa en ese momento.',
                )
              : tr(
                  'Le chauffeur vérifie que tout entre dans son véhicule quand il accepte.',
                  'The driver checks that everything fits in their vehicle when accepting.',
                  'El conductor verifica que todo cabe en su vehículo al aceptar.',
                ),
        ),
        _next(
          tr('Réserver à ce prix', 'Book at this price', 'Reservar a este precio'),
          () => _step(2),
          key: const ValueKey('booking-reserve'),
        ),
      ],
      TextButton(
        onPressed: () => _step(0, part: 0),
        child: Text(
          tr(
            'Modifier ma livraison',
            'Edit my delivery',
            'Modificar mi entrega',
          ),
        ),
      ),
    ],
    if (!_draft.quoteValid)
      _button(
        tr(
          'Continuer à préparer ma demande',
          'Continue preparing my request',
          'Seguir preparando mi solicitud',
        ),
        () => _step(2),
      ),
  ];
  /// The price in large type (screens 5 and 7).
  Widget _priceHero({bool compact = false}) {
    final quote = _draft.quote!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('booking-price-hero'),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 14 : 22,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2A5C),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                _moneyText(quote['customerTotal']),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 30 : 42,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Total officiel, taxes comprises',
                  'Official total, including taxes',
                  'Total oficial, impuestos incluidos',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD7E1F5)),
              ),
              Text(
                tr(
                  'Payé seulement une fois livré',
                  'Paid only once delivered',
                  'Se paga solo una vez entregado',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD7E1F5)),
              ),
            ],
          ),
        ),
        if (!_draft.quoteValid)
          _note(
            tr(
              'Ce prix a expiré : il est recalculé automatiquement. S’il ne change pas, vous continuez sans rien refaire ; s’il change, vous verrez le nouveau montant avant de confirmer.',
              'This price has expired: it is recalculated automatically. If it does not change, you continue without redoing anything; if it changes, you will see the new amount before confirming.',
              'Este precio expiró: se recalcula automáticamente. Si no cambia, continúas sin rehacer nada; si cambia, verás el nuevo monto antes de confirmar.',
            ),
            warning: true,
          ),
      ],
    );
  }

  /// What, where, when (and who, on the last screen), each with "Modifier".
  Widget _recap({bool contacts = false}) {
    String dims(Map item) {
      final l = _dimensionText(item['length']),
          w = _dimensionText(item['width']),
          h = _dimensionText(item['height']);
      if (l == null || w == null || h == null) return '';
      return ' · $l × $w × $h ${item['dimension_unit']}';
    }

    Widget row(
      IconData icon,
      Widget content,
      String key,
      VoidCallback onEdit,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F2A5C), size: 22),
          const SizedBox(width: 12),
          Expanded(child: content),
          TextButton(
            key: ValueKey('recap-edit-$key'),
            onPressed: _busy ? null : onEdit,
            child: Text(tr('Modifier', 'Edit', 'Modificar')),
          ),
        ],
      ),
    );
    final help = helpChoice(_draft.data);
    return Card(
      key: const ValueKey('booking-recap'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            row(
              Icons.inventory_2_outlined,
              Text(
                [
                  for (final raw in _draft.items)
                    '${(raw as Map)['quantity']} × ${raw['label']}${dims(raw)}',
                ].join('\n'),
              ),
              'items',
              () => _step(0, part: 0),
            ),
            row(
              Icons.place_outlined,
              Text('${_pickup.text}\n→ ${_dropoff.text}'),
              'where',
              () => _step(0, part: 1),
            ),
            if (help != null)
              row(
                Icons.people_alt_outlined,
                Text(
                  help == 'two_movers'
                      ? tr(
                          'Deux personnes viennent',
                          'Two people come',
                          'Vienen dos personas',
                        )
                      : tr(
                          'Un chauffeur, vous donnez un coup de main',
                          'One driver, you lend a hand',
                          'Un conductor, tú echas una mano',
                        ),
                ),
                'help',
                () => _step(0, part: 2),
              ),
            row(
              Icons.calendar_today_outlined,
              _draft.isImmediate
                  ? Text(
                      tr(
                        'Dès maintenant — selon la disponibilité du chauffeur',
                        'As soon as possible — subject to driver availability',
                        'Lo antes posible — según la disponibilidad del conductor',
                      ),
                    )
                  : _localizedTime(
                      _draft.data['requested_at'] as String?,
                      prefix: tr(
                        'Créneau demandé',
                        'Requested time',
                        'Horario solicitado',
                      ),
                    ),
              'when',
              () => _step(0, part: 3),
            ),
            if (contacts)
              row(
                Icons.phone_outlined,
                Text(
                  [
                    '${_draft.contacts['pickup_name']} · ${_draft.contacts['pickup_phone']}',
                    if (!_sameRecipient)
                      '${tr('Reçoit', 'Receives', 'Recibe')} : ${_draft.contacts['dropoff_name']} · ${_draft.contacts['dropoff_phone']}',
                  ].join('\n'),
                ),
                'contacts',
                () => _step(2),
              ),
          ],
        ),
      ),
    );
  }

  /// The full price breakdown, folded by default.
  Widget _priceDetails() {
    final quote = _draft.quote!;
    final breakdown = Map<String, dynamic>.from(
      quote['breakdown'] as Map? ?? {},
    );
    final lines = [
      ('missionBaseValue', tr('Transport', 'Transport', 'Transporte')),
      ('handlingFeesTotal', tr('Manutention', 'Handling', 'Manipulación')),
      ('waitingFee', tr('Attente', 'Waiting', 'Espera')),
      (
        'additionalStopsFee',
        tr('Arrêts supplémentaires', 'Additional stops', 'Paradas adicionales'),
      ),
      ('surchargesTotal', tr('Suppléments', 'Surcharges', 'Suplementos')),
      (
        'customerServiceFee',
        tr('Frais de service', 'Service fee', 'Tarifa de servicio'),
      ),
      ('customerDiscountAmount', tr('Remise', 'Discount', 'Descuento')),
      ('taxAmount', tr('Taxes', 'Taxes', 'Impuestos')),
    ];
    // Supplement by item class (2026-10-26): shown apart from the other
    // handling fees, one line per item, as the server computed it.
    final itemFee = breakdown['itemClassFeesTotal'];
    final itemLines = <(String, num)>[];
    if (itemFee is num && itemFee > 0) {
      final handling = breakdown['handlingFeesTotal'];
      if (handling is num) breakdown['handlingFeesTotal'] = handling - itemFee;
      for (final raw in (breakdown['itemClassFeeLines'] as List? ?? [])) {
        if (raw is! Map || raw['amount'] is! num) continue;
        final type = itemTypes.where((t) => t.id == raw['category']).firstOrNull;
        final label = type?.label(widget.locale) ?? tr('Objet', 'Item', 'Objeto');
        final cls = itemClassLabel('${raw['item_class']}', widget.locale).toLowerCase();
        final qty = raw['quantity'] is int && (raw['quantity'] as int) > 1
            ? ' ×${raw['quantity']}'
            : '';
        itemLines.add(('$label$qty ($cls)', raw['amount'] as num));
      }
      final linesSum = itemLines.fold<num>(0, (a, l) => a + l.$2);
      if (itemLines.isEmpty || (linesSum - itemFee).abs() > 0.005) {
        // Capped per order: one line with the capped total.
        itemLines
          ..clear()
          ..add((tr('Objets', 'Items', 'Objetos'), itemFee));
      }
    }
    return ExpansionTile(
      key: const ValueKey('booking-price-details'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        tr(
          'Voir le détail du prix',
          'See the price details',
          'Ver el detalle del precio',
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, amount) in itemLines)
          Padding(
            key: const ValueKey('booking-price-item-supplement'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${tr('Supplément', 'Supplement', 'Suplemento')} : $label'),
                  Text(_moneyText(amount)),
                ],
              ),
            ),
          ),
        for (final line in lines)
          if (breakdown[line.$1] is num && breakdown[line.$1] != 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(line.$2),
                    Text(
                      '${line.$1 == 'customerDiscountAmount' ? '-' : ''}${_moneyText(breakdown[line.$1])}',
                    ),
                  ],
                ),
              ),
            ),
        const Divider(),
        if (quote['assignmentPending'] == true)
          Text(
            tr(
              'Chauffeur à affecter après le calcul du prix',
              'Driver assignment follows the price calculation',
              'El conductor se asigna después del cálculo del precio',
            ),
          )
        else
          Text(
            '${tr('Véhicule recommandé', 'Recommended vehicle', 'Vehículo recomendado')} : ${_vehicleLabel(quote['vehicleCategory'] as String? ?? '')}',
          ),
        Text(
          '${tr('Distance routière', 'Road distance', 'Distancia por carretera')} : ${formatDistanceKm(quote['distanceKm'] is num ? quote['distanceKm'] as num : null, locale: widget.locale)}',
        ),
        _localizedTime(
          DateTime.fromMillisecondsSinceEpoch(
            (quote['expiresAtMillis'] as num).toInt(),
          ).toIso8601String(),
          prefix: tr('Valable jusqu’à', 'Valid until', 'Válido hasta'),
        ),
        const SizedBox(height: 8),
        _quoteLoadSummary(collapsible: false),
      ],
    );
  }

  String _vehicleLabel(String v) => switch (v) {
    'cargo_van' ||
    'cargoVan' => tr('Fourgonnette cargo', 'Cargo van', 'Furgoneta de carga'),
    'pickup_truck' ||
    'pickupTruck' => tr('Camionnette', 'Pickup truck', 'Camioneta'),
    'box_truck' ||
    'boxTruck' => tr('Camion fermé', 'Box truck', 'Camión cerrado'),
    _ => v.replaceAll('_', ' '),
  };
  String get _contactPhoneHint => tr(
    'Au moins 8 chiffres. Espaces, parenthèses et tirets permis. Maximum 25 caractères, ou 26 avec + au début.',
    'At least 8 digits. Spaces, parentheses and hyphens are allowed. Up to 25 characters, or 26 with a leading +.',
    'Al menos 8 dígitos. Se permiten espacios, paréntesis y guiones. Máximo 25 caracteres, o 26 con + al inicio.',
  );

  /// Email verification reminder, shown from step 1 so the customer is not
  /// stopped at step 3 after filling the whole request (2026-10-23). The
  /// verification email itself is sent at sign-up.
  List<Widget> _emailVerification(FirebaseAuthProvider auth) => [
    if (_uid != null && auth.user?.emailVerified != true) ...[
      Container(
        key: const ValueKey('booking-email-verification'),
        child: _note(
          tr(
            'Vérifiez votre adresse courriel pour pouvoir réserver. Nous avons envoyé un lien à ${auth.effectiveEmail ?? 'votre adresse'} (regardez aussi dans les courriels indésirables ou promotions). Cliquez sur le lien, puis sur « J’ai vérifié mon courriel ». Vous pouvez déjà préparer votre demande et obtenir votre prix.',
            'Verify your email address to be able to book. We sent a link to ${auth.effectiveEmail ?? 'your address'} (also check spam or promotions). Click the link, then “I verified my email”. You can already prepare your request and get your price.',
            'Verifica tu correo para poder reservar. Enviamos un enlace a ${auth.effectiveEmail ?? 'tu dirección'} (revisa también spam o promociones). Haz clic en el enlace y luego en «Ya verifiqué mi correo». Ya puedes preparar tu solicitud y obtener tu precio.',
          ),
          warning: true,
        ),
      ),
      Wrap(
        spacing: 12,
        children: [
          TextButton(
            onPressed: () => _run(() async {
              await auth.user?.sendEmailVerification();
              if (mounted) {
                setState(() {
                  _message = tr(
                    'Courriel de vérification envoyé.',
                    'Verification email sent.',
                    'Correo de verificación enviado.',
                  );
                });
              }
            }),
            child: Text(
              tr(
                'Renvoyer le courriel',
                'Resend the email',
                'Reenviar el correo',
              ),
            ),
          ),
          TextButton(
            onPressed: () => _run(() async {
              await auth.reloadCurrentUser();
              if (mounted) setState(() {});
            }),
            child: Text(
              tr(
                'J’ai vérifié mon courriel',
                'I verified my email',
                'Ya verifiqué mi correo',
              ),
            ),
          ),
        ],
      ),
    ],
  ];

  /// "C'est moi qui reçois la livraison": checked by default unless the
  /// draft already names a different recipient (2026-10-24).
  bool get _sameRecipient {
    final stored = _draft.data['same_recipient'];
    if (stored is bool) return stored;
    final c = _draft.contacts;
    final name = (c['dropoff_name'] as String? ?? '').trim();
    final phone = (c['dropoff_phone'] as String? ?? '').trim();
    return (name.isEmpty && phone.isEmpty) ||
        (name == (c['pickup_name'] as String? ?? '').trim() &&
            phone == (c['pickup_phone'] as String? ?? '').trim());
  }

  void _copyRecipient() {
    final contacts = _draft.data['contacts'] as Map;
    contacts['dropoff_name'] = contacts['pickup_name'];
    contacts['dropoff_phone'] = contacts['pickup_phone'];
  }

  Widget _contactField(String key, String label, {String? hint}) {
    final phone = key.contains('phone');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            key: ValueKey('contact-label-$key'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: TextFormField(
              key: ValueKey('${_draft.id}-$key'),
              initialValue: _draft.contacts[key] as String? ?? '',
              keyboardType: phone ? TextInputType.phone : TextInputType.text,
              autofillHints: phone ? [AutofillHints.telephoneNumber] : null,
              minLines: key == 'instructions' ? 2 : 1,
              maxLines: key == 'instructions' ? 4 : 1,
              decoration: InputDecoration(
                hintText: hint,
                helperText: phone ? _contactPhoneHint : null,
                helperMaxLines: 16,
                errorMaxLines: 20,
              ),
              // Match normalizeContacts: 8–25 allowed characters after
              // an optional leading +. Keep invalid pasted text editable.
              maxLength: key == 'instructions'
                  ? 1200
                  : phone
                  ? ((_draft.contacts[key] as String? ?? '').startsWith('+')
                        ? 26
                        : 25)
                  : 120,
              maxLengthEnforcement: phone ? MaxLengthEnforcement.none : null,
              validator: (v) {
                if (key == 'instructions') return null;
                if (v == null || v.trim().isEmpty) {
                  return tr('Champ requis', 'Required', 'Obligatorio');
                }
                if (phone &&
                    (!RegExp(r'^\+?[0-9 ()-]{8,25}$').hasMatch(v) ||
                        v.replaceAll(RegExp(r'\D'), '').length < 8)) {
                  return '${tr('Téléphone invalide', 'Invalid phone', 'Teléfono inválido')}\n$_contactPhoneHint';
                }
                return null;
              },
              onChanged: (v) {
                (_draft.data['contacts'] as Map)[key] = v;
                if (_sameRecipient && key.startsWith('pickup_')) {
                  _copyRecipient();
                }
                _changed(quote: false);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 6: who the driver calls. Prefilled from the account.
  List<Widget> _details(FirebaseAuthProvider auth) {
    final same = _sameRecipient;
    return [
      BookingQuestion(
        tr(
          'Qui le chauffeur appelle ?',
          'Who does the driver call?',
          '¿A quién llama el conductor?',
        ),
        hint: tr(
          'Déjà rempli avec votre compte. Vérifiez, c’est tout.',
          'Already filled in from your account. Just check it.',
          'Ya completado con tu cuenta. Solo verifícalo.',
        ),
      ),
      ..._emailVerification(auth),
      Form(
        key: _contactsForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _contactField('pickup_name', tr('Votre nom', 'Your name', 'Tu nombre')),
            _contactField(
              'pickup_phone',
              tr('Votre téléphone', 'Your phone', 'Tu teléfono'),
            ),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFDDE2EA), width: 2),
              ),
              child: CheckboxListTile(
                key: const ValueKey('booking-same-recipient'),
                controlAffinity: ListTileControlAffinity.leading,
                value: same,
                title: Text(
                  tr(
                    'C’est moi qui reçois la livraison',
                    'I am receiving the delivery',
                    'Yo recibo la entrega',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onChanged: (v) {
                  _draft.data['same_recipient'] = v == true;
                  if (v == true) _copyRecipient();
                  _changed(quote: false);
                },
              ),
            ),
            if (!same) ...[
              const SizedBox(height: 8),
              _contactField(
                'dropoff_name',
                tr(
                  'Nom de la personne qui reçoit',
                  'Name of the person receiving',
                  'Nombre de quien recibe',
                ),
              ),
              _contactField(
                'dropoff_phone',
                tr(
                  'Téléphone de la personne qui reçoit',
                  'Phone of the person receiving',
                  'Teléfono de quien recibe',
                ),
              ),
            ],
            _contactField(
              'instructions',
              tr(
                'Un mot pour le chauffeur (facultatif)',
                'A note for the driver (optional)',
                'Una nota para el conductor (opcional)',
              ),
              hint: tr(
                'Ex. : sonner à la porte de côté',
                'E.g. ring at the side door',
                'Ej.: tocar la puerta lateral',
              ),
            ),
          ],
        ),
      ),
      _next(
        _nextLabel,
        () {
          if (_sameRecipient) {
            _copyRecipient();
            _changed(quote: false);
          }
          if (_contactsForm.currentState?.validate() == true) _step(3);
        },
        key: const ValueKey('booking-next-details'),
      ),
    ];
  }

  /// "Ce que vous payez, et quand", in 3 sentences (owner mockup 2026-10-23).
  Widget _paymentTimeline() {
    Widget line(String bold, String text, {Color dot = const Color(0xFF0F2A5C)}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  color: dot,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$bold ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: text),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    final low =
        _draft.quote?['customerTotal'] is num &&
        (_draft.quote!['customerTotal'] as num) < 30;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        key: const ValueKey('booking-payment-timeline'),
        initiallyExpanded: true,
        title: Text(
          tr(
            'Ce que vous payez, et quand',
            'What you pay, and when',
            'Qué pagas y cuándo',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(
            tr('Maintenant :', 'Now:', 'Ahora:'),
            tr(
              'vous enregistrez votre carte chez Stripe. Rien n’est débité.',
              'you save your card with Stripe. Nothing is charged.',
              'guardas tu tarjeta en Stripe. No se cobra nada.',
            ),
          ),
          line(
            tr(
              'Quand un chauffeur accepte :',
              'When a driver accepts:',
              'Cuando un conductor acepta:',
            ),
            tr(
              'le montant est réservé sur votre carte (au moins 30 \$).',
              'the amount is held on your card (at least 30 \$).',
              'el monto se reserva en tu tarjeta (al menos 30 \$).',
            ),
          ),
          line(
            tr('Après la livraison :', 'After delivery:', 'Después de la entrega:'),
            tr(
              'seul votre prix est débité. Le reste est libéré.',
              'only your price is charged. The rest is released.',
              'solo se cobra tu precio. El resto se libera.',
            ),
          ),
          line(
            tr(
              'Annulation tardive ou déplacement pour rien :',
              'Late cancellation or wasted trip:',
              'Cancelación tardía o viaje en vano:',
            ),
            '30 \$.',
            dot: const Color(0xFFB85E10),
          ),
          if (low)
            Padding(
              key: const ValueKey('booking-minimum-hold'),
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr(
                  'Votre prix est inférieur à 30 \$ : 30 \$ sont réservés, puis seul votre prix est prélevé à la fin.',
                  'Your price is below 30 \$: 30 \$ is held, then only your price is charged at the end.',
                  'Tu precio es inferior a 30 \$: se reservan 30 \$ y al final solo se cobra tu precio.',
                ),
                style: const TextStyle(color: Color(0xFF54607A)),
              ),
            ),
        ],
      ),
    );
  }

  /// Screen 7: confirm and pay.
  List<Widget> _confirmation(FirebaseAuthProvider auth) => [
    BookingQuestion(
      tr('Dernière étape', 'Last step', 'Último paso'),
      hint: tr(
        'Vérifiez, acceptez les conditions, enregistrez votre carte.',
        'Check, accept the terms, save your card.',
        'Verifica, acepta las condiciones y guarda tu tarjeta.',
      ),
    ),
    if (_internalTestAllowed && _assignmentPending && _draft.quoteValid) ...[
      _note(
        tr(
          'Compte de test autorisé : créez la demande, puis affectez le chauffeur manuellement dans l’administration. Aucun paiement ne sera déclenché.',
          'Authorized test account: create the request, then assign the driver manually in administration. No payment will be triggered.',
          'Cuenta de prueba autorizada: crea la solicitud y asigna el conductor manualmente en administración. No se iniciará ningún pago.',
        ),
      ),
      _button(
        tr(
          'Créer la demande de test — sans paiement',
          'Create test request — no payment',
          'Crear solicitud de prueba — sin pago',
        ),
        () => _run(_submitInternalTest),
      ),
    ],
    if (!_canPay || !_draft.quoteValid)
      _note(
        tr(
          'Résumé de votre brouillon. Aucune réservation confirmée, aucun paiement effectué. Vos coordonnées restent modifiables.',
          'Draft summary. No booking confirmed and no payment made. Your contact details remain editable.',
          'Resumen del borrador. No hay reserva confirmada ni pago realizado. Puedes editar tus datos.',
        ),
        warning: true,
      ),
    if (_draft.quote == null)
      _note(
        tr(
          'Prix non disponible : le prix officiel doit être calculé avant toute confirmation.',
          'Price unavailable: the official price must be calculated before confirmation.',
          'Precio no disponible: el precio oficial debe calcularse antes de confirmar.',
        ),
      ),
    if (_draft.quote != null) _priceHero(compact: true),
    _recap(contacts: true),
    if (!_draft.quoteValid)
      _button(
        tr(
          'Recalculer mon prix',
          'Recalculate my price',
          'Recalcular mi precio',
        ),
        // Stay on this step: same price keeps the card and the acceptance.
        () => _run(() async {
          await _ensureFreshQuote();
        }),
      ),
    _paymentTimeline(),
    if (_draft.quote != null) _priceDetails(),
    // Without approved terms, the single availability banner above already
    // explains that booking is not open; do not repeat it here.
    if (_policy != null) ...[
      BookingTermsSection(
        contract: BookingContract(_policy!),
        locale: widget.locale,
        accepted: _acceptanceCurrent,
        beforeOpen: () async {
          await _save();
        },
        onChanged: _busy
            ? null
            : (value) {
                _draft.data['accepted'] = value == true;
                _draft.data['accepted_contract_hash'] =
                    _policy!['contract_hash'];
                _draft.data['accepted_quote_id'] = _draft.quote?['quoteId'];
                _draft.data['accepted_locale'] = widget.locale;
                _changed(quote: false);
              },
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _draft.data['marketing'] == true,
        title: Text(
          tr(
            'Je souhaite recevoir des offres (facultatif).',
            'I would like to receive offers (optional).',
            'Quiero recibir ofertas (opcional).',
          ),
        ),
        onChanged: (v) {
          _draft.data['marketing'] = v;
          _changed(quote: false);
        },
      ),
    ],
    if (auth.user?.emailVerified != true)
      _note(
        tr(
          'Votre courriel doit être vérifié à l’étape 6.',
          'Verify your email in step 6.',
          'Verifica tu correo en el paso 6.',
        ),
        warning: true,
      ),
    // Never claim the card is saved: Stripe confirms it, then the server
    // authorizes only when a driver accepts.
    if (_cardReady)
      _note(
        tr(
          'Moyen de paiement prêt pour la confirmation. Cela ne confirme ni une autorisation ni un paiement.',
          'Payment method ready for confirmation. This does not confirm an authorization or a payment.',
          'Método de pago listo para confirmar. Esto no confirma una autorización ni un pago.',
        ),
        key: const ValueKey('booking-card-ready'),
      )
    else ...[
      _note(
        tr(
          'Préparation du moyen de paiement non confirmée.',
          'Payment method preparation is not confirmed.',
          'La preparación del método de pago no está confirmada.',
        ),
      ),
      _button(
        tr(
          'Enregistrer ma carte avec Stripe',
          'Save my card with Stripe',
          'Guardar mi tarjeta con Stripe',
        ),
        _readyToConfirm(auth) ? () => _run(_setupCard) : null,
        icon: Icons.lock_outline,
      ),
      Text(
        tr(
          'Paiement sécurisé par Stripe. Movi-K ne voit jamais votre numéro de carte.',
          'Payment secured by Stripe. Movi-K never sees your card number.',
          'Pago protegido por Stripe. Movi-K nunca ve el número de tu tarjeta.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      TextButton(
        onPressed: _canPay && !_busy ? () => _run(_refreshCard) : null,
        child: Text(
          tr(
            'J’ai terminé chez Stripe : vérifier',
            'I finished on Stripe: check status',
            'Terminé en Stripe: verificar',
          ),
        ),
      ),
    ],
    if (_confirmBlockers(auth).isNotEmpty)
      Container(
        key: const ValueKey('booking-confirm-blockers'),
        child: _note(
          '${tr('Pour confirmer, il reste à :', 'To confirm, you still need to:', 'Para confirmar, falta:')}\n${_confirmBlockers(auth).map((b) => '• $b').join('\n')}',
          warning: true,
        ),
      ),
    _next(
      tr(
        'Confirmer ma demande de livraison',
        'Confirm my delivery request',
        'Confirmar mi solicitud de entrega',
      ),
      _cardReady && _readyToConfirm(auth) ? () => _run(_confirm) : null,
      key: const ValueKey('booking-confirm'),
    ),
  ];
  Widget _quoteLoadSummary({bool collapsible = true}) => BookingLoadSummary(
    collapsible: collapsible,
    snapshot: _quoteSnapshot,
    locale: widget.locale,
    photoLoader: widget.photoLoader,
  );

  /// A price calculated before driver assignment carries no server booking
  /// snapshot (booking: null). The summary then shows the customer's own
  /// answers — access, help, handlers and equipment — instead of
  /// "à préciser" and "null" (2026-10-23). Items and the requested time are
  /// already listed above the summary, so they are not repeated.
  Map<String, dynamic> get _quoteSnapshot {
    final booking = _draft.quote?['booking'];
    if (booking is Map && booking['load'] is Map) {
      return Map<String, dynamic>.from(booking);
    }
    return {
      'load': {
        'pickup': _draft.data['pickup_access'],
        'dropoff': _draft.data['dropoff_access'],
        'handlers': _draft.data['handlers'],
        'equipment': _draft.data['equipment'],
      },
    };
  }
  /// Why the confirm button is disabled, shown right above it (2026-10-23).
  List<String> _confirmBlockers(FirebaseAuthProvider auth) => [
    if (!_canPay)
      tr(
        'attendre l’ouverture de la réservation pour votre compte.',
        'wait until booking opens for your account.',
        'esperar a que la reserva se abra para tu cuenta.',
      ),
    if (_draft.quote == null)
      tr(
        'calculer votre prix (étape 5).',
        'calculate your price (step 5).',
        'calcular tu precio (paso 5).',
      ),
    if (auth.user?.emailVerified != true)
      tr(
        'vérifier votre adresse courriel (étape 6).',
        'verify your email address (step 6).',
        'verificar tu correo (paso 6).',
      ),
    if (_policy != null && !_acceptanceCurrent)
      tr(
        'lire les conditions et cocher « J’accepte… » ci-dessus.',
        'read the terms and tick “I accept…” above.',
        'leer las condiciones y marcar «Acepto…» arriba.',
      ),
    if (!_cardReady)
      tr(
        'enregistrer votre carte avec Stripe (bouton ci-dessus).',
        'save your card with Stripe (button above).',
        'guardar tu tarjeta con Stripe (botón arriba).',
      ),
  ];

  // An expired price does not block the buttons: _setupCard and _confirm
  // recalculate it first (_ensureFreshQuote) and stop if the total changed.
  bool _readyToConfirm(FirebaseAuthProvider auth) =>
      _canPay &&
      _acceptanceCurrent &&
      _draft.quote != null &&
      auth.user?.emailVerified == true;
  bool get _acceptanceCurrent =>
      _draft.data['accepted'] == true &&
      _policy != null &&
      _draft.data['accepted_contract_hash'] == _policy!['contract_hash'] &&
      _draft.data['accepted_quote_id'] == _draft.quote?['quoteId'] &&
      _draft.data['accepted_locale'] == widget.locale;
  Map<String, dynamic> get _currentConsent => BookingContract(_policy!).consent(
    widget.locale,
    accepted: _acceptanceCurrent,
    marketing: _draft.data['marketing'] == true,
  );
}
