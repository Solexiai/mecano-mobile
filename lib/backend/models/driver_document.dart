// ---------------------------------------------------------------------------
// DriverDocument (Firestore-ready) — collection `driver_documents/{id}`.
//
// Métadonnées d'un document téléversé par un chauffeur dans Firebase
// Storage. Le fichier lui-même vit dans Storage (`storageBucketPath`) ;
// ce document Firestore ne contient que les métadonnées et le statut de
// validation. `status` ne doit être modifié que par un analyste/admin via
// une opération serveur protégée (jamais par le chauffeur lui-même après
// upload initial).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class DriverDocument {
  final String id;
  final String driverId;
  final DriverDocumentType type;
  final DriverDocumentStatus status;

  /// Chemin dans Firebase Storage (ex: 'driver_documents/{uid}/licence.jpg').
  /// Ne jamais stocker d'URL publique permanente ici — utiliser des URLs
  /// signées à courte durée de vie générées à la demande.
  final String storageBucketPath;

  final DateTime uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewedByUserId;
  final String? rejectionReason;
  final DateTime? expiresAt; // pour permis/assurance ayant une date d'expiration

  const DriverDocument({
    required this.id,
    required this.driverId,
    required this.type,
    required this.status,
    required this.storageBucketPath,
    required this.uploadedAt,
    this.reviewedAt,
    this.reviewedByUserId,
    this.rejectionReason,
    this.expiresAt,
  });

  bool get isApproved => status == DriverDocumentStatus.approved;
  bool get needsAction =>
      status == DriverDocumentStatus.missing ||
      status == DriverDocumentStatus.rejected ||
      status == DriverDocumentStatus.replacementRequired ||
      status == DriverDocumentStatus.expired;

  Map<String, dynamic> toJson() => {
        'id': id,
        'driver_id': driverId,
        'type': type.firestoreValue,
        'status': status.firestoreValue,
        'storage_bucket_path': storageBucketPath,
        'uploaded_at': uploadedAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by_user_id': reviewedByUserId,
        'rejection_reason': rejectionReason,
        'expires_at': expiresAt?.toIso8601String(),
      };

  factory DriverDocument.fromJson(String id, Map<String, dynamic> json) {
    return DriverDocument(
      id: id,
      driverId: json['driver_id'] as String,
      type: DriverDocumentTypeX.fromFirestoreValue(json['type'] as String?),
      status: DriverDocumentStatusX.fromFirestoreValue(json['status'] as String?),
      storageBucketPath: json['storage_bucket_path'] as String? ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
      reviewedAt:
          json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
      reviewedByUserId: json['reviewed_by_user_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
    );
  }
}
