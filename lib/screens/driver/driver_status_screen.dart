// ---------------------------------------------------------------------------
// DriverStatusScreen — vue RÉACTIVE du statut de dossier chauffeur.
//
// Point d'entrée post-onboarding (et de retour) pour un chauffeur
// Firebase Auth connecté. Couvre les 6 statuts minimum requis :
// registration_incomplete, pending_review, documents_required, approved,
// rejected, suspended (+ inactive, valeur d'enum existante mais hors
// périmètre workflow normal).
//
// RÈGLES RESPECTÉES :
// - AUCUN faux succès : chaque statut affiche un message et un CTA propres
//   à son état réel, jamais un état générique optimiste.
// - `approved` NE fait JAMAIS passer le chauffeur `online` automatiquement
//   — un bouton explicite (`setDriverOnlineStatus`) laisse le chauffeur
//   décider, conformément au point 3 du cahier des charges Phase 2.
// - `documents_required` affiche le motif fourni par l'analyste
//   (`documentsRequiredReason`) et propose de re-soumettre le dossier
//   (`submitForReview`, transition documents_required -> pending_review
//   déjà gérée côté serveur par submitDriverForReview.ts).
// - `suspended` bloque toute action de mise en ligne (pas de bouton
//   "online").
// - Lecture 100% temps réel via `watchDriverProfile(uid)` (StreamBuilder),
//   avec états loading/error/empty explicites.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';

class DriverStatusScreen extends StatefulWidget {
  final String locale;
  const DriverStatusScreen({super.key, required this.locale});

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  bool _actionInProgress = false;
  String? _actionError;

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
            constraints: const BoxConstraints(maxWidth: 560),
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
      // Pas de session : rediriger discrètement vers la connexion plutôt
      // que d'afficher un état vide trompeur.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/${widget.locale}/connexion');
      });
      return const Center(child: CircularProgressIndicator());
    }

    final uid = auth.effectiveUid!;
    final repo = BackendLocator.driverRepository;

    return StreamBuilder<DriverProfileV2?>(
      stream: repo.watchDriverProfile(uid),
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
            onRetry: () => context.go('/${widget.locale}/devenir-chauffeur/inscription'),
            retryLabel: t('driver_status_complete_registration'),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onResubmit: () => _runAction(
                () => repo.submitForReview(),
              ),
              onToggleOnline: (goOnline) => _runAction(
                () => repo.setDriverOnlineStatus(uid, goOnline),
              ),
              onRefresh: () => setState(() {}),
              onGoHome: () => context.go('/${widget.locale}'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }
}

class _StatusCard extends StatelessWidget {
  final DriverProfileV2 profile;
  final String Function(String) t;
  final bool busy;
  final String? actionError;
  final VoidCallback onCompleteRegistration;
  final VoidCallback onResubmit;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback onRefresh;
  final VoidCallback onGoHome;

  const _StatusCard({
    required this.profile,
    required this.t,
    required this.busy,
    required this.actionError,
    required this.onCompleteRegistration,
    required this.onResubmit,
    required this.onToggleOnline,
    required this.onRefresh,
    required this.onGoHome,
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
        return (icon: Icons.assignment_late_outlined, color: AppColors.textSecondary);
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
              decoration: BoxDecoration(color: v.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(v.icon, color: v.color, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              t(profile.status.key),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: v.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t(_messageKey),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),

          // Motif — affiché uniquement quand un motif réel existe côté
          // serveur (documents_required / rejected / suspended).
          if (profile.status == DriverStatus.documentsRequired &&
              (profile.documentsRequiredReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(label: t('driver_status_reason_label'), reason: profile.documentsRequiredReason!),
          ],
          if (profile.status == DriverStatus.rejected &&
              (profile.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(label: t('driver_status_reason_label'), reason: profile.rejectionReason!),
          ],
          if (profile.status == DriverStatus.suspended &&
              (profile.suspensionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _ReasonBox(label: t('driver_status_reason_label'), reason: profile.suspensionReason!),
          ],

          if (actionError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t('admin_action_error'),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 22),
          ..._buildActions(context),
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
        return [
          ElevatedButton.icon(
            onPressed: busy ? null : onResubmit,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_outlined, size: 18),
            label: Text(t('driver_status_resubmit')),
          ),
        ];

      case DriverStatus.approved:
        final isOnline = profile.onlineStatus == DriverOnlineStatus.online;
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isOnline ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.08),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
  const _ErrorCard({required this.message, required this.onRetry, required this.retryLabel});

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
