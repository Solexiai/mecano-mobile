import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import '../helpers/booking_test_harness.dart';

class PickerProbe extends ImagePickerPlatform {
  PickerProbe(this.events);
  final List<String> events;
  bool denied = false;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    events.add('picker');
    expect(source, ImageSource.gallery);
    if (denied) throw PlatformException(code: 'photo_access_denied');
    return null;
  }
}

class SaveProbe extends TestBookingApi {
  SaveProbe(this.events);
  final List<String> events;
  bool failSave = false;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'saveBookingDraft') {
      events.add('save');
      if (failSave) throw StateError('simulated unavailable save');
    }
    return super.call(name, data);
  }
}

void main() {
  late ImagePickerPlatform original;
  setUp(() => original = ImagePickerPlatform.instance);
  tearDown(() => ImagePickerPlatform.instance = original);

  for (final failSave in [false, true]) {
    testWidgets('local picker precedes remote save (save failure: $failSave)', (
      tester,
    ) async {
      final events = <String>[];
      final picker = PickerProbe(events);
      ImagePickerPlatform.instance = picker;
      final api = SaveProbe(events);
      final draft = testDraft();
      draft.data['intake_mode'] = 'photo_assisted';
      final storage = MemoryBookingStorage(draft);
      await pumpBooking(
        tester,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
      );
      final add = find.byKey(const ValueKey('photo-add-test-item'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      events.clear();
      api.failSave = failSave;
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(events, isNotEmpty);
      expect(
        events.first,
        'picker',
        reason: 'The native picker must run before any remote save.',
      );
      expect(events.where((e) => e == 'picker'), hasLength(1));
      expect(storage.saved!.items.single['photos'], isEmpty);
      expect(api.calls, isNot(contains('analyzeBookingPhoto')));
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(tester);
    });
  }

  testWidgets('picker permission error releases button for retry', (
    tester,
  ) async {
    final events = <String>[];
    final picker = PickerProbe(events)..denied = true;
    ImagePickerPlatform.instance = picker;
    final draft = testDraft();
    draft.data['intake_mode'] = 'photo_assisted';
    final storage = MemoryBookingStorage(draft);
    await pumpBooking(
      tester,
      storage: storage,
      api: SaveProbe(events),
      photoIntakeEnabled: true,
    );
    final add = find.byKey(const ValueKey('photo-add-test-item'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    picker.denied = false;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(events.where((e) => e == 'picker'), hasLength(2));
    expect(storage.saved!.items.single['photos'], isEmpty);
    expect(tester.takeException(), isNull);
    await disposeBooking(tester);
  });
}
