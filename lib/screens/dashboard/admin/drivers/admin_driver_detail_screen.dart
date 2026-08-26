// ---------------------------------------------------------------------------
// AdminDriverDetailScreen — Phase 2, fiche analyste d'un dossier chauffeur.
//
// Affiche Profil + Véhicule + Documents + Notes internes, et expose les
// actions Approuver / Refuser / Demander un document / Suspendre / Réactiver
// / Ajouter une note — TOUTES via Cloud Functions (DriverRepository), jamais
// d'écriture Firestore directe depuis cet écran.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/app_user_v2.dart';
import '../../../../backend/models/driver_document.dart';
import '../../../../backend/models/driver_internal_note.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../backend/models/driver_vehicle.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../finance/presentation/money_format.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

class AdminDriverDetailScreen extends StatefulWidget {
  final String driverId;
  const AdminDriverDetailScreen({super.key, required this.driverId});

  @override
  State<AdminDriverDetailScreen> createState() => _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends State<AdminDriverDetailScreen> {
  bool _actionInProgress = false;

  // Bloc M (gap performance, même classe de bug que Bloc C item 3) : le
  // StreamBuilder sur `watchDriverProfile()` était instancié directement
  // dans `build()`. Chaque action admin (Approuver/Refuser/Suspendre/
  // Réactiver/Demander documents) déclenche un `setState()` via
  // `onBusyChanged`, recréant le Stream (flicker + re-souscription
  // Firestore). `widget.driverId` est stable pour la durée de vie de cet
  // écran, donc le Stream n'a besoin d'être créé qu'une seule fois — pas
  // de mémoïsation conditionnelle par id nécessaire ici (contrairement aux
  // shells où le driverId peut changer), un simple champ `late final`
  // suffit et documente clairement l'intention.
  late final Stream<DriverProfileV2?> _driverProfileStream =
      BackendLocator.driverRepository.watchDriverProfile(widget.driverId);

  @override
  void initState() {
    super.initState();
    // Point 12 — traçabilité : journalise l'ouverture du dossier (audit_logs
    // action driver_review_opened), sans bloquer l'affichage sur le résultat.
    BackendLocator.driverRepository.logDriverReviewOpened(widget.driverId).catchError((_) {
      // Non bloquant : un échec de journalisation ne doit jamais empêcher
      // l'analyste de consulter le dossier.
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;

    return Scaffold(
      appBar: AppBar(title: Text(t('admin_driver_detail_title'))),
      body: StreamBuilder<DriverProfileV2?>(
        stream: _driverProfileStream,
        builder: (context, profileSnap) {
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnap.hasError) {
            return Center(child: Text(t('admin_drivers_error')));
          }
          final profile = profileSnap.data;
          if (profile == null) {
            return Center(child: Text(t('common_empty')));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBanner(profile: profile, t: t),
                const SizedBox(height: 20),
                _ProfileSection(driverId: widget.driverId, profile: profile, t: t),
                const SizedBox(height: 20),
                _VehicleSection(driverId: widget.driverId, t: t),
                const SizedBox(height: 20),
                _DocumentsSection(driverId: widget.driverId, t: t),
                const SizedBox(height: 20),
                _NotesSection(driverId: widget.driverId, t: t),
                const SizedBox(height: 24),
                _ActionsBar(
                  profile: profile,
                  busy: _actionInProgress,
                  onBusyChanged: (v) => setState(() => _actionInProgress = v),
                  t: t,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final DriverProfileV2 profile;
  final String Function(String) t;
  const _StatusBanner({required this.profile, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${profile.fullName} — ${t(profile.status.key)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatefulWidget {
  final String driverId;
  final DriverProfileV2 profile;
  final String Function(String) t;
  const _ProfileSection({required this.driverId, required this.profile, required this.t});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  // Bloc M (gap performance) : ce widget est recréé à chaque rebuild du
  // parent (ex : toggle `_actionInProgress` sur une action admin sans
  // rapport avec ce champ), et un `FutureBuilder` dont `future:` est
  // construit en `build()` relance systématiquement une LECTURE FIRESTORE
  // (`users/{driverId}.get()`) à chaque reconstruction — coûteux et
  // inutile puisque `driverId` ne change jamais pour cet écran. Le Future
  // est désormais capturé une seule fois dans `initState()`.
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture =
      FirebaseFirestore.instance.collection('users').doc(widget.driverId).get();

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final profile = widget.profile;
    final driverId = widget.driverId;
    final na = t('admin_driver_field_not_available');
    final nameParts = profile.fullName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    return _SectionCard(
      title: t('admin_driver_section_profile'),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userFuture,
        builder: (context, snap) {
          AppUserV2? user;
          if (snap.hasData && snap.data!.exists) {
            user = AppUserV2.fromJson(driverId, snap.data!.data()!);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow(label: t('admin_driver_field_first_name'), value: firstName.isEmpty ? na : firstName),
              _KeyValueRow(label: t('admin_driver_field_last_name'), value: lastName.isEmpty ? na : lastName),
              _KeyValueRow(label: t('admin_driver_field_phone'), value: user?.phone ?? na),
              _KeyValueRow(label: t('admin_driver_field_email'), value: user?.email ?? na),
              // Champs non capturés par le modèle actuel (AppUserV2/
              // DriverProfileV2 n'ont ni adresse, ni province, ni code
              // postal) — voir note d'audit dans app_user_v2.dart : gap
              // documenté, affichage explicite "non renseigné" plutôt que
              // de supposer une valeur.
              _KeyValueRow(label: t('admin_driver_field_address'), value: na),
              _KeyValueRow(label: t('admin_driver_field_city'), value: profile.city.isEmpty ? na : profile.city),
              _KeyValueRow(label: t('admin_driver_field_province'), value: na),
              _KeyValueRow(label: t('admin_driver_field_postal_code'), value: na),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleSection extends StatefulWidget {
  final String driverId;
  final String Function(String) t;
  const _VehicleSection({required this.driverId, required this.t});

  @override
  State<_VehicleSection> createState() => _VehicleSectionState();
}

class _VehicleSectionState extends State<_VehicleSection> {
  // Bloc M (gap performance) : même correctif que _ProfileSection — évite
  // de relancer `getDriverVehicles()` (lecture Firestore) à chaque rebuild
  // du parent déclenché par une action admin sans rapport (toggle busy).
  late final Future<List<DriverVehicle>> _vehiclesFuture =
      BackendLocator.driverRepository.getDriverVehicles(widget.driverId);

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final na = t('admin_driver_field_not_available');
    return _SectionCard(
      title: t('admin_driver_section_vehicle'),
      child: FutureBuilder<List<DriverVehicle>>(
        future: _vehiclesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          final vehicles = snap.data ?? const <DriverVehicle>[];
          if (vehicles.isEmpty) {
            return Text(na, style: const TextStyle(color: AppColors.textSecondary));
          }
          final v = vehicles.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow(label: t('admin_driver_field_category'), value: t(v.category.key)),
              _KeyValueRow(label: t('admin_driver_field_make'), value: v.displayMake.isEmpty ? na : v.displayMake),
              _KeyValueRow(label: t('admin_driver_field_model'), value: v.displayModel.isEmpty ? na : v.displayModel),
              _KeyValueRow(label: t('admin_driver_field_year'), value: v.year == 0 ? na : '${v.year}'),
              _KeyValueRow(label: t('admin_driver_field_color'), value: v.color ?? na),
              _KeyValueRow(label: t('admin_driver_field_plate'), value: v.plate.isEmpty ? na : v.plate),
              _KeyValueRow(
                label: t('admin_driver_field_capacity'),
                value: v.maxPayloadKg != null ? '${v.maxPayloadKg} kg' : na,
              ),
              _KeyValueRow(
                label: t('admin_driver_field_vehicle_verified'),
                value: v.isVerified ? t('admin_driver_verified') : t('admin_driver_not_verified'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final String driverId;
  final String Function(String) t;
  const _DocumentsSection({required this.driverId, required this.t});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: t('admin_driver_section_documents'),
      child: StreamBuilder<List<DriverDocument>>(
        stream: BackendLocator.driverRepository.watchDriverDocuments(driverId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          final docs = snap.data ?? const <DriverDocument>[];
          if (docs.isEmpty) {
            return Text(t('admin_driver_doc_no_documents'),
                style: const TextStyle(color: AppColors.textSecondary));
          }
          return Column(
            children: docs.map((doc) => _DocumentTile(doc: doc, t: t)).toList(),
          );
        },
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DriverDocument doc;
  final String Function(String) t;
  const _DocumentTile({required this.doc, required this.t});

  Color get _statusColor {
    switch (doc.status) {
      case DriverDocumentStatus.approved:
        return AppColors.success;
      case DriverDocumentStatus.rejected:
      case DriverDocumentStatus.expired:
      case DriverDocumentStatus.replacementRequired:
        return AppColors.error;
      case DriverDocumentStatus.pendingReview:
      case DriverDocumentStatus.uploaded:
        return AppColors.warning;
      case DriverDocumentStatus.missing:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t(doc.type.key), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t(doc.status.key),
                    style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // Bloc K2 (K2-2) : plus de Timestamp/DateTime brut visible
            // (ex: "2026-08-26 12:24:28.123456") — formatage localisé via
            // `formatDisplayDate` (déjà utilisé ailleurs pour la finance),
            // cohérent avec le reste de l'app.
            '${t('admin_driver_doc_uploaded_at')}: ${formatDisplayDate(doc.uploadedAt, connector: t('datetime_connector_at'))}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          if (doc.expiresAt != null)
            Text(
              '${t('admin_driver_doc_expires_at')}: ${formatDisplayDate(doc.expiresAt!, connector: t('datetime_connector_at'))}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          if (doc.rejectionReason != null && doc.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${t('admin_driver_doc_comment')}: ${doc.rejectionReason}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: doc.storageBucketPath.isEmpty
                  ? null
                  : () {
                      // L'aperçu réel nécessite une URL signée générée à la
                      // demande (Firebase Storage) — non implémenté dans ce
                      // repository (hors périmètre Phase 2 : ce bouton est
                      // prêt à être branché sur getDownloadURL() côté
                      // Storage une fois cette intégration ajoutée).
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('admin_driver_doc_view'))),
                      );
                    },
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text(t('admin_driver_doc_view'), style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatefulWidget {
  final String driverId;
  final String Function(String) t;
  const _NotesSection({required this.driverId, required this.t});

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  final _controller = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await BackendLocator.driverRepository.addDriverInternalNote(widget.driverId, text);
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.t('admin_action_success_note'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.t('admin_action_error'))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _SectionCard(
      title: t('admin_driver_section_notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<DriverInternalNote>>(
            stream: BackendLocator.driverRepository.watchDriverInternalNotes(widget.driverId),
            builder: (context, snap) {
              final notes = [...(snap.data ?? const <DriverInternalNote>[])]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (notes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(t('admin_note_empty'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                );
              }
              return Column(
                children: notes
                    .map((n) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.text, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '${n.authorRole} • ${n.createdAt.toLocal()}'.split('.').first,
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: t('admin_note_hint')),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(t('admin_action_add_note')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsBar extends StatelessWidget {
  final DriverProfileV2 profile;
  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  final String Function(String) t;
  const _ActionsBar({
    required this.profile,
    required this.busy,
    required this.onBusyChanged,
    required this.t,
  });

  Future<void> _run(BuildContext context, Future<void> Function() action, String successKey) async {
    onBusyChanged(true);
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(successKey))));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('admin_action_error'))));
    } finally {
      onBusyChanged(false);
    }
  }

  Future<String?> _promptReason(BuildContext context, String labelKey, String hintKey) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(labelKey)),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: t(hintKey)),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 3) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(t('admin_reason_required_error'))),
                );
                return;
              }
              Navigator.of(dialogContext).pop(text);
            },
            child: Text(t('common_confirm')),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmApprove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('admin_confirm_approve_title')),
        content: Text(t('admin_confirm_approve_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('admin_action_approve')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final repo = BackendLocator.driverRepository;
    final auth = context.watch<FirebaseAuthProvider>();
    final canApproveReject = profile.status != DriverStatus.approved;
    // Suspendre/réactiver un chauffeur est délibérément réservé à
    // admin/super_admin côté serveur (voir suspendDriver.ts/
    // reactivateDriver.ts — requireAdminOrAbove). L'UI masque ces actions
    // à un analyste simple pour éviter un appel Cloud Function voué à un
    // refus PERMISSION_DENIED, mais la vraie protection reste côté serveur.
    final canSuspendReactivate = auth.isAdminOrAbove;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (canApproveReject)
          ElevatedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final ok = await _confirmApprove(context);
                    if (!ok || !context.mounted) return;
                    await _run(
                      context,
                      () => repo.approveDriver(profile.uid),
                      'admin_action_success_approve',
                    );
                  },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(t('admin_action_approve')),
          ),
        if (profile.status != DriverStatus.rejected)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final reason = await _promptReason(
                      context,
                      'admin_reason_reject_label',
                      'admin_reason_reject_hint',
                    );
                    if (reason == null || !context.mounted) return;
                    await _run(
                      context,
                      () => repo.rejectDriver(profile.uid, reason),
                      'admin_action_success_reject',
                    );
                  },
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(t('admin_action_reject')),
          ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final reason = await _promptReason(
                    context,
                    'admin_reason_request_documents_label',
                    'admin_reason_request_documents_hint',
                  );
                  if (reason == null || !context.mounted) return;
                  await _run(
                    context,
                    () => repo.requestDriverDocuments(profile.uid, reason),
                    'admin_action_success_request_documents',
                  );
                },
          icon: const Icon(Icons.description_outlined, size: 18),
          label: Text(t('admin_action_request_documents')),
        ),
        if (profile.status == DriverStatus.approved && canSuspendReactivate)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final reason = await _promptReason(
                      context,
                      'admin_reason_suspend_label',
                      'admin_reason_suspend_label',
                    );
                    if (reason == null || !context.mounted) return;
                    await _run(
                      context,
                      () => repo.suspendDriver(profile.uid, reason),
                      'admin_action_success_suspend',
                    );
                  },
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.block_outlined, size: 18),
            label: Text(t('admin_action_suspend')),
          ),
        if (profile.status == DriverStatus.suspended && canSuspendReactivate)
          ElevatedButton.icon(
            onPressed: busy
                ? null
                : () => _run(
                      context,
                      () => repo.reactivateDriver(profile.uid),
                      'admin_action_success_reactivate',
                    ),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(t('admin_action_reactivate')),
          ),
      ],
    );
  }
}
