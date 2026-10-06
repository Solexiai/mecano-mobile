import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../services/delivery_request_draft.dart';

import 'package:flutter/material.dart';
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
  });
  final String locale;
  final String? initialCategory;
  final BookingApi? api;
  final BookingDraftStorage? storage;
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
      _configurationChecked = false;
  int _epoch = 0;
  String? _message, _saveError;
  Map<String, dynamic>? _policy, _review;
  BookingApi get _api => widget.api ?? FirebaseBookingApi(_uid);
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  List<String> get _titles => [
    tr('Ma livraison', 'My delivery', 'Mi entrega'),
    tr('Mon prix', 'My price', 'Mi precio'),
    tr('Mes coordonnées', 'My details', 'Mis datos'),
    tr(
      'Confirmation et paiement',
      'Confirmation and payment',
      'Confirmación y pago',
    ),
  ];
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
      _refreshCard();
    }
  }

  void _invalidateAddress(String key, TextEditingController controller) {
    final address = _draft.data[key] as Map?;
    if (_loaded &&
        address != null &&
        address['formatted_address'] != controller.text) {
      _draft.data[key] = null;
      _changed();
    }
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
    _pickup.text =
        (_draft.data['pickup'] as Map?)?['formatted_address'] as String? ?? '';
    _dropoff.text =
        (_draft.data['dropoff'] as Map?)?['formatted_address'] as String? ?? '';
    _cardReady = false;
    _busy = false;
    _message = null;
    _review = null;
    _policy = null;
    _configurationChecked = false;
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
              _draft.step = 1;
            });
          }
        }
      }
    }
  }

  Future<void> _loadConfiguration(int epoch) async {
    Map<String, dynamic>? policy;
    try {
      final config = await _api.call('getBookingConfiguration');
      if (config['policy'] is Map) {
        final value = Map<String, dynamic>.from(config['policy'] as Map);
        if (value['approved'] == true) policy = value;
      }
    } catch (_) {
      // Keep the draft usable when the reservation service is unavailable.
    }
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _policy = policy;
      _configurationChecked = true;
    });
  }

  String get _reservationUnavailable => tr(
    'La réservation est indisponible pour le moment. Vous pouvez préparer votre demande dans cet onglet, sans paiement ni réservation confirmée.',
    'Booking is currently unavailable. You can prepare your request in this tab, without payment or a confirmed booking.',
    'La reserva no está disponible por el momento. Puedes preparar tu solicitud en esta pestaña, sin pago ni reserva confirmada.',
  );

  void _changed({bool quote = true}) {
    setState(() {
      final hadQuote = _draft.quote != null;
      _draft.changed(affectsQuote: quote);
      if (quote) {
        _review = null;
        if (hadQuote) {
          _message = tr(
            'La livraison a changé : un nouveau devis est requis.',
            'Your delivery changed. Request a new quote.',
            'La entrega cambió. Solicita un nuevo presupuesto.',
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
    } on BookingPhotoFormatException {
      if (mounted && epoch == _epoch) {
        setState(() {
          _message = tr(
            'Choisissez une photo JPEG de moins de 5 Mo.',
            'Choose a JPEG photo under 5 MB.',
            'Elige una foto JPEG de menos de 5 MB.',
          );
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
            'Connexion indisponible. Vos données restent dans cet onglet. Réessayez.',
            'Connection unavailable. Your details remain in this tab. Retry.',
            'Conexión no disponible. Tus datos permanecen en esta pestaña. Reintenta.',
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
  Future<void> _quote() async {
    if (_policy == null) {
      setState(() => _message = _reservationUnavailable);
      return;
    }
    if (_uid == null) {
      await _login();
      return;
    }
    final revision = _draft.revision, epoch = _epoch;
    final result = await _api.call('reviewDeliveryLoad', {
      'load': _draft.load,
      'stops': _draft.stops,
    });
    if (!mounted || epoch != _epoch || revision != _draft.revision) return;
    setState(() {
      _review = result;
    });
    if (result['status'] != 'ready') return;
    final quote = await _api.call('calculateDeliveryQuote', {
      'booking': _draft.load,
      'stops': _draft.stops,
      if (_draft.data['requested_vehicle'] != null)
        'requestedVehicleCategory': _draft.data['requested_vehicle'],
    });
    if (!mounted || epoch != _epoch || revision != _draft.revision) return;
    setState(() {
      _draft.data['quote'] = quote;
      _draft.data['accepted'] = false;
    });
    await _save();
    await _refreshCard();
  }

  Future<void> _refreshCard() async {
    if (_draft.quote == null ||
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
    final epoch = _epoch;
    await _save();
    if (_saveError != null) return;
    final result = await _api.call('startBookingCardSetup', {
      'quoteId': _draft.quote!['quoteId'],
      'locale': widget.locale,
      'accepted': _draft.data['accepted'],
      'termsVersion': _policy!['version'],
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

  Future<void> _confirm() async {
    final epoch = _epoch;
    await _save();
    final q = _draft.quote!;
    final result = await _api.call('createDeliveryRequest', {
      'quoteId': q['quoteId'],
      'booking': _draft.load,
      'contacts': _draft.contacts,
      'consent': {
        'terms_version': _policy!['version'],
        'accepted': _draft.data['accepted'],
        'marketing': _draft.data['marketing'],
      },
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
    });
    if (notify) _changed();
  }

  List<(String, String, IconData)> get _catalog => [
    ('sofa', tr('Canapé', 'Sofa', 'Sofá'), Icons.weekend_outlined),
    ('armchair', tr('Fauteuil', 'Armchair', 'Sillón'), Icons.chair_outlined),
    (
      'fridge',
      tr('Réfrigérateur', 'Refrigerator', 'Refrigerador'),
      Icons.kitchen_outlined,
    ),
    (
      'washer',
      tr('Laveuse', 'Washer', 'Lavadora'),
      Icons.local_laundry_service_outlined,
    ),
    ('table', tr('Table', 'Table', 'Mesa'), Icons.table_restaurant_outlined),
    ('tv', tr('Téléviseur', 'TV', 'Televisor'), Icons.tv_outlined),
    ('boxes', tr('Boîtes', 'Boxes', 'Cajas'), Icons.inventory_2_outlined),
    (
      'materials',
      tr('Matériaux', 'Materials', 'Materiales'),
      Icons.construction_outlined,
    ),
    (
      'other',
      tr('Autre objet', 'Other item', 'Otro objeto'),
      Icons.category_outlined,
    ),
  ];
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _note(String text, {bool warning = false}) => Container(
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
  void _step(int step) {
    setState(() {
      _draft.step = step;
      _message = null;
    });
    _changed(quote: false);
  }

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
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Objets volumineux · Demande de créneau · Devis calculé par Movi-K',
                    'Large items · Requested time · Quote calculated by Movi-K',
                    'Objetos voluminosos · Horario solicitado · Presupuesto de Movi-K',
                  ),
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
                  if (_configurationChecked && _policy == null)
                    _note(_reservationUnavailable, warning: true),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      4,
                      (i) => ChoiceChip(
                        label: Text('${i + 1}. ${_titles[i]}'),
                        selected: _draft.step == i,
                        onSelected: _busy || i > _draft.step
                            ? null
                            : (_) => _step(i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _uid == null
                        ? tr(
                            'Brouillon conservé 24 h dans cet onglet. Fermer l’onglet efface le brouillon invité.',
                            'Draft kept in this tab for 24 hours. Closing the tab removes the guest draft.',
                            'Borrador guardado en esta pestaña por 24 h. Al cerrar la pestaña se borra el borrador de invitado.',
                          )
                        : tr(
                            'Brouillon privé sauvegardé automatiquement, valable 24 h.',
                            'Private draft saved automatically, valid for 24 hours.',
                            'Borrador privado guardado automáticamente, válido por 24 h.',
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
                        if (_draft.step == 0) ..._delivery(),
                        if (_draft.step == 1) ..._price(),
                        if (_draft.step == 2) ..._details(auth),
                        if (_draft.step == 3) ..._confirmation(auth),
                      ],
                    ),
                  ),
                  if (_draft.step > 0)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _step(_draft.step - 1),
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

  List<Widget> _delivery() => [
    if (DemoDataService.deliveryCategories.contains(_draft.data['category']))
      _note(
        '${tr('Catégorie sélectionnée', 'Selected category', 'Categoría seleccionada')} : '
        '${AppStrings.t(_draft.data['category'] as String, widget.locale)}',
      ),
    _heading(
      tr(
        'Que souhaitez-vous transporter ?',
        'What are you moving?',
        '¿Qué quieres transportar?',
      ),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _catalog
          .map(
            (e) => OutlinedButton.icon(
              onPressed: _draft.items.length >= 20
                  ? null
                  : () => _addItem(e.$1),
              icon: Icon(e.$3),
              label: Text(e.$2),
            ),
          )
          .toList(),
    ),
    ..._draft.items.map(
      (item) => _item(Map<String, dynamic>.from(item as Map)),
    ),
    _note(
      tr(
        'Mesurez l’objet emballé. Laissez une mesure vide si vous ne la connaissez pas : une vérification sera nécessaire. Aucune dimension n’est supposée.',
        'Measure the packaged item. Leave an unknown measurement blank: review will be required. No dimensions are assumed.',
        'Mide el objeto embalado. Deja en blanco las medidas desconocidas: será necesaria una revisión. No se suponen dimensiones.',
      ),
    ),
    _heading(
      tr('Ramassage et livraison', 'Pickup and delivery', 'Recogida y entrega'),
    ),
    ..._address(
      'pickup',
      _pickup,
      tr('Adresse de ramassage', 'Pickup address', 'Dirección de recogida'),
    ),
    ..._address(
      'dropoff',
      _dropoff,
      tr('Adresse de livraison', 'Delivery address', 'Dirección de entrega'),
    ),
    _heading(
      tr(
        'Services et créneau demandé',
        'Services and requested time',
        'Servicios y horario solicitado',
      ),
    ),
    DropdownButtonFormField<int>(
      initialValue: (_draft.data['handlers'] as num).toInt(),
      decoration: InputDecoration(
        labelText: tr(
          'Nombre de manutentionnaires requis',
          'Required handlers',
          'Personas necesarias para cargar',
        ),
      ),
      items: [
        1,
        2,
      ].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
      onChanged: (n) {
        _draft.data['handlers'] = n;
        _changed();
      },
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children:
          [
                ('dolly', tr('Diable', 'Dolly', 'Carretilla')),
                ('straps', tr('Sangles', 'Straps', 'Correas')),
                (
                  'liftgate',
                  tr('Hayon élévateur', 'Liftgate', 'Plataforma elevadora'),
                ),
              ]
              .map(
                (e) => FilterChip(
                  label: Text(e.$2),
                  selected: (_draft.data['equipment'] as List).contains(e.$1),
                  onSelected: (v) {
                    final list = _draft.data['equipment'] as List;
                    v ? list.add(e.$1) : list.remove(e.$1);
                    _changed();
                  },
                ),
              )
              .toList(),
    ),
    OutlinedButton.icon(
      icon: const Icon(Icons.schedule),
      onPressed: () => _chooseTime(),
      label: Text(
        _draft.data['requested_at'] == null
            ? tr(
                'Choisir une date et une heure',
                'Choose date and time',
                'Elegir fecha y hora',
              )
            : _formatTime(_draft.data['requested_at'] as String),
      ),
    ),
    _note(
      tr(
        'La date et l’heure expriment votre souhait. Elles dépendent de l’acceptation et de la disponibilité du chauffeur.',
        'Date and time are your preference. They depend on driver acceptance and availability.',
        'La fecha y hora expresan tu preferencia y dependen de la aceptación y disponibilidad del conductor.',
      ),
    ),
    _button(
      tr('Voir mon prix', 'See my price', 'Ver mi precio'),
      _draft.items.isEmpty ||
              !_addressesValid ||
              _draft.data['requested_at'] == null
          ? null
          : () {
              _step(1);
              if (_uid != null) _run(_quote);
            },
    ),
    if (!_addressesValid)
      Text(
        tr(
          'Sélectionnez deux adresses dans les suggestions, avec ville et code postal.',
          'Select both addresses from suggestions, including city and postal code.',
          'Selecciona ambas direcciones en las sugerencias, con ciudad y código postal.',
        ),
      ),
  ];
  String _formatTime(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    return date == null
        ? iso
        : '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    _draft.data['requested_at'] = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc().toIso8601String();
    _changed();
  }

  Widget _item(Map<String, dynamic> copy) {
    final item = _draft.items.firstWhere((i) => i['id'] == copy['id']) as Map;
    Widget number(String key, String label) => SizedBox(
      width: 145,
      child: TextFormField(
        key: ValueKey(
          '${item['id']}-$key-${item['dimension_unit']}-${item['weight_unit']}',
        ),
        initialValue: item[key]?.toString() ?? '',
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
                  child: DropdownButtonFormField<String>(
                    initialValue: item['weight_unit'] as String,
                    decoration: InputDecoration(
                      labelText: tr(
                        'Unité de poids',
                        'Weight unit',
                        'Unidad de peso',
                      ),
                    ),
                    items: ['kg', 'lb']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
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
                  'Ajouter une photo JPEG (facultatif)',
                  'Add a JPEG photo (optional)',
                  'Añadir foto JPEG (opcional)',
                ),
              ),
              onPressed: (item['photos'] as List? ?? []).length >= 3
                  ? null
                  : () => _run(() async {
                      if (_uid == null) {
                        await _login();
                        return;
                      }
                      await _save();
                      if (_saveError != null) return;
                      final photos = item['photos'] as List? ?? <String>[];
                      final path = await uploadBookingPhoto(
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
  ) {
    final access = _draft.data['${key}_access'] as Map;
    return [
      const SizedBox(height: 18),
      AddressAutocompleteField(
        key: ValueKey('$key-${_draft.id}'),
        controller: controller,
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
      // A restored address must also be invalidated if the user types. The
      // autocomplete field did not previously know its initial resolved text.
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 150,
            child: TextFormField(
              key: ValueKey('$key-floor-${_draft.id}'),
              initialValue: '${access['floor']}',
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: tr(
                  'Étage (0 = sol)',
                  'Floor (0 = ground)',
                  'Piso (0 = calle)',
                ),
              ),
              onChanged: (v) {
                access['floor'] = int.tryParse(v) ?? -999;
                _changed();
              },
            ),
          ),
          FilterChip(
            label: Text(tr('Escaliers', 'Stairs', 'Escaleras')),
            selected: access['stairs'] == true,
            onSelected: (v) {
              access['stairs'] = v;
              _changed();
            },
          ),
          FilterChip(
            label: Text(tr('Ascenseur', 'Elevator', 'Ascensor')),
            selected: access['elevator'] == true,
            onSelected: (v) {
              access['elevator'] = v;
              _changed();
            },
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          key == 'pickup'
              ? tr('Aide au chargement', 'Loading help', 'Ayuda para cargar')
              : tr(
                  'Aide au déchargement',
                  'Unloading help',
                  'Ayuda para descargar',
                ),
        ),
        value: access['help'] as bool,
        onChanged: (v) {
          access['help'] = v;
          _changed();
        },
      ),
    ];
  }

  String _reason(String reason) => switch (reason) {
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
    _ => tr(
      'Aucun chargement compatible n’est validé. Une vérification est nécessaire.',
      'No compatible loading plan is verified. A review is needed.',
      'No se ha verificado un plan de carga compatible. Se necesita una revisión.',
    ),
  };
  List<Widget> _price() => [
    _heading(_titles[1]),
    if (!_configurationChecked)
      const LinearProgressIndicator()
    else if (_policy == null)
      _button(
        tr(
          'Vérifier à nouveau la disponibilité',
          'Check availability again',
          'Comprobar disponibilidad de nuevo',
        ),
        () => _run(() => _loadConfiguration(_epoch)),
      )
    else if (_uid == null) ...[
      _note(
        tr(
          'Connectez-vous pour obtenir le devis officiel. Votre livraison sera reprise automatiquement. Aucun prix provisoire ne constitue une réservation.',
          'Sign in for your official quote. Your delivery details will resume automatically. A provisional price is not a booking.',
          'Inicia sesión para obtener el presupuesto oficial. Tu entrega se retomará automáticamente. Un precio provisional no es una reserva.',
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
      if (_review?['reasons'] is List)
        ...(_review!['reasons'] as List).map(
          (r) => _note(_reason(r as String), warning: true),
        ),
      if (_review?['status'] == 'review_required')
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
      if (_draft.quote != null) ...[_quoteLoadSummary(), ..._quoteSummary()],
      if (!_draft.quoteValid)
        _button(
          tr(
            'Calculer mon devis officiel',
            'Calculate my official quote',
            'Calcular mi presupuesto oficial',
          ),
          () => _run(_quote),
        ),
      if ((_review?['compatible_categories'] as List? ?? []).length > 1) ...[
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
          tr(
            'Le véhicule recommandé est vérifié à nouveau avec le véhicule réel du chauffeur à l’acceptation.',
            'The recommended vehicle is checked against the driver’s actual vehicle on acceptance.',
            'Se verifica la recomendación con el vehículo real del conductor al aceptar.',
          ),
        ),
        _button(
          tr(
            'Continuer vers mes coordonnées',
            'Continue to my details',
            'Continuar a mis datos',
          ),
          () => _step(2),
        ),
      ],
      TextButton(
        onPressed: () => _step(0),
        child: Text(
          tr(
            'Modifier ma livraison',
            'Edit my delivery',
            'Modificar mi entrega',
          ),
        ),
      ),
    ],
  ];
  List<Widget> _quoteSummary() {
    final quote = _draft.quote!;
    final breakdown = Map<String, dynamic>.from(
      quote['breakdown'] as Map? ?? {},
    );
    String money(dynamic n) => '${(n as num).toStringAsFixed(2)} CAD';
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
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                money(quote['customerTotal']),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                tr(
                  'Total officiel, taxes comprises',
                  'Official total, including taxes',
                  'Total oficial, impuestos incluidos',
                ),
              ),
              const Divider(height: 28),
              for (final line in lines)
                if (breakdown[line.$1] is num && breakdown[line.$1] != 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(line.$2)),
                        Text(
                          '${line.$1 == 'customerDiscountAmount' ? '-' : ''}${money(breakdown[line.$1])}',
                        ),
                      ],
                    ),
                  ),
              const Divider(),
              Text(
                '${tr('Véhicule recommandé', 'Recommended vehicle', 'Vehículo recomendado')} : ${_vehicleLabel(quote['vehicleCategory'] as String? ?? '')}',
              ),
              Text(
                '${tr('Distance routière', 'Road distance', 'Distancia por carretera')} : ${(quote['distanceKm'] as num).toStringAsFixed(1)} km',
              ),
              Text(
                '${tr('Valable jusqu’à', 'Valid until', 'Válido hasta')} ${_formatTime(DateTime.fromMillisecondsSinceEpoch((quote['expiresAtMillis'] as num).toInt()).toIso8601String())}',
              ),
            ],
          ),
        ),
      ),
      if (!_draft.quoteValid)
        _note(
          tr(
            'Ce devis a expiré. Recalculez-le avant de confirmer.',
            'This quote has expired. Recalculate before confirming.',
            'Este presupuesto expiró. Recálculalo antes de confirmar.',
          ),
          warning: true,
        ),
    ];
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
  List<Widget> _details(FirebaseAuthProvider auth) => [
    _heading(_titles[2]),
    Text(auth.effectiveEmail ?? ''),
    if (auth.user?.emailVerified != true) ...[
      _note(
        tr(
          'Vérifiez votre adresse courriel pour réserver.',
          'Verify your email address to book.',
          'Verifica tu correo electrónico para reservar.',
        ),
        warning: true,
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
              tr('Envoyer le courriel', 'Send email', 'Enviar correo'),
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
    Form(
      key: _contactsForm,
      child: Column(
        children: [
          for (final field in [
            (
              'pickup_name',
              tr(
                'Nom au ramassage',
                'Pickup contact name',
                'Nombre en recogida',
              ),
            ),
            (
              'pickup_phone',
              tr(
                'Téléphone au ramassage',
                'Pickup phone',
                'Teléfono en recogida',
              ),
            ),
            (
              'dropoff_name',
              tr(
                'Nom à la livraison',
                'Delivery contact name',
                'Nombre en entrega',
              ),
            ),
            (
              'dropoff_phone',
              tr(
                'Téléphone à la livraison',
                'Delivery phone',
                'Teléfono en entrega',
              ),
            ),
            (
              'instructions',
              tr(
                'Instructions pour les contacts (facultatif)',
                'Contact instructions (optional)',
                'Instrucciones de contacto (opcional)',
              ),
            ),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                key: ValueKey('${_draft.id}-${field.$1}'),
                initialValue: _draft.contacts[field.$1] as String? ?? '',
                keyboardType: field.$1.contains('phone')
                    ? TextInputType.phone
                    : TextInputType.text,
                autofillHints: field.$1.contains('phone')
                    ? [AutofillHints.telephoneNumber]
                    : null,
                decoration: InputDecoration(labelText: field.$2),
                maxLength: field.$1 == 'instructions' ? 1200 : 120,
                validator: (v) {
                  if (field.$1 == 'instructions') return null;
                  if (v == null || v.trim().isEmpty) {
                    return tr('Champ requis', 'Required', 'Obligatorio');
                  }
                  if (field.$1.contains('phone') &&
                      !RegExp(r'^\+?[0-9 ()-]{8,25}$').hasMatch(v)) {
                    return tr(
                      'Téléphone invalide',
                      'Invalid phone',
                      'Teléfono inválido',
                    );
                  }
                  return null;
                },
                onChanged: (v) {
                  (_draft.data['contacts'] as Map)[field.$1] = v;
                  _changed(quote: false);
                },
              ),
            ),
        ],
      ),
    ),
    _button(
      tr('Vérifier et confirmer', 'Review and confirm', 'Revisar y confirmar'),
      () {
        if (_contactsForm.currentState?.validate() == true) _step(3);
      },
    ),
  ];
  List<Widget> _confirmation(FirebaseAuthProvider auth) => [
    _heading(_titles[3]),
    Text('${_pickup.text}\n↓\n${_dropoff.text}'),
    const SizedBox(height: 12),
    for (final item in _draft.items)
      Text(
        '${item['quantity']} × ${item['label']} · ${item['length'] ?? '?'} × ${item['width'] ?? '?'} × ${item['height'] ?? '?'} ${item['dimension_unit']} · ${item['weight'] ?? '?'} ${item['weight_unit']}',
      ),
    if (_draft.data['requested_at'] != null)
      Text(
        '${tr('Créneau demandé', 'Requested time', 'Horario solicitado')} : ${_formatTime(_draft.data['requested_at'] as String)}',
      ),
    Text(
      '${tr('Manutentionnaires', 'Handlers', 'Personas para cargar')} : ${_draft.data['handlers']}',
    ),
    Text(
      '${tr('Ramassage', 'Pickup', 'Recogida')} : ${_draft.contacts['pickup_name']} · ${_draft.contacts['pickup_phone']}',
    ),
    Text(
      '${tr('Livraison', 'Delivery', 'Entrega')} : ${_draft.contacts['dropoff_name']} · ${_draft.contacts['dropoff_phone']}',
    ),
    Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => _step(0),
          child: Text(
            tr('Modifier la livraison', 'Edit delivery', 'Modificar entrega'),
          ),
        ),
        TextButton(
          onPressed: () => _step(2),
          child: Text(
            tr(
              'Modifier mes coordonnées',
              'Edit my details',
              'Modificar mis datos',
            ),
          ),
        ),
      ],
    ),
    if (_draft.quote != null) ...[_quoteLoadSummary(), ..._quoteSummary()],
    if (!_draft.quoteValid)
      _button(
        tr(
          'Recalculer mon prix',
          'Recalculate my price',
          'Recalcular mi precio',
        ),
        () {
          _step(1);
          _run(_quote);
        },
      ),
    if (_policy == null)
      _note(
        tr(
          'Les conditions de réservation et d’annulation doivent être publiées et validées par Movi-K. Votre brouillon est conservé.',
          'Booking and cancellation terms must be published and approved by Movi-K. Your draft is saved.',
          'Movi-K debe publicar y aprobar las condiciones de reserva y cancelación. Tu borrador se conserva.',
        ),
        warning: true,
      )
    else ...[
      _heading(
        tr(
          'Conditions de réservation',
          'Booking terms',
          'Condiciones de reserva',
        ),
      ),
      _note(_policyText('cancellation_text')),
      _note(_policyText('payment_text')),
      Wrap(
        spacing: 12,
        children: [
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse(_policy!['terms_url'] as String)),
            child: Text(
              tr(
                'Conditions générales',
                'Terms of service',
                'Condiciones generales',
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse(_policy!['privacy_url'] as String)),
            child: Text(tr('Confidentialité', 'Privacy', 'Privacidad')),
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _draft.data['accepted'] == true,
        title: Text(
          tr(
            'J’accepte les conditions et la politique d’annulation affichées.',
            'I accept the displayed terms and cancellation policy.',
            'Acepto las condiciones y política de cancelación mostradas.',
          ),
        ),
        onChanged: (v) {
          _draft.data['accepted'] = v;
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
    _note(
      tr(
        'Votre carte est enregistrée chez Stripe. Aucun numéro de carte n’est transmis à Movi-K. L’autorisation a lieu quand un chauffeur accepte, puis le paiement est capturé après la livraison.',
        'Your card is saved with Stripe. Movi-K does not receive your card number. Authorization occurs when a driver accepts; payment is captured after delivery.',
        'Stripe guarda tu tarjeta. Movi-K no recibe el número. Se autoriza cuando acepta un conductor y se cobra después de la entrega.',
      ),
    ),
    if (auth.user?.emailVerified != true)
      _note(
        tr(
          'Votre courriel doit être vérifié à l’étape 3.',
          'Verify your email in step 3.',
          'Verifica tu correo en el paso 3.',
        ),
        warning: true,
      ),
    if (_cardReady)
      _note(
        tr(
          'Carte enregistrée. Aucun paiement effectué à cette étape.',
          'Card saved. No payment made at this step.',
          'Tarjeta guardada. No se ha realizado ningún pago en este paso.',
        ),
      )
    else ...[
      _button(
        tr(
          'Enregistrer ma carte avec Stripe',
          'Save my card with Stripe',
          'Guardar mi tarjeta con Stripe',
        ),
        _readyToConfirm(auth) ? () => _run(_setupCard) : null,
        icon: Icons.lock_outline,
      ),
      TextButton(
        onPressed: () => _run(_refreshCard),
        child: Text(
          tr(
            'J’ai terminé chez Stripe : vérifier',
            'I finished on Stripe: check status',
            'Terminé en Stripe: verificar',
          ),
        ),
      ),
    ],
    _button(
      tr(
        'Confirmer ma demande de livraison',
        'Confirm my delivery request',
        'Confirmar mi solicitud de entrega',
      ),
      _cardReady && _readyToConfirm(auth) ? () => _run(_confirm) : null,
      icon: Icons.check,
    ),
  ];
  Widget _quoteLoadSummary() => BookingLoadSummary(
    snapshot: Map<String, dynamic>.from(_draft.quote!['booking'] as Map? ?? {}),
    locale: widget.locale,
  );
  bool _readyToConfirm(FirebaseAuthProvider auth) =>
      _policy != null &&
      _policy!['setup_enabled'] == true &&
      _draft.data['accepted'] == true &&
      _draft.quoteValid &&
      auth.user?.emailVerified == true;
  String _policyText(String key) {
    final map = Map<String, dynamic>.from(_policy![key] as Map);
    return map[widget.locale] as String? ?? map['fr'] as String;
  }
}
