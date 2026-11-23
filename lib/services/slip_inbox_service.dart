import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SlipInboxDraft {
  const SlipInboxDraft({
    required this.id,
    required this.imagePath,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.paymentMethod,
    required this.isExpense,
    required this.selected,
    this.transactionNo,
    this.assetId,
  });

  final String id;
  final String imagePath;
  final String title;
  final double? amount;
  final DateTime date;
  final String category;
  final String paymentMethod;
  final bool isExpense;
  final bool selected;
  final String? transactionNo;
  final String? assetId;

  String? get referenceNumber => transactionNo;

  SlipInboxDraft copyWith({
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? paymentMethod,
    bool? isExpense,
    bool? selected,
    String? transactionNo,
    String? assetId,
  }) {
    return SlipInboxDraft(
      id: id,
      imagePath: imagePath,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isExpense: isExpense ?? this.isExpense,
      selected: selected ?? this.selected,
      transactionNo: transactionNo ?? this.transactionNo,
      assetId: assetId ?? this.assetId,
    );
  }

  factory SlipInboxDraft.fromJson(Map<String, dynamic> json) {
    return SlipInboxDraft(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      paymentMethod: json['paymentMethod'] as String,
      isExpense: json['isExpense'] as bool? ?? true,
      selected: json['selected'] as bool? ?? true,
      transactionNo: json['transactionNo'] as String?,
      assetId: json['assetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'paymentMethod': paymentMethod,
        'isExpense': isExpense,
        'selected': selected,
        'transactionNo': transactionNo,
        'assetId': assetId,
      };
}

class SlipInboxService {
  const SlipInboxService(this.scope);

  final String scope;
  static const _draftsKey = 'slip_inbox_drafts';
  static const _corruptDraftsBackupKey = 'slip_inbox_drafts_corrupt_backup';
  static const _processedAssetsKey = 'slip_inbox_processed_assets';
  static final _random = Random.secure();

  String _key(String key) => '$scope:$key';

  static Future<void> migrateLegacy(String? savedGuestScope) async {
    final prefs = await SharedPreferences.getInstance();
    const migratedKey = 'slip_inbox_scope_migrated';
    if (prefs.getBool(migratedKey) == true) return;
    if (savedGuestScope != null) {
      final inbox = SlipInboxService(savedGuestScope);
      for (final key in [_draftsKey, _corruptDraftsBackupKey]) {
        final value = prefs.getString(key);
        final target = inbox._key(key);
        if (value != null && !prefs.containsKey(target)) {
          await prefs.setString(target, value);
        }
      }
      final processed = prefs.getStringList(_processedAssetsKey);
      final target = inbox._key(_processedAssetsKey);
      if (processed != null && !prefs.containsKey(target)) {
        await prefs.setStringList(target, processed);
      }
    }
    await prefs.setBool(migratedKey, true);
  }

  Future<List<SlipInboxDraft>> loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(_draftsKey));
    if (value == null) return [];

    dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (error) {
      debugPrint('Invalid slip inbox data; resetting saved drafts: $error');
      try {
        await prefs.setString(_key(_corruptDraftsBackupKey), value);
        await prefs.setString(_key(_draftsKey), jsonEncode([]));
      } catch (saveError) {
        debugPrint('Could not reset invalid slip inbox data: $saveError');
      }
      return [];
    }

    if (decoded is! List) {
      debugPrint('Slip inbox data is not a list; resetting saved drafts.');
      try {
        await prefs.setString(_key(_corruptDraftsBackupKey), value);
        await prefs.setString(_key(_draftsKey), jsonEncode([]));
      } catch (error) {
        debugPrint('Could not reset invalid slip inbox data: $error');
      }
      return [];
    }

    final drafts = <SlipInboxDraft>[];
    var skippedDrafts = 0;
    for (final item in decoded) {
      if (item is! Map) {
        skippedDrafts++;
        continue;
      }
      try {
        drafts.add(
          SlipInboxDraft.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        skippedDrafts++;
      }
    }

    if (skippedDrafts > 0) {
      debugPrint('Skipped $skippedDrafts invalid slip inbox draft(s).');
      try {
        await saveDrafts(drafts);
      } catch (error) {
        debugPrint('Could not save repaired slip inbox drafts: $error');
      }
    }
    return drafts;
  }

  Future<void> saveDrafts(List<SlipInboxDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(_draftsKey),
      jsonEncode(drafts.map((draft) => draft.toJson()).toList()),
    );
  }

  static Future<SlipInboxDraft> storeDraft({
    required Uint8List imageBytes,
    required String extension,
    required String title,
    required double? amount,
    required DateTime date,
    required String category,
    required String paymentMethod,
    required bool isExpense,
    String? transactionNo,
    String? assetId,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final inboxDirectory =
        Directory('${directory.path}${Platform.pathSeparator}slip_inbox');
    await inboxDirectory.create(recursive: true);

    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
    final safeExtension = extension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final imagePath =
        '${inboxDirectory.path}${Platform.pathSeparator}$id.${safeExtension.isEmpty ? 'jpg' : safeExtension}';
    await File(imagePath).writeAsBytes(imageBytes, flush: true);

    return SlipInboxDraft(
      id: id,
      imagePath: imagePath,
      title: title,
      amount: amount,
      date: date,
      category: category,
      paymentMethod: paymentMethod,
      isExpense: isExpense,
      selected: true,
      transactionNo: transactionNo,
      assetId: assetId,
    );
  }

  Future<Set<String>> loadProcessedAssetIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(_processedAssetsKey)) ?? <String>[])
        .toSet();
  }

  Future<void> removeDrafts(
    List<SlipInboxDraft> drafts,
    Set<String> ids, {
    bool markAssetsProcessed = true,
  }) async {
    final removed = drafts.where((draft) => ids.contains(draft.id)).toList();
    for (final draft in removed) {
      final file = File(draft.imagePath);
      if (await file.exists()) await file.delete();
    }

    final remaining = drafts.where((draft) => !ids.contains(draft.id)).toList();
    await saveDrafts(remaining);

    if (markAssetsProcessed) {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(_processedAssetsKey);
      final processed = prefs.getStringList(key) ?? <String>[];
      final updated = {...processed, ...removed.map((draft) => draft.assetId)}
          .whereType<String>()
          .toList();
      await prefs.setStringList(key, updated);
    }
  }
}
