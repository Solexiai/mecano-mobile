import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../backend/models/delivery_mission.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';

Future<void> showAdminMissionAssignmentDialog(
  BuildContext context, {
  required DeliveryMission mission,
  required bool isFrench,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AssignmentDialog(mission: mission, isFrench: isFrench),
);

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.mission, required this.isFrench});
  final DeliveryMission mission;
  final bool isFrench;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  String? _assigningDriverId;
  bool _internalTest = false;
  bool _isSuperAdmin = false;
  bool _loadingAccess = true;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final claims =
          (await FirebaseAuth.instance.currentUser?.getIdTokenResult(true)).claims;
      final rawRoles = claims?['roles'];
      final roles = rawRoles is Iterable
          ? rawRoles.map((role) => role.toString()).toSet()
          : <String>{};
      final superAdmin =
          roles.contains('super_admin') ||
          claims?['role']?.toString() == 'super_admin';
      if (!mounted) return;
      setState(() {
        _isSuperAdmin = superAdmin;
        _internalTest = superAdmin;
        _loadingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _internalTest = false;
        _loadingAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isFrench ? 'Assigner un chauffeur' : 'Assign a driver'),
    content: SizedBox(
      width: 560,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('driver_profiles')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              widget.isFrench
                  ? 'Impossible de charger les chauffeurs.'
                  : 'Unable to load drivers.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final drivers =
              snapshot.data!.docs
                  .map((d) => DriverProfileV2.fromJson(d.id, d.data()))
                  .where(_isEligible)
                  .toList()
                ..sort((a, b) => a.fullName.compareTo(b.fullName));
          if (drivers.isEmpty) {
            return Text(
              widget.isFrench
                  ? 'Aucun chauffeur approuvé, disponible et compatible.'
                  : 'No approved, available and compatible driver.',
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              if (_loadingAccess) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 14),
              ],
              if (_isSuperAdmin) ...[
                _modeSelector(),
                const SizedBox(height: 14),
              ],
              Text(
                widget.isFrench
                    ? 'Chauffeurs compatibles avec le véhicule demandé :'
                    : 'Drivers compatible with the requested vehicle:',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              ...drivers.map(_driverTile),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _assigningDriverId == null
            ? () => Navigator.pop(context)
            : null,
        child: Text(widget.isFrench ? 'Annuler' : 'Cancel'),
      ),
    ],
  );

  Widget _modeSelector() => Container(
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: AppColors.warning.withValues(alpha: 0.45),
      ),
    ),
    child: SwitchListTile.adaptive(
      value: _internalTest,
      onChanged: _assigningDriverId == null
          ? (value) => setState(() => _internalTest = value)
          : null,
      secondary: const Icon(
        Icons.science_outlined,
        color: AppColors.warningText,
      ),
      title: Text(
        widget.isFrench
            ? 'Mode test interne'
            : 'Internal test mode',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        widget.isFrench
            ? 'Aucun paiement, revenu ou versement réel.'
            : 'No real payment, revenue or driver payout.',
      ),
    ),
  );

  bool _isEligible(DriverProfileV2 driver) =>
      driver.status == DriverStatus.approved &&
      driver.documentsAllValid &&
      driver.onlineStatus != DriverOnlineStatus.onMission &&
      driver.acceptedVehicleCategories.contains(
        widget.mission.requiredVehicleCategory,
      );

  Widget _driverTile(DriverProfileV2 driver) {
    final busy = _assigningDriverId == driver.uid;
    final place = [
      driver.city,
      driver.baseRegion,
    ].where((v) => v.trim().isNotEmpty).toSet().join(' • ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
        title: Text(driver.fullName.isEmpty ? driver.uid : driver.fullName),
        subtitle: Text(
          place.isEmpty
              ? (widget.isFrench
                    ? 'Région non indiquée'
                    : 'Region not provided')
              : place,
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton(
                onPressed: _assigningDriverId == null && !_loadingAccess
                    ? () => _confirmAndAssign(driver)
                    : null,
                child: Text(
                  _internalTest
                      ? (widget.isFrench ? 'Tester' : 'Test')
                      : (widget.isFrench ? 'Assigner' : 'Assign'),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmAndAssign(DriverProfileV2 driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.isFrench ? 'Confirmer l’attribution' : 'Confirm assignment',
        ),
        content: Text(
          _internalTest
              ? (widget.isFrench
                    ? 'Assigner cette mission à ${driver.fullName} en mode test interne? '
                          'Aucun paiement, revenu ou versement réel ne sera créé.'
                    : 'Assign this job to ${driver.fullName} in internal test mode? '
                          'No real payment, revenue or payout will be created.')
              : (widget.isFrench
                    ? 'Assigner cette mission à ${driver.fullName}? '
                          'Le paiement réel sera autorisé comme lors d’une acceptation normale.'
                    : 'Assign this job to ${driver.fullName}? '
                          'A real payment will be authorized as with a normal acceptance.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(widget.isFrench ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(widget.isFrench ? 'Confirmer' : 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _assigningDriverId = driver.uid);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminAssignDelivery')
          .call({
            'missionId': widget.mission.id,
            'driverId': driver.uid,
            'assignmentMode': _internalTest ? 'internal_test' : 'standard',
          });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _internalTest
                ? (widget.isFrench
                      ? 'Test interne assigné à ${driver.fullName}. Aucun paiement réel.'
                      : 'Internal test assigned to ${driver.fullName}. No real payment.')
                : (widget.isFrench
                      ? 'Mission réelle assignée à ${driver.fullName}.'
                      : 'Real job assigned to ${driver.fullName}.'),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _assigningDriverId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                (widget.isFrench
                    ? 'Attribution impossible.'
                    : 'Unable to assign the job.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _assigningDriverId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isFrench
                ? 'Attribution impossible.'
                : 'Unable to assign the job.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
