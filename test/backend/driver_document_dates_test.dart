// 2026-11-03 — régression « Aucun document téléversé » dans Admin › Chauffeurs.
// Le serveur (validateDriverDocument) écrit `reviewed_at` en Timestamp
// Firestore ; le modèle attendait une chaîne ISO et plantait au premier
// document approuvé, ce qui vidait toute la liste.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/app_user_v2.dart';
import 'package:movik_connect/backend/models/audit_log.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/models/enums.dart';

void main() {
  final reviewed = DateTime.utc(2026, 11, 3, 17, 40);

  test('DriverDocument.fromJson accepte les dates serveur (Timestamp)', () {
    final doc = DriverDocument.fromJson('doc-1', {
      'driver_id': 'driver-1',
      'type': 'insurance',
      'status': 'approved',
      'storage_bucket_path': 'driver_documents/driver-1/insurance_1.jpg',
      'uploaded_at': '2026-11-03T12:33:22.126',
      'reviewed_at': Timestamp.fromDate(reviewed),
      'reviewed_by_user_id': 'admin-1',
      'expires_at': Timestamp.fromDate(DateTime.utc(2027, 11, 3)),
    });
    expect(doc.status, DriverDocumentStatus.approved);
    expect(doc.uploadedAt, DateTime.parse('2026-11-03T12:33:22.126'));
    expect(doc.reviewedAt, reviewed);
    expect(doc.expiresAt, DateTime.utc(2027, 11, 3));
  });

  test('DriverDocument.fromJson accepte toujours les dates en chaîne ISO', () {
    final doc = DriverDocument.fromJson('doc-2', {
      'driver_id': 'driver-1',
      'type': 'identity',
      'status': 'uploaded',
      'storage_bucket_path': 'driver_documents/driver-1/identity_1.jpg',
      'uploaded_at': '2026-11-03T12:33:24.371',
      'reviewed_at': null,
    });
    expect(doc.reviewedAt, isNull);
    expect(doc.expiresAt, isNull);
    expect(doc.uploadedAt.year, 2026);
  });

  test('AuditLog et AppUserV2 acceptent created_at en Timestamp', () {
    final log = AuditLog.fromJson('log-1', {
      'actor_user_id': 'admin-1',
      'actor_role': 'admin',
      'action': 'approveDriver',
      'created_at': Timestamp.fromDate(reviewed),
    });
    expect(log.createdAt, reviewed);
    final user = AppUserV2.fromJson('u-1', {
      'email': 'x@example.com',
      'full_name': 'X',
      'roles': ['driver'],
      'created_at': Timestamp.fromDate(reviewed),
    });
    expect(user.createdAt, reviewed);
  });
}
