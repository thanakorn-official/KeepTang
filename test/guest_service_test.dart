import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/services/guest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening without a Guest ID does not create one', () async {
    SharedPreferences.setMockInitialValues(
        {'guest_username': 'Old display name'});

    await GuestService.loadSavedGuest();
    await GuestService.saveCustomSettings();
    await GuestService.setUsername('Unconfirmed name');

    expect(GuestService.hasActiveGuest, isFalse);
    expect(GuestService.guestId, isEmpty);
    expect(() => GuestService.activeGuestDocument, throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('guest_id'), isFalse);
    expect(prefs.getString('guest_username'), 'Old display name');
  });

  test('an existing local session loads without contacting Firestore',
      () async {
    SharedPreferences.setMockInitialValues({
      'guest_id': 'G-saved123',
      'guest_username': 'KeepTang',
    });

    await GuestService.loadSavedGuest();

    expect(GuestService.hasActiveGuest, isTrue);
    expect(GuestService.guestId, 'G-saved123');
    expect(GuestService.username, 'KeepTang');

    await GuestService.signOut();
    await GuestService.loadSavedGuest();
    expect(GuestService.hasActiveGuest, isFalse);
    expect(GuestService.guestId, isEmpty);
  });

  test('invalid restore input leaves the local guest session empty', () async {
    SharedPreferences.setMockInitialValues({});
    await GuestService.loadSavedGuest();

    for (final id in ['', '  ', '..', 'guests/other']) {
      expect(await GuestService.restoreGuest(id), isFalse);
    }

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('guest_id'), isFalse);
    expect(GuestService.hasActiveGuest, isFalse);
  });
}
