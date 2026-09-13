// ---------------------------------------------------------------------------
// DriverStatusScreen — vue RÉACTIVE du statut de dossier chauffeur.
//
// Point d'entrée post-onboarding (et de retour) pour un chauffeur
// Firebase Auth connecté. Couvre les 6 statuts minimum requis :
// registration_incomplete, pending_review, documents_required, approved,
// rejected, suspended (+ inactive, valeur d'enum existante mais hors
// périmètre workflow normal).
//
// STABILISATION PRÉ-PILOTE :
// - Le statut administratif réel reste visible en temps réel.
// - `documents_required` affiche le motif transmis par l'administration ET
//   permet maintenant de téléverser un ou plusieurs documents de remplacement
//   avant de re-soumettre le dossier. Aucun faux succès : la transition vers
//   `pending_review` n'est appelée qu'après tous les uploads réussis.
// - Le chauffeur peut consulter ses notifications depuis cet écran.
// - Une fois approuvé, il dispose d'un CTA explicite vers l'espace chauffeur.
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/driver_document.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/notification_bell.dart';

class DriverStatusScreen extends StatefulWidget {
  final String locale;
  const DriverStatusScreen({super.key, required this.locale});

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  bool _actionInProgress = false;
  bool _pickingReplacement = false;
  String? _actionError;
  final Map<DriverDocumentType, _SelectedReplacementDocument>
      _replacementDocuments = {};

  String? _cachedUid;
  Stream<DriverProfileV2?>? _driverProfileStream;

  Stream<DriverProfileV2?> _ensureDriverProfileStream(String uid) {
    if (_cachedUid != uid || _driverProfileStream == null) {
      _cachedUid = uid;
      _driverProfileStream = BackendLocator.driverRepository.watchDriverProfile(uid);
    }
    return _driverProfileStream!;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _buildBody(context, t, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String Function(String) t,
    FirebaseAuthProvider auth,
  ) {
    if (!auth.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/${widget.locale}/connexion');
      });
      return const Center(child: CircularProgressIndicator());
    }

    final uid = auth.effectiveUid!;
    final repo = BackendLocator.driverRepository;

    return StreamBuilder<DriverProfileV2?>(
      stream: _ensureDriverProfileStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: t('driver_status_error'),
            onRetry: () => setState(() {}),
            retryLabel: t('driver_status_refresh'),
          );
        }
        final profile = snap.data;
        if (profile == null) {
          return _ErrorCard(
            message: t('driver_status_no_profile'),
            onRetry: () =>
                context.go('/${widget.locale}/devenir-chauffeur/inscription'),
            retryLabel: t('driver_status_complete_registration'),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: NotificationBell(userId: uid),
            ),
            Text(
              t('driver_status_view_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            _StatusCard(
              profile: profile,
              t: t,
              busy: _actionInProgress,
              actionError: _actionError,
              onCompleteRegistration: () =>
                  context.go('/${widget.locale}/devenir-chauffeur/inscription'),
              onToggleOnline: (goOnline) => _runAction(
                () => repo.setDriverOnlineStatus(uid, goOnline),
              ),
              onRefresh: () => setState(() {}),
              onGoHome: () => context.go('/${widget.locale}'),
              onGoToDriverDashboard: () =>
                  context.go('/${widget.locale}/fournisseur/tableau-de-bord'),
            ),
            if (profile.status == DriverStatus.documentsRequired) ...[
              const SizedBox(height: 16),
              _buildDocumentCorrectionCard(uid, t),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDocumentCorrectionCard(
    String uid,
    String Function(String) t,
  ) {
    const types = <DriverDocumentType>[
      DriverDocumentType.driversLicence,
      DriverDocumentType.insurance,
      DriverDocumentType.vehicleRegistration,
      DriverDocumentType.identity,
      DriverDocumentType.vehiclePhoto,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('driver_status_documents_required'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            t('driver_status_documents_required_message'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...types.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReplacementDocumentRow(
                label: t(type.key),
                fileName: _replacementDocuments[type]?.fileName,
                busy: _actionInProgress || _pickingReplacement,
                selectLabel: t('driver_onboarding_document_select'),
                editLabel: t('driver_onboarding_document_edit'),
                onPick: () => _pickReplacementDocument(type),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ElevatedButton.icon(
            onPressed: _actionInProgress ||
                    _pickingReplacement ||
                    _replacementDocuments.isEmpty
                ? null
                : () => _uploadReplacementDocumentsAndResubmit(uid),
            icon: _actionInProgress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_outlined, size: 18),
            label: Text(t('driver_status_resubmit')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReplacementDocument(DriverDocumentType type) async {
    if (_pickingReplacement || _actionInProgress) return;
    final t = context.read<LocaleProvider>().t;
    setState(() {
      _pickingReplacement = true;
      _actionError = null;
    });

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(t('driver_onboarding_document_source_camera')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(t('driver_onboarding_document_source_gallery')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _replacementDocuments[type] = _SelectedReplacementDocument(
          bytes: bytes,
          fileName: picked.name,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _actionError = t('driver_onboarding_error_document_pick_failed'));
    } finally {
      if (mounted) setState(() => _pickingReplacement = false);
    }
  }

  Future<void> _uploadReplacementDocumentsAndResubmit(String uid) async {
    if (_replacementDocuments.isEmpty || _actionInProgress) return;
    final t = context.read<LocaleProvider>().t;
    final selected = Map<DriverDocumentType, _SelectedReplacementDocument>.from(
      _replacementDocuments,
    );

    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });

    try {
      final uploadRepo = BackendLocator.driverDocumentUploadRepository;
      final driverRepo = BackendLocator.driverRepository;

      for (final entry in selected.entries) {
        final type = entry.key;
        final selectedFile = entry.value;
        final extension = selectedFile.fileName.contains('.')
            ? selectedFile.fileName.split('.').last.toLowerCase()
            : 'jpg';
        final contentType =
            extension == 'pdf' ? 'application/pdf' : 'image/jpeg';
        final fileName =
            '${type.firestoreValue}_${DateTime.now().microsecondsSinceEpoch}.$extension';

        await uploadRepo.uploadDriverDocument(
          driverId: uid,
          fileName: fileName,
          bytes: selectedFile.bytes,
          contentType: contentType,
        );

        await driverRepo.submitDriverDocument(
          DriverDocument(
            id: const Uuid().v4(),
            driverId: uid,
            type: type,
            status: DriverDocumentStatus.uploaded,
            storageBucketPath: 'driver_documents/$uid/$fileName',
            uploadedAt: DateTime.now(),
          ),
        );
      }

      // La candidature ne repasse à pending_review QU'APRÈS que tous les
      // nouveaux fichiers et leurs métadonnées Firestore ont été persistés.
      await driverRepo.submitForReview();

      if (!mounted) return;
      setState(() => _replacementDocuments.clear());
    } catch (e) {
      debugPrint('DriverStatusScreen replacement upload failed: $e');
      if (!mounted) return;
      setState(() => _actionError = t('admin_action_error'));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (e) {
      debugPrint('DriverStatusScreen action failed: $e');
      if (!mounted) return;
      setState(() => _actionError = context.read<LocaleProvider>().t('admin_action_error'));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }
}

class _SelectedReplacementDocument {
  final Uint8List bytes;
  final String fileName;

  const _SelectedReplacementDocument({
    required this.bytes,
    required this.fileName,
  });
}

class _ReplacementDocumentRow extends StatelessWidget {
  final String label;
  final String? fileName;
  final bool busy;
  final String selectLabel;
  final String editLabel;
  final VoidCallback onPick;

  const _ReplacementDocumentRow({
    required this.label,
    required this.fileName,
    required this.busy,
    required this.selectLabel,
    required this.editLabel,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final selected = fileName != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.success : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_outline : Icons.description_outlined,
            color: selected ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 2),
                  Text(
                    fileName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : onPick,
            child: Text(selected ? editLabel : selectLabel),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final DriverProfileV2 profile;
  final String Function(String) t;
  final bool busy;
  final String? actionError;
  final VoidCallback onCompleteRegistration;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback onRefresh;
  final VoidCallback onGoHome;
  final VoidCallback onGoToDriverDashboard;

  const _StatusCard({
    required this.profile,
    required this.t,
    required this.busy,
    required this.actionError,
    required this.onCompleteRegistration,
    required this.onToggleOnline,
    required this.onRefresh,
    required this.onGoHome,
    required this.onGoToDriverDashboard,
  });

  ({IconData icon, Color color}) get _visual {
    switch (profile.status) {
      case DriverStatus.approved:
        return (icon: Icons.check_circle_outline, color: AppColors.success);
      case DriverStatus.rejected:
      case DriverStatus.suspended:
        return (icon: Icons.error_outline, color: AppColors.error);
      case DriverStatus.documentsRequired:
        return (icon: Icons.description_outlined, color: AppColors.warning);
      case DriverStatus.pendingReview:
        return (icon: Icons.hourglass_top_rounded, color: AppColors.info);
      case DriverStatus.registrationIncomplete:
      case DriverStatus.inactive:
        return (
          icon: Icons.assignment_late_outlined,
          color: AppColors.textSecondary,
        );
    }
  }

  String get _messageKey {
    switch (profile.status) {
      case DriverStatus.registrationIncomplete:
        return 'driver_status_registration_incomplete_message';
      case DriverStatus.pendingReview:
        return 'driver_status_pending_message';
      case DriverStatus.documentsRequired:
        return 'driver_status_documents_required_message';
      case DriverStatus.approved:
        return 'driver_status_approved_message';
      case DriverStatus.rejected:
        return 'driver_status_rejected_message';
      case DriverStatus.suspended:
        return 'driver_status_suspended_message';
      case DriverStatus.inactive:
        return 'driver_status_inactive_message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    final actions = _buildActions(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: v.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(v.icon, color: v.color, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              t(profile.status.key),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: v.color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t(_messageKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (profile.status == DriverStatus.documentsRequired &&
              (profile.documentsRequiredReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(
              label: t('driver_status_reason_label'),
              reason: profile.documentsRequiredReason!,
            ),
          ],
          if (profile.status == DriverStatus.rejected &&
              (profile.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(
              label: t('driver_status_reason_label'),
              reason: profile.rejectionReason!,
            ),
          ],
          if (profile.status == DriverStatus.suspended &&
              (profile.suspensionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(
              label: t('driver_status_reason_label'),
              reason: profile.suspensionReason!,
            ),
          ],
          if (actionError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actionError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 22),
            ...actions,
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    switch (profile.status) {
      case DriverStatus.registrationIncomplete:
        return [
          ElevatedButton(
            onPressed: busy ? null : onCompleteRegistration,
            child: Text(t('driver_status_complete_registration')),
          ),
        ];
      case DriverStatus.pendingReview:
        return [
          OutlinedButton.icon(
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(t('driver_status_refresh')),
          ),
        ];
      case DriverStatus.documentsRequired:
        // La resoumission est volontairement retirée de cette carte : elle
        // vit maintenant dans la carte de remplacement ci-dessous et reste
        // désactivée tant qu'aucun nouveau document n'a été sélectionné.
        return const [];
      case DriverStatus.approved:
        final isOnline = profile.onlineStatus == DriverOnlineStatus.online;
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isOnline ? AppColors.success : AppColors.textSecondary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi_tethering : Icons.wifi_off,
                  color: isOnline ? AppColors.success : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? t('driver_status_online_label')
                        : t('driver_status_offline_label'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: isOnline,
                  onChanged: busy ? null : onToggleOnline,
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy ? null : onGoToDriverDashboard,
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: Text(t('driver_status_go_to_dashboard')),
          ),
        ];
      case DriverStatus.rejected:
        return [
          OutlinedButton(
            onPressed: busy ? null : onGoHome,
            child: Text(t('driver_status_go_home')),
          ),
        ];
      case DriverStatus.suspended:
        return [
          OutlinedButton(
            onPressed: busy ? null : onGoHome,
            child: Text(t('driver_status_go_home')),
          ),
        ];
      case DriverStatus.inactive:
        return [
          OutlinedButton(
            onPressed: busy ? null : onGoHome,
            child: Text(t('driver_status_go_home')),
          ),
        ];
    }
  }
}

class _ReasonBox extends StatelessWidget {
  final String label;
  final String reason;
  const _ReasonBox({required this.label, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(reason, style: const TextStyle(fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
