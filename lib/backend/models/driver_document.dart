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
import 'firestore_date.dart';

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
      // 2026-11-03 : le serveur (validateDriverDocument, detectExpiringDocuments)
      // écrit ces dates en Timestamp Firestore, l'app en chaîne ISO. Les deux
      // formes sont acceptées, sinon le premier document approuvé faisait
      // planter toute la liste des documents de l'écran admin.
      uploadedAt: parseFirestoreDate(json['uploaded_at']) ?? DateTime.now(),
      reviewedAt: parseFirestoreDate(json['reviewed_at']),
      reviewedByUserId: json['reviewed_by_user_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: parseFirestoreDate(json['expires_at']),
    );
  }
}
