// Fiche chauffeur › Documents (Daniel, 2026-11-12) : une place par document
// (permis recto, permis verso, immatriculation, assurance, photos du
// véhicule, autres). Pour chaque place, un agent peut ajouter le document
// reçu par courriel à infos@movi-k.com (adminAddDriverDocument) ; il se
// vérifie et s'approuve ensuite comme un envoi du chauffeur.
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../backend/models/driver_document.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/driver_document_slots.dart';
import '../../../../models/enums.dart';
import '../../../../services/document_file_picker.dart';

/// 8 Mo, comme la limite du serveur.
const maxStaffDocumentBytes = 8 * 1024 * 1024;

typedef AddDriverDocumentCall = Future<void> Function(Map<String, dynamic> data);
typedef PickDocumentFile = Future<PickedDocumentFile?> Function();

class DriverDocumentChecklist extends StatefulWidget {
  const DriverDocumentChecklist({
    super.key,
    required this.driverId,
    required this.docs,
    required this.t,
    required this.tileFor,
    this.pick,
    this.addCall,
  });

  final String driverId;
  final List<DriverDocument> docs;
  final String Function(String) t;
  final Widget Function(DriverDocument) tileFor;

  /// Tests : remplacent le sélecteur de fichier et l'appel serveur.
  final PickDocumentFile? pick;
  final AddDriverDocumentCall? addCall;

  @override
  State<DriverDocumentChecklist> createState() => _DriverDocumentChecklistState();
}

class _DriverDocumentChecklistState extends State<DriverDocumentChecklist> {
  String? _busySlot;

  String t(String key) => widget.t(key);

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _add(DriverDocumentSlot slot) async {
    if (_busySlot != null) return;
    PickedDocumentFile? picked;
    try {
      picked = await (widget.pick ?? pickDocumentFile)();
    } catch (_) {
      _snack(t('admin_driver_doc_add_error'), error: true);
      return;
    }
    if (picked == null || !mounted) return;
    if (picked.bytes.length > maxStaffDocumentBytes) {
      _snack(t('admin_driver_doc_too_large'), error: true);
      return;
    }
    setState(() => _busySlot = slot.id);
    final data = <String, dynamic>{
      'driverId': widget.driverId,
      'slot': slot.id,
      'fileName': picked.name,
      'mimeType': picked.mimeType,
      'dataBase64': base64Encode(picked.bytes),
    };
    try {
      if (widget.addCall != null) {
        await widget.addCall!(data);
      } else {
        await FirebaseFunctions.instance
            .httpsCallable(
              'adminAddDriverDocument',
              options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
            )
            .call(data);
      }
      _snack(t('admin_driver_doc_add_success'));
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? t('admin_driver_doc_add_error'), error: true);
    } catch (_) {
      _snack(t('admin_driver_doc_add_error'), error: true);
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Widget _place({
    required DriverDocumentSlot slot,
    required String label,
    required List<DriverDocument> docs,
    String? emptyNote,
    bool showMissing = true,
  }) {
    final busy = _busySlot == slot.id;
    final empty = docs.isEmpty;
    return Padding(
      key: ValueKey('doc-slot-${slot.id}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (empty && emptyNote != null)
                      Text(
                        emptyNote,
                        key: ValueKey('doc-note-${slot.id}'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      )
                    else if (empty && showMissing)
                      Text(
                        slot.required
                            ? '${t('admin_driver_doc_missing')} · ${t('admin_driver_doc_required')}'
                            : t('admin_driver_doc_missing'),
                        key: ValueKey('doc-missing-${slot.id}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: slot.required ? AppColors.error : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                key: ValueKey('doc-add-${slot.id}'),
                onPressed: _busySlot == null ? () => _add(slot) : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(t('admin_driver_doc_add')),
              ),
            ],
          ),
          ...docs.map(widget.tileFor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupDriverDocuments(widget.docs);
    final legacyLicence = groups.others.any(isLegacyLicence);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t('admin_driver_doc_add_hint'),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        for (final slot in driverDocumentSlots)
          _place(
            slot: slot,
            label: t(slot.labelKey),
            docs: groups.bySlot[slot.id]!,
            emptyNote: legacyLicence && slot.type == DriverDocumentType.driversLicence
                ? t('admin_driver_doc_legacy_licence')
                : null,
          ),
        _place(
          slot: otherDocumentSlot,
          label: t('admin_driver_doc_others'),
          docs: groups.others,
          showMissing: false,
        ),
      ],
    );
  }
}
