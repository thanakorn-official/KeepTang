import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// โหมดผู้ใช้ทั่วไป (Guest): ไม่มีระบบบัญชี — แต่ละเครื่องจะได้ ID ที่สุ่มขึ้น
/// ไม่ซ้ำกับผู้ใช้อื่น (guestId) เป็นที่อยู่ของพื้นที่ข้อมูลใน Firestore
/// ส่วน "ชื่อผู้ใช้" เป็นเพียงชื่อแสดงผล ตั้ง/เปลี่ยนได้อิสระโดยไม่กระทบข้อมูล
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

  /// ID พื้นที่ข้อมูลที่สุ่มไม่ซ้ำกัน (ว่างเมื่อยังไม่ผ่าน ensureGuest)
  static String get guestId => _guestId ?? '';

  static String? get username => _username;

  static bool get hasUsername => (_username ?? '').trim().isNotEmpty;

  /// โหลด Guest ของเครื่องนี้ ถ้ายังไม่มีจะสุ่ม ID ใหม่ที่ไม่ซ้ำกับผู้อื่น
  /// และสำหรับเครื่องที่อัปเกรดมาจากเวอร์ชันที่ใช้ชื่อผู้ใช้เป็น ID
  /// จะคัดลอกข้อมูลเดิมมาที่ ID ใหม่ให้เอง
  static Future<void> ensureGuest() async {
    final prefs = await SharedPreferences.getInstance();
    _guestId = prefs.getString(_idKey);
    _username = prefs.getString(_usernameKey);

    if (_guestId == null || _guestId!.isEmpty) {
      final fromOldVersion = hasUsername;
      _guestId = await _generateUniqueGuestId();
      await prefs.setString(_idKey, _guestId!);
      // เครื่องใหม่ล้วนไม่ต้องยุ่งกับข้อมูลรูปแบบเก่าเด็ดขาด
      await prefs.setBool(_legacyUpgradedKey, fromOldVersion);
      await prefs.setBool(_legacyMigratedKey, !fromOldVersion);
      await _touchGuestDoc();
    }

    if (prefs.getBool(_legacyUpgradedKey) == true &&
        prefs.getBool(_legacyMigratedKey) != true &&
        hasUsername) {
      await _migrateLegacyGuestData(prefs);
    }
  }

  /// สุ่ม ID: G- + เวลา (base36) + 4 ตัวอักษรสุ่ม แล้วตรวจกับ Firestore
  /// ว่าไม่มีใครใช้ก่อน — ถ้าออฟไลน์ให้ใช้ค่าที่สุ่มได้เลย
  /// (โอกาสชนกันกับผู้อื่นแทบเป็นศูนย์)
  static Future<String> _generateUniqueGuestId() async {
    String candidate() {
      final ts = DateTime.now()
          .millisecondsSinceEpoch
          .toRadixString(36)
          .padLeft(8, '0');
      final rnd = Random.secure();
      final suffix =
          List.generate(4, (_) => _idAlphabet[rnd.nextInt(_idAlphabet.length)])
              .join();
      return 'G-$ts$suffix';
    }

    var id = candidate();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('guests')
            .doc(id)
            .get()
            .timeout(const Duration(seconds: 3));
        if (!doc.exists) return id;
        id = candidate();
      } catch (_) {
        return id;
      }
    }
    return id;
  }

  static Future<void> _touchGuestDoc() async {
    try {
      await FirebaseFirestore.instance.collection('guests').doc(_guestId).set({
        'username': username ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// คัดลอกรายการจากพื้นที่รูปแบบเก่า guests/{ชื่อผู้ใช้}/transactions
  /// มาไว้ที่ guests/{guestId}/transactions ของเครื่องนี้
  /// (คัดลอกเท่านั้น ไม่ลบของเดิม; ถ้าล้มเหลว เช่น ออฟไลน์ จะลองใหม่เปิดครั้งถัดไป)
  static Future<void> _migrateLegacyGuestData(SharedPreferences prefs) async {
    final legacyId = username!.trim().replaceAll('/', '-');
    try {
      final fs = FirebaseFirestore.instance;
      final guestDoc = fs.collection('guests').doc(_guestId);
      final existing = await guestDoc.collection('transactions').limit(1).get();
      if (existing.docs.isEmpty) {
        final legacy = await fs
            .collection('guests')
            .doc(legacyId)
            .collection('transactions')
            .get();
        final docs = legacy.docs;
        for (var i = 0; i < docs.length; i += 400) {
          final batch = fs.batch();
          for (final doc in docs.skip(i).take(400)) {
            batch.set(
                guestDoc.collection('transactions').doc(doc.id), doc.data());
          }
          await batch.commit();
        }
      }
      await prefs.setBool(_legacyMigratedKey, true);
    } catch (_) {}
  }

  /// ตั้งชื่อผู้ใช้ (ชื่อแสดงผลเท่านั้น ไม่กระทบพื้นที่ข้อมูล)
  static Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    _username = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, trimmed);
    try {
      await FirebaseFirestore.instance
          .collection('guests')
          .doc(_guestId)
          .set({'username': trimmed}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// กำหนด Guest ID ด้วยตัวเอง (สำหรับกู้คืนข้อมูลเดิม)
  static Future<void> setCustomGuestId(String customId) async {
    final trimmed = customId.trim();
    if (trimmed.isEmpty) return;
    _guestId = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, trimmed);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('guests')
          .doc(trimmed)
          .get();
      if (doc.exists) {
        final savedName = (doc.data()?['username'] as String? ?? '').trim();
        if (savedName.isNotEmpty) {
          _username = savedName;
          await prefs.setString(_usernameKey, savedName);
        }
      } else {
        await _touchGuestDoc();
      }
    } catch (_) {
      await _touchGuestDoc();
    }
  }

  static DocumentReference<Map<String, dynamic>> get _preferencesDocument =>
      FirebaseFirestore.instance
          .collection('guests')
          .doc(guestId)
          .collection('settings')
          .doc('preferences');

  /// Saves local category and payment preferences for the active Guest ID.
  static Future<void> saveCustomSettings() async {
    if (guestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final values = <String, String>{
      for (final key in _customSettingKeys)
        if (prefs.getString(key) != null) key: prefs.getString(key)!,
    };
    try {
      await _preferencesDocument.set({
        'values': values,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Local preferences remain available and will be synced on a later save.
    }
  }

  /// Restores the active Guest's category and payment preferences locally.
  static Future<void> restoreCustomSettings() async {
    if (guestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final doc = await _preferencesDocument.get();
      final values = doc.data()?['values'];
      if (values is Map) {
        for (final key in _customSettingKeys) {
          final value = values[key];
          if (value is String) {
            await prefs.setString(key, value);
          } else {
            await prefs.remove(key);
          }
        }
      } else if (!doc.exists) {
        await saveCustomSettings();
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
