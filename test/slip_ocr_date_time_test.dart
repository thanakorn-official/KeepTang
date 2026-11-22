import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/models/transaction_model.dart';
import 'package:keeptang/services/slip_inbox_service.dart';
import 'package:keeptang/services/slip_ocr_parser.dart';

void main() {
  test('reads a full Thai Buddhist date and time with Thai numerals', () {
    final result = SlipOcrParser.parse('''
โอนเงินสำเร็จ
วันที่ทำรายการ: ๕ พฤศจิกายน พ.ศ. ๒๕๖๙ เวลา ๑๔:๒๕:๐๙ น.
จำนวนเงิน: ๑,๒๕๐.๐๐ บาท
''');

    expect(result.date, DateTime(2026, 11, 5, 14, 25, 9));
    expect(result.hasTime, isTrue);
    expect(result.amount, 1250);
  });

  test('reads an abbreviated Thai month and a dot-separated clock', () {
    final result = SlipOcrParser.parse('''
วันที่ทำรายการ 5 พ. ย. 69
เวลา 8.05 น.
ยอดโอน 125.00 บาท
''');

    expect(result.date, DateTime(2026, 11, 5, 8, 5));
    expect(result.hasTime, isTrue);
    expect(result.amount, 125);
  });

  test('honors a Gregorian year and PM on a bilingual slip', () {
    final result = SlipOcrParser.parse(
      'วันที่ทำรายการ ๕ พ.ย. ค.ศ. ๒๐๒๖ Time: ๒:๒๕ PM',
    );

    expect(result.date, DateTime(2026, 11, 5, 14, 25));
    expect(result.hasTime, isTrue);
  });

  test('recognizes an unlabeled timestamp after an amount with its own value',
      () {
    final result = SlipOcrParser.parse('''
โอนเงินสำเร็จ
ยอดเงิน 125.00 บาท
05/11/2569 14:25 น.
''');

    expect(result.date, DateTime(2026, 11, 5, 14, 25));
    expect(result.hasTime, isTrue);
    expect(result.amount, 125);
  });

  test('pairs separate transaction date and time values ahead of expiry', () {
    final result = SlipOcrParser.parse('''
วันหมดอายุ 06/11/2569 19:31
วันที่ทำรายการ
05/11/2569
เวลา
14:25
เลขอ้างอิง: REF-20261105-7864
''');

    expect(result.date, DateTime(2026, 11, 5, 14, 25));
    expect(result.hasTime, isTrue);
    expect(result.referenceNumber, 'REF-20261105-7864');
  });

  test('allows OCR spacing around separators and recognizes actual midnight',
      () {
    final result = SlipOcrParser.parse('''
วันที่: ๐๕ / ๑๑ / ๒๕๖๙
เวลา: ๐๐ : ๐๐ น.
''');

    expect(result.date, DateTime(2026, 11, 5));
    expect(result.hasTime, isTrue);
  });

  test('does not assign an expiry clock, fee or reference to a date', () {
    final result = SlipOcrParser.parse('''
วันที่ทำรายการ 05/11/2569
วันหมดอายุ 06/11/2569 19:31
ค่าธรรมเนียม 12.45 บาท
เลขอ้างอิง: REF-20261105-1425
''');

    expect(result.date, DateTime(2026, 11, 5));
    expect(result.hasTime, isFalse);
  });

  test('does not mistake a stand-alone expiry value for the transaction', () {
    final result = SlipOcrParser.parse('''
วันหมดอายุ
06/11/2569 เวลา 19:31
เลขอ้างอิง: REF-20261105-1425
''');

    expect(result.date, isNull);
    expect(result.hasTime, isFalse);
  });

  test('malformed clocks do not become a partial or rolled-over time', () {
    for (final clock in ['24:35', '14:62', '14:25:71']) {
      final result =
          SlipOcrParser.parse('วันที่ทำรายการ 05/11/2569 เวลา $clock');

      expect(result.date, DateTime(2026, 11, 5), reason: clock);
      expect(result.hasTime, isFalse, reason: clock);
    }
  });

  test('an unreadable date is not replaced with the day of the scan', () {
    final result = SlipOcrParser.parse('วันที่ทำรายการ 31/11/2569 เวลา 14:25');

    expect(result.date, isNull);
    expect(result.hasTime, isFalse);
  });

  test('reads a labelled clock above the date and tolerates a missing dot', () {
    final result = SlipOcrParser.parse('''
เวลา 7.09 น
วันที่ทำรายการ: 05/11/2569
''');

    expect(result.date, DateTime(2026, 11, 5, 7, 9));
    expect(result.hasTime, isTrue);
  });

  test('does not borrow a previous expiry clock for the transaction date', () {
    final result = SlipOcrParser.parse('''
Expiry: 06/11/2026
Time 19:31
Transaction Date: 05/11/2026
''');

    expect(result.date, DateTime(2026, 11, 5));
    expect(result.hasTime, isFalse);
  });

  test('reads a hyphenated Thai abbreviated month and preserves seconds', () {
    final result = SlipOcrParser.parse(
      'วันที่โอน: ๕-พ.ย.-๒๕๖๙ เวลา ๑๔:๒๕:๓๖ น.',
    );

    expect(result.date, DateTime(2026, 11, 5, 14, 25, 36));
    expect(result.hasTime, isTrue);
  });

  test('reads a Thai full month with slashes and an explicit Buddhist era', () {
    final result = SlipOcrParser.parse(
      'วันที่ทำรายการ ๗ / ธันวาคม / พ.ศ. ๒๕๖๙, ๐๐:๐๓ น.',
    );

    expect(result.date, DateTime(2026, 12, 7, 0, 3));
    expect(result.hasTime, isTrue);
  });

  test('joins a wrapped Buddhist year and clock to a named Thai date', () {
    final result = SlipOcrParser.parse('''
วันที่ทำรายการ
5 พ.ย.
พ.ศ. 2569
เวลา 14:25
''');

    expect(result.date, DateTime(2026, 11, 5, 14, 25));
    expect(result.hasTime, isTrue);
  });

  test('reads an English month-first ordinal with a separate PM clock', () {
    final result = SlipOcrParser.parse('''
Transaction Date: November 5th, 2026
Transaction Time: 11:42 PM
''');

    expect(result.date, DateTime(2026, 11, 5, 23, 42));
    expect(result.hasTime, isTrue);
  });

  test('reads a day-first ordinal and Sept. with a dotted AM qualifier', () {
    final result = SlipOcrParser.parse(
      'Transaction Date: 5th Sept. 2026 at 12:05 A.M.',
    );

    expect(result.date, DateTime(2026, 9, 5, 0, 5));
    expect(result.hasTime, isTrue);
  });

  test('reads year-first dates with a numeric or abbreviated month', () {
    for (final timestamp in ['2026-11-05T22:31:08', '2026-Nov-05 22:31:08']) {
      final result = SlipOcrParser.parse('Transaction Date: $timestamp');

      expect(result.date, DateTime(2026, 11, 5, 22, 31, 8), reason: timestamp);
      expect(result.hasTime, isTrue, reason: timestamp);
    }
  });

  test('does not interpret a clock as the missing year of a named date', () {
    final result = SlipOcrParser.parse('Transaction Date: 5 Nov 14:25');

    expect(result.date, isNull);
    expect(result.hasTime, isFalse);
  });

  test('keeps the Thai reference separate from a neighboring clock', () {
    final result = SlipOcrParser.parse(
      'วันที่ทำรายการ 7-Dec.-2026 เวลา 13:48 น. รหัสอ้างอิง: KTB-P20261207',
    );

    expect(result.date, DateTime(2026, 12, 7, 13, 48));
    expect(result.hasTime, isTrue);
    expect(result.referenceNumber, 'KTB-P20261207');
  });

  test('keeps the parsed clock when a draft and transaction are serialized',
      () {
    final result =
        SlipOcrParser.parse('วันที่ทำรายการ: 5 พ.ย. 2569 เวลา 14:25:36 น.');
    expect(result.hasTime, isTrue);
    expect(result.date, DateTime(2026, 11, 5, 14, 25, 36));
    final draft = SlipInboxDraft(
      id: 'test-slip',
      imagePath: 'test-slip.png',
      title: 'ตัวอย่าง',
      amount: 125,
      date: result.date!,
      category: 'อื่นๆ',
      paymentMethod: 'cash',
      isExpense: true,
      selected: false,
    );
    final restoredDraft = SlipInboxDraft.fromJson(draft.toJson());
    final transaction = TransactionModel(
      id: restoredDraft.id,
      title: restoredDraft.title,
      amount: restoredDraft.amount!,
      date: restoredDraft.date,
      isExpense: restoredDraft.isExpense,
      category: restoredDraft.category,
      paymentMethod: restoredDraft.paymentMethod,
    );
    final transactionMap = transaction.toMap();

    expect(transactionMap['date'], '2026-11-05T14:25:36.000');
    expect(
      TransactionModel.fromMap(transactionMap).date,
      DateTime(2026, 11, 5, 14, 25, 36),
    );
  });
}
