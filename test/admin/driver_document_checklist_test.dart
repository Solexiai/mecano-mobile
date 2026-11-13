// Fiche chauffeur › Documents : une place par document, ajout par un agent
// d'un document reçu par courriel (Daniel, 2026-11-12).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/driver_document_checklist.dart';
import 'package:movik_connect/services/picked_document_file.dart';

String t(String key) => AppStrings.t(key, 'fr');

DriverDocument _doc(String id, DriverDocumentType type, String file, {bool staff = false}) =>
    DriverDocument(
      id: id,
      driverId: 'drv',
      type: type,
      status: DriverDocumentStatus.uploaded,
      storageBucketPath: 'driver_documents/drv/$file',
      uploadedAt: DateTime(2026, 11, 12),
      addedByStaff: staff,
    );

Future<List<Map<String, dynamic>>> _pump(
  WidgetTester tester,
  List<DriverDocument> docs, {
  PickedDocumentFile? file,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final calls = <Map<String, dynamic>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DriverDocumentChecklist(
            driverId: 'drv',
            docs: docs,
            t: t,
            tileFor: (doc) => Text('tile:${doc.id}'),
            pick: () async => file,
            addCall: (data) async => calls.add(data),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('places: licence front and back, required ones flagged, identity under others', (tester) async {
    await _pump(tester, [
      _doc('front', DriverDocumentType.driversLicence, 'drivers_licence_front_1.jpg'),
      _doc('ins', DriverDocumentType.insurance, 'insurance_1.jpg', staff: true),
      _doc('id', DriverDocumentType.identity, 'identity_1.jpg'),
    ]);
    expect(find.text(t('doc_slot_licence_front')), findsOneWidget);
    expect(find.text(t('doc_slot_licence_back')), findsOneWidget);
    expect(find.text('tile:front'), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-missing-drivers_licence_front')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('doc-slot-drivers_licence_back')),
        matching: find.text('${t('admin_driver_doc_missing')} · ${t('admin_driver_doc_required')}'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('doc-missing-vehicle_registration')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('doc-slot-other')), matching: find.text('tile:id')),
      findsOneWidget,
    );
    expect(find.text(t('admin_driver_doc_add_hint')), findsOneWidget);
    // Every place has its « Ajouter » button.
    for (final id in [
      'drivers_licence_front', 'drivers_licence_back', 'vehicle_registration', 'insurance',
      'vehicle_main_photo', 'vehicle_rear_photo', 'vehicle_plate_photo', 'other',
    ]) {
      expect(find.byKey(ValueKey('doc-add-$id')), findsOneWidget, reason: id);
    }
  });

  testWidgets('a licence sent before in one image covers front and back', (tester) async {
    await _pump(tester, [
      _doc('old', DriverDocumentType.driversLicence, 'drivers_licence_1.jpg'),
    ]);
    expect(find.byKey(const ValueKey('doc-note-drivers_licence_front')), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-note-drivers_licence_back')), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-missing-drivers_licence_back')), findsNothing);
    expect(find.text('tile:old'), findsOneWidget);
  });

  testWidgets('an agent adds the licence back received by email', (tester) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final calls = await _pump(
      tester,
      const [],
      file: PickedDocumentFile(bytes: bytes, name: 'verso.pdf', mimeType: 'application/pdf'),
    );
    await tester.tap(find.byKey(const ValueKey('doc-add-drivers_licence_back')));
    await tester.pumpAndSettle();
    expect(calls, [
      {
        'driverId': 'drv',
        'slot': 'drivers_licence_back',
        'fileName': 'verso.pdf',
        'mimeType': 'application/pdf',
        'dataBase64': base64Encode(bytes),
      },
    ]);
    expect(find.text(t('admin_driver_doc_add_success')), findsOneWidget);
  });

  testWidgets('a file over 8 MB is refused before sending', (tester) async {
    final calls = await _pump(
      tester,
      const [],
      file: PickedDocumentFile(
        bytes: Uint8List(maxStaffDocumentBytes + 1),
        name: 'gros.pdf',
        mimeType: 'application/pdf',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('doc-add-insurance')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text(t('admin_driver_doc_too_large')), findsOneWidget);
  });

  test('MIME type from the browser or the file name', () {
    expect(documentMimeType('image/jpg', 'a.jpg'), 'image/jpeg');
    expect(documentMimeType('', 'permis.PDF'), 'application/pdf');
    expect(documentMimeType('application/octet-stream', 'x.heic'), 'image/heic');
    expect(documentMimeType('image/png', 'x'), 'image/png');
  });
}
