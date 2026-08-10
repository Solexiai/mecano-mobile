// ---------------------------------------------------------------------------
// AuditLog (Firestore-ready) — collection `audit_logs/{id}`.
//
// Trace immuable de toute action administrative/sensible : approbation
// chauffeur, changement de commission, changement de statut Founding
// Driver, remboursement, correction de ledger, etc. Écrit exclusivement par
// les Cloud Functions ; jamais modifiable après création.
// ---------------------------------------------------------------------------

class AuditLog {
  final String id;
  final String actorUserId;
  final String actorRole;
  final String action; // ex: 'approveDriver', 'updatePricingConfiguration'
  final String? targetId; // ex: driverId concerné
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.actorUserId,
    required this.actorRole,
    required this.action,
    this.targetId,
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actor_user_id': actorUserId,
        'actor_role': actorRole,
        'action': action,
        'target_id': targetId,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  factory AuditLog.fromJson(String id, Map<String, dynamic> json) {
    return AuditLog(
      id: id,
      actorUserId: json['actor_user_id'] as String? ?? '',
      actorRole: json['actor_role'] as String? ?? '',
      action: json['action'] as String? ?? '',
      targetId: json['target_id'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
