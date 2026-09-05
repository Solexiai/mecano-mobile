// ---------------------------------------------------------------------------
// AddressAutocompleteField — champ d'adresse UNIQUE avec suggestions en
// temps réel (MOVI-K — CORRECTION UX LIVRAISON — ADRESSES RÉELLES +
// AUTOCOMPLETE + GÉOCODAGE).
//
// Remplace les anciens champs séparés "adresse / ville / code postal /
// latitude / longitude" par UN SEUL champ texte : le client tape une
// adresse partielle, une liste de suggestions réelles apparaît, il en
// sélectionne une, et ce widget notifie le parent (`onResolved`) avec
// l'adresse COMPLÈTEMENT résolue (adresse formatée, composants structurés,
// lat/lng, placeId) — jamais de coordonnées tapées manuellement.
//
// GARANTIE FAIL-CLOSED CENTRALE : si l'utilisateur modifie le texte APRÈS
// avoir sélectionné une adresse (donc le texte affiché ne correspond plus
// exactement à la dernière adresse résolue), `onInvalidated()` est appelé
// IMMÉDIATEMENT — le parent doit alors considérer les anciennes
// coordonnées comme invalides tant qu'une nouvelle sélection/résolution
// n'a pas eu lieu. Ceci évite le scénario "adresse A affichée avec les
// coordonnées de l'adresse B".
//
// Ce widget ne connaît AUCUN détail Google/fournisseur : il dépend
// uniquement de `AddressAutocompleteProvider` (via
// `AddressBackendLocator.autocompleteProvider`, ou une instance passée
// explicitement — pratique pour les tests).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../providers/locale_provider.dart';
import '../services/address/address_autocomplete_provider.dart';
import '../services/address/address_backend_locator.dart';
import '../services/address/address_suggestion.dart';

enum _SuggestionStatus { idle, loading, results, noResults, unavailable, resolving }

class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<ResolvedAddress> onResolved;

  /// Appelé dès que le texte affiché ne correspond plus à la dernière
  /// adresse résolue (édition manuelle après sélection, champ vidé, etc.).
  /// Le parent DOIT alors invalider toute coordonnée précédemment stockée.
  final VoidCallback onInvalidated;

  /// Permet d'injecter un provider explicite (tests). Si `null`, utilise
  /// `AddressBackendLocator.autocompleteProvider` au moment de l'appel
  /// (jamais mis en cache), pour respecter les changements de seam de test
  /// en cours d'exécution.
  final AddressAutocompleteProvider? provider;

  final Duration debounceDuration;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.onResolved,
    required this.onInvalidated,
    this.provider,
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  _SuggestionStatus _status = _SuggestionStatus.idle;
  List<AddressSuggestion> _suggestions = const [];

  /// Texte EXACT de la dernière adresse résolue avec succès (formattedAddress).
  /// Tant que `widget.controller.text == _lastResolvedText`, le champ est
  /// considéré comme "adresse valide" — toute divergence invalide.
  String? _lastResolvedText;

  Timer? _debounceTimer;

  AddressAutocompleteProvider get _effectiveProvider =>
      widget.provider ?? AddressBackendLocator.autocompleteProvider;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;

    // Le texte correspond EXACTEMENT à la dernière adresse résolue (ex:
    // vient d'être positionné par _selectSuggestion) : rien à faire, ni
    // invalidation ni nouvelle recherche.
    if (_lastResolvedText != null && text == _lastResolvedText) {
      return;
    }

    // Le texte diverge d'une résolution précédente (édition manuelle après
    // sélection) : invalider IMMÉDIATEMENT les anciennes coordonnées.
    if (_lastResolvedText != null) {
      _lastResolvedText = null;
      widget.onInvalidated();
    }

    _debounceTimer?.cancel();

    final trimmed = text.trim();
    if (trimmed.length < 3) {
      setState(() {
        _suggestions = const [];
        _status = _SuggestionStatus.idle;
      });
      return;
    }

    _debounceTimer = Timer(widget.debounceDuration, () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    setState(() => _status = _SuggestionStatus.loading);
    try {
      final results = await _effectiveProvider.searchSuggestions(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _status = results.isEmpty ? _SuggestionStatus.noResults : _SuggestionStatus.results;
      });
    } on AddressProviderUnavailableException {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _status = _SuggestionStatus.unavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _status = _SuggestionStatus.unavailable;
      });
    }
  }

  Future<void> _selectSuggestion(AddressSuggestion suggestion) async {
    setState(() {
      _status = _SuggestionStatus.resolving;
      _suggestions = const [];
    });
    try {
      final resolved = await _effectiveProvider.resolvePlace(suggestion.placeId);
      if (!mounted) return;
      // IMPORTANT : positionner `_lastResolvedText` AVANT d'assigner
      // `controller.text` — l'assignation notifie les listeners de façon
      // SYNCHRONE, donc `_onTextChanged` doit déjà voir la nouvelle valeur
      // comme "résolue" pour ne pas déclencher une invalidation immédiate
      // de la résolution qu'on vient d'obtenir.
      _lastResolvedText = resolved.formattedAddress;
      widget.controller.text = resolved.formattedAddress;
      setState(() => _status = _SuggestionStatus.idle);
      widget.onResolved(resolved);
    } on AddressProviderUnavailableException {
      if (!mounted) return;
      setState(() => _status = _SuggestionStatus.unavailable);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _SuggestionStatus.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: _lastResolvedText == null ? t('delivery_address_guidance') : null,
            helperMaxLines: 2,
            suffixIcon: _status == _SuggestionStatus.loading || _status == _SuggestionStatus.resolving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_lastResolvedText != null
                    ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                    : null),
          ),
        ),
        if (_status == _SuggestionStatus.noResults)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t('delivery_address_no_suggestions'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        if (_status == _SuggestionStatus.unavailable)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t('delivery_address_provider_unavailable'),
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (_status == _SuggestionStatus.results)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                  title: Text(suggestion.description, style: const TextStyle(fontSize: 13.5)),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
