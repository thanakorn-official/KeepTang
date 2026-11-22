import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guest ID ระบุพื้นที่ข้อมูลใน Firestore ส่วนชื่อผู้ใช้เป็นชื่อแสดงผล
class GuestService {
  static const _idKey = 'guest_id';
  static const _usernameKey = 'guest_username';
  static const _legacyUpgradedKey = 'guest_legacy_upgraded';
  static const _legacyMigratedKey = 'guest_legacy_migrated';
  static const _categoriesKey = 'app_categories_list';
  static const _categoryIconsKey = 'app_category_icon_codes';
  static const _categoryColorsKey = 'app_category_color_values';
  static const _paymentsKey = 'app_payments_list';
  static const _paymentIconsKey = 'app_payment_icon_codes';
  static const _paymentColorsKey = 'app_payment_color_values';

  static const _customSettingKeys = [
    _categoriesKey,
    _categoryIconsKey,
    _categoryColorsKey,
    _paymentsKey,
    _paymentIconsKey,
    _paymentColorsKey,
  ];

  static const _idAlphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  static String? _guestId;
  static String? _username;

  static String get guestId => _guestId ?? '';

  static String? get username => _username;

  static bool get hasActiveGuest =>
      _guestId != null && (_username ?? '').isNotEmpty;

  static CollectionReference<Map<String, dynamic>> get _guests =>
      FirebaseFirestore.instance.collection('guests');

  static DocumentReference<Map<String, dynamic>> get activeGuestDocument {
    if (!hasActiveGuest) {
      throw StateError('Create or restore a Guest ID first.');
    }
    return _guests.doc(guestId);
  }

  static bool _isValidGuestId(String id) =>
      id.isNotEmpty &&
      id != '.' &&
      id != '..' &&
      !id.contains('/') &&
      !(id.startsWith('__') && id.endsWith('__'));

  /// Loads only an existing local session. A missing ID stays missing.
  static Future<void> loadSavedGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey)?.trim() ?? '';
    _guestId = _isValidGuestId(id) ? id : null;
    _username = _guestId == null ? null : prefs.getString(_usernameKey)?.trim();
  }

  static String _newGuestId() {
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).padLeft(8, '0');
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => _idAlphabet[random.nextInt(_idAlphabet.length)],
    ).join();
    return 'G-$timestamp$suffix';
  }

  /// Creates a cloud account only after the user submits the create form.
  static Future<void> createGuest(String name) async {
    final displayName = name.trim();
    if (displayName.isEmpty || hasActiveGuest) {
      throw StateError('A new Guest ID requires a name and no active session.');
    }
    final prefs = await SharedPreferences.getInstance();
    final firestore = FirebaseFirestore.instance;
    for (var attempt = 0; attempt < 3; attempt++) {
      final doc = _guests.doc(_newGuestId());
      final created = await firestore.runTransaction<bool>((transaction) async {
        if ((await transaction.get(doc)).exists) return false;
        transaction.set(doc, {
          'username': displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      }, timeout: const Duration(seconds: 12));
      if (!created) continue;

      await _saveLocalGuest(prefs, id: doc.id, name: displayName);
      return;
    }
    throw StateError('Could not create an unused Guest ID.');
  }

  static Future<void> _saveLocalGuest(
    SharedPreferences prefs, {
    required String id,
    required String name,
  }) async {
    // A newly created or explicitly restored account is never a legacy
    // migration target from a previous local session.
    await prefs.remove(_legacyUpgradedKey);
    await prefs.remove(_legacyMigratedKey);
    if (_guestId != id) {
      for (final key in _customSettingKeys) {
        await prefs.remove(key);
      }
    }
    await prefs.setString(_usernameKey, name);
    await prefs.setString(_idKey, id);
    _username = name;
    _guestId = id;
  }

  static Future<void> finishPendingLegacyMigration() async {
    if (!hasActiveGuest) return;
    final prefs = await SharedPreferences.getInstance();
    if (hasActiveGuest &&
        prefs.getBool(_legacyUpgradedKey) == true &&
        prefs.getBool(_legacyMigratedKey) != true) {
      await _migrateLegacyGuestData(prefs);
    }
  }

  /// คัดลอกรายการจากพื้นที่รูปแบบเก่า guests/{ชื่อผู้ใช้}/transactions
  /// มาไว้ที่ guests/{guestId}/transactions ของเครื่องนี้
  /// (คัดลอกเท่านั้น ไม่ลบของเดิม; ถ้าล้มเหลว เช่น ออฟไลน์ จะลองใหม่เปิดครั้งถัดไป)
  static Future<void> _migrateLegacyGuestData(SharedPreferences prefs) async {
    final legacyId = username!.trim().replaceAll('/', '-');
    if (!_isValidGuestId(legacyId)) return;
    try {
      final fs = FirebaseFirestore.instance;
      final guestDoc = activeGuestDocument;
      final existing = await guestDoc
          .collection('transactions')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (existing.docs.isEmpty) {
        final legacy = await fs
            .collection('guests')
            .doc(legacyId)
            .collection('transactions')
            .get()
            .timeout(const Duration(seconds: 8));
        final docs = legacy.docs;
        for (var i = 0; i < docs.length; i += 400) {
          final batch = fs.batch();
          for (final doc in docs.skip(i).take(400)) {
            batch.set(
                guestDoc.collection('transactions').doc(doc.id), doc.data());
          }
          await batch.commit().timeout(const Duration(seconds: 8));
        }
      }
      await prefs.setBool(_legacyMigratedKey, true);
    } catch (_) {}
  }

  /// ตั้งชื่อผู้ใช้ (ชื่อแสดงผลเท่านั้น ไม่กระทบพื้นที่ข้อมูล)
  static Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !hasActiveGuest) return;
    final doc = activeGuestDocument;
    _username = trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (!hasActiveGuest || doc.id != guestId) return;
    await prefs.setString(_usernameKey, trimmed);
    try {
      await doc.set({'username': trimmed}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Verifies an existing account with Firestore before changing the local
  /// session. A missing ID does not create a new cloud document.
  static Future<bool> restoreGuest(String input) async {
    final id = input.trim();
    if (!_isValidGuestId(id)) return false;
    const options = GetOptions(source: Source.server);
    const timeout = Duration(seconds: 8);
    final guest = _guests.doc(id);
    final profile = await guest.get(options).timeout(timeout);
    if (!profile.exists) {
      // Firestore allows an existing subcollection without a parent document.
      final existingData = await Future.wait([
        _preferencesFor(guest).get(options).then((doc) => doc.exists),
        guest
            .collection('transactions')
            .limit(1)
            .get(options)
            .then((query) => query.docs.isNotEmpty),
      ]).timeout(timeout);
      if (!existingData.contains(true)) return false;
    }

    final savedName = (profile.data()?['username'] as String?)?.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();
    await _saveLocalGuest(prefs,
        id: id, name: savedName.isEmpty ? id : savedName);
    return true;
  }

  static DocumentReference<Map<String, dynamic>> _preferencesFor(
    DocumentReference<Map<String, dynamic>> guest,
  ) =>
      guest.collection('settings').doc('preferences');

  /// Saves local category and payment preferences for the active Guest ID.
  static Future<void> saveCustomSettings() async {
    if (!hasActiveGuest) return;
    final guest = activeGuestDocument;
    final prefs = await SharedPreferences.getInstance();
    if (!hasActiveGuest || guest.id != guestId) return;
    final values = <String, String>{
      for (final key in _customSettingKeys)
        if (prefs.getString(key) != null) key: prefs.getString(key)!,
    };
    try {
      await _preferencesFor(guest).set({
        'values': values,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Local preferences remain available and will be synced on a later save.
    }
  }

  /// Restores the active Guest's category and payment preferences locally.
  static Future<void> restoreCustomSettings() async {
    if (!hasActiveGuest) return;
    final guest = activeGuestDocument;
    final prefs = await SharedPreferences.getInstance();
    try {
      final doc = await _preferencesFor(guest)
          .get()
          .timeout(const Duration(seconds: 8));
      final values = doc.data()?['values'];
      if (values is Map) {
        for (final key in _customSettingKeys) {
          if (!hasActiveGuest || guest.id != guestId) return;
          final value = values[key];
          if (value is String) {
            await prefs.setString(key, value);
          } else {
            await prefs.remove(key);
          }
        }
      }
    } catch (_) {
      // Offline users continue using the locally cached preferences.
    }
  }

  /// Ends the current local guest session without deleting its cloud data.
  /// The previous data can be restored later with its Guest ID.
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_legacyUpgradedKey);
    await prefs.remove(_legacyMigratedKey);
    for (final key in _customSettingKeys) {
      await prefs.remove(key);
    }
    _guestId = null;
    _username = null;
  }
}
