import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

bool canReviewMissionFailure(DeliveryMission mission) =>
    !mission.isInternalTest &&
    mission.driverId != null &&
    mission.completedAt == null &&
    mission.proofOfDeliveryUrl == null &&
    const {
      MissionStatus.assigned,
      MissionStatus.driverToPickup,
      MissionStatus.arrivedAtPickup,
      MissionStatus.pickedUp,
      MissionStatus.inTransit,
      MissionStatus.arrivedAtDropoff,
      MissionStatus.disputed,
      MissionStatus.refunded,
    }.contains(mission.status);

String _copy(String locale, String fr, String en, String es) =>
    switch (locale) {
      'fr' => fr,
      'es' => es,
      _ => en,
    };

class AdminMissionFailureReview extends StatefulWidget {
  const AdminMissionFailureReview({
    super.key,
    required this.mission,
    this.reviewStream,
    this.submit,
  });
  final DeliveryMission mission;
  final Stream<Map<String, dynamic>>? reviewStream;
  final Future<void> Function(Map<String, dynamic>)? submit;
  @override
  State<AdminMissionFailureReview> createState() =>
      _AdminMissionFailureReviewState();
}

class _AdminMissionFailureReviewState extends State<AdminMissionFailureReview> {
  late Stream<Map<String, dynamic>> _stream;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _stream =
        widget.reviewStream ??
        FirebaseFirestore.instance
            .collection('mission_outcome_reviews')
            .doc(widget.mission.id)
            .snapshots(includeMetadataChanges: true)
            .map(
              (snap) => {
                ...?(snap.data()),
                '_fromCache': snap.metadata.isFromCache,
              },
            );
  }

  @override
  void didUpdateWidget(covariant AdminMissionFailureReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mission.id != widget.mission.id ||
        oldWidget.reviewStream != widget.reviewStream) {
      _listen();
    }
  }

  Future<void> _review(String action, int revision, String locale) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => MissionFailureReviewDialog(
        locale: locale,
        revoke: action == 'revoke',
      ),
    );
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'missionId': widget.mission.id,
        'action': action,
        'reason': reason,
        'expectedStatus': widget.mission.status.firestoreValue,
        'expectedRevision': revision,
        'expectedDriverId': widget.mission.driverId,
        'deliveryNotCompleted': action == 'confirm',
      };
      if (widget.submit != null) {
        await widget.submit!(payload);
      } else {
        await FirebaseFunctions.instance
            .httpsCallable('reviewMissionFailure')
            .call(payload);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _copy(
            locale,
            'Impossible de confirmer l’enregistrement. Actualisez la mission avant de réessayer.',
            'Unable to confirm the save. Refresh the job before retrying.',
            'No se puede confirmar el registro. Actualice el servicio antes de reintentar.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final canEdit = context.watch<FirebaseAuthProvider>().isAdminOrAbove;
    String c(String fr, String en, String es) => _copy(locale, fr, en, es);
    return StreamBuilder<Map<String, dynamic>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            c(
              'Constat administratif indisponible.',
              'Administrative finding unavailable.',
              'Resultado administrativo no disponible.',
            ),
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final data = snapshot.data!;
        final confirmed = data['confirmed'] == true;
        final fresh = data['_fromCache'] != true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              confirmed
                  ? c(
                      'Échec de livraison confirmé par l’administration',
                      'Delivery failure confirmed by administration',
                      'Fallo de entrega confirmado por administración',
                    )
                  : c(
                      'Aucun échec confirmé',
                      'No confirmed failure',
                      'Ningún fallo confirmado',
                    ),
            ),
            if (confirmed) Text(data['reason'] as String? ?? ''),
            if (confirmed && !canReviewMissionFailure(widget.mission))
              Text(
                c(
                  'Le statut actuel exclut ce constat du compteur des échecs.',
                  'The current status excludes this finding from the failure count.',
                  'El estado actual excluye este resultado del contador de fallos.',
                ),
              ),
            Text(
              c(
                'Ce constat n’attribue aucune faute au chauffeur. Il ne clôture pas la mission et ne modifie aucun paiement.',
                'This finding does not assign blame to the driver. It does not close the job or change any payment.',
                'Este resultado no atribuye culpa al conductor. No cierra el servicio ni modifica ningún pago.',
              ),
            ),
            if (!fresh)
              Text(
                c(
                  'Connexion nécessaire pour modifier le constat.',
                  'Connection required to change the finding.',
                  'Conexión necesaria para modificar el resultado.',
                ),
              ),
            if (_error != null) Text(_error!),
            if (canEdit &&
                (confirmed || canReviewMissionFailure(widget.mission)))
              OutlinedButton.icon(
                onPressed: _busy || !fresh
                    ? null
                    : () => _review(
                        confirmed ? 'revoke' : 'confirm',
                        (data['revision'] as num?)?.toInt() ?? 0,
                        locale,
                      ),
                icon: Icon(confirmed ? Icons.undo : Icons.fact_check_outlined),
                label: Text(
                  confirmed
                      ? c(
                          'Retirer ce constat',
                          'Revoke this finding',
                          'Retirar este resultado',
                        )
                      : c(
                          'Confirmer une livraison non réalisée',
                          'Confirm an uncompleted delivery',
                          'Confirmar una entrega no realizada',
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MissionFailureReviewDialog extends StatefulWidget {
  const MissionFailureReviewDialog({
    super.key,
    required this.locale,
    this.revoke = false,
  });
  final String locale;
  final bool revoke;
  @override
  State<MissionFailureReviewDialog> createState() =>
      _MissionFailureReviewDialogState();
}

class _MissionFailureReviewDialogState
    extends State<MissionFailureReviewDialog> {
  final _reason = TextEditingController();
  bool _attested = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String c(String fr, String en, String es) =>
        _copy(widget.locale, fr, en, es);
    final valid =
        _reason.text.trim().length >= 3 && (widget.revoke || _attested);
    return AlertDialog(
      title: Text(
        widget.revoke
            ? c(
                'Corriger le constat',
                'Correct the finding',
                'Corregir el resultado',
              )
            : c(
                'Confirmer l’échec de livraison',
                'Confirm delivery failure',
                'Confirmar el fallo de entrega',
              ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c(
                'Constat administratif uniquement : aucune sanction, annulation ou opération financière automatique.',
                'Administrative finding only: no automatic sanction, cancellation or financial operation.',
                'Resultado administrativo únicamente: sin sanción, cancelación ni operación financiera automática.',
              ),
            ),
            if (!widget.revoke)
              CheckboxListTile(
                value: _attested,
                onChanged: (value) => setState(() => _attested = value == true),
                title: Text(
                  c(
                    'Après vérification, je confirme que la livraison n’a pas été réalisée.',
                    'After verification, I confirm that the delivery was not completed.',
                    'Tras verificar, confirmo que la entrega no se realizó.',
                  ),
                ),
              ),
            TextField(
              key: const Key('failure-review-reason'),
              controller: _reason,
              maxLength: 2000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: c(
                  'Motif obligatoire',
                  'Required reason',
                  'Motivo obligatorio',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(c('Annuler', 'Cancel', 'Cancelar')),
        ),
        FilledButton(
          key: const Key('failure-review-submit'),
          onPressed: valid
              ? () => Navigator.pop(context, _reason.text.trim())
              : null,
          child: Text(
            c('Enregistrer le constat', 'Save finding', 'Guardar resultado'),
          ),
        ),
      ],
    );
  }
}
