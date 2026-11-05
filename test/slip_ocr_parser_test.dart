import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/models/transaction_model.dart';
import 'package:keeptang/services/slip_inbox_service.dart';
import 'package:keeptang/services/slip_ocr_parser.dart';

void main() {
  group('SlipOcrParser', () {
    test('reads Thai amount, Buddhist date, and transaction number', () {
      final result = SlipOcrParser.parse('''
รายการสำเร็จ
จำนวนเงิน
1,250.00 บาท
วันหมดอายุ 06/11/2569
วันที่ทำรายการ 05/11/2569
เลขที่รายการ: ABC12345678
''');

      expect(result.amount, 1250);
      expect(result.date, DateTime(2026, 11, 5));
      expect(result.transactionNumber, 'ABC12345678');
    });

    test('reads English amount, year-first date, and reference number', () {
      final result = SlipOcrParser.parse('''
Transfer successful
Amount: THB 2,400.50
Date: 2026-11-05
Reference: REF-20261105-1234
''');

      expect(result.amount, 2400.5);
      expect(result.date, DateTime(2026, 11, 5));
      expect(result.transactionNumber, 'REF-20261105-1234');
    });

    test('prefers the transaction date over an expiry date', () {
      final result = SlipOcrParser.parse('''
วันหมดอายุ 06/11/2569
วันที่ทำรายการ 05/11/2569
''');

      expect(result.date, DateTime(2026, 11, 5));
    });

    test('reads Thai month names and two-digit Buddhist years', () {
      final result = SlipOcrParser.parse('วันที่ทำรายการ 5 พ.ย. 69');

      expect(result.date, DateTime(2026, 11, 5));
    });

    test('reads a date value on the line after its transaction-date label', () {
      final result = SlipOcrParser.parse('''
วันหมดอายุ
06/11/2569
วันที่ทำรายการ
05/11/2569
เวลา 14:25
''');

      expect(result.date, DateTime(2026, 11, 5));
    });

    test('reads English month-first dates', () {
      final result = SlipOcrParser.parse('Transaction Date: Nov 5, 2026');

      expect(result.date, DateTime(2026, 11, 5));
    });

    test('prefers the labeled amount to other slip amounts', () {
      final result = SlipOcrParser.parse('''
Balance 9,500.00
Transfer amount
250.00
Fee 10.00
''');

      expect(result.amount, 250);
    });

    test('prefers an amount marked THB over other decimal amounts', () {
      final result = SlipOcrParser.parse('''
Amount 100.00 USD
1,250.00 THB
''');

      expect(result.amount, 1250);
    });

    test('recognizes baht currency labels in Thai and English', () {
      final thaiResult = SlipOcrParser.parse('''
ยอดเงิน 800.00 บาท
ยอดคงเหลือ 9,500.00
''');
      final englishResult = SlipOcrParser.parse('Received 2400 baht');

      expect(thaiResult.amount, 800);
      expect(englishResult.amount, 2400);
    });

    test('normalizes Thai numerals and ignores balances and fees', () {
      final result = SlipOcrParser.parse('''
ยอดเงิน ๘๐๐.๐๐ บาท
ยอดคงเหลือ ๙,๕๐๐.๐๐
ค่าธรรมเนียม ๑๐.๐๐
''');

      expect(result.amount, 800);
    });

    test('does not use a fee as the transfer amount', () {
      final result = SlipOcrParser.parse('''
Balance 9,500.00
Fee 10.00
''');

      expect(result.amount, isNull);
    });

    test('does not interpret dates or reference numbers as an amount', () {
      final result = SlipOcrParser.parse('''
Date 05/11/2569
Reference 123456789012
''');

      expect(result.amount, isNull);
      expect(result.date, DateTime(2026, 11, 5));
    });

    test('stores the recognized slip number in the transaction model map', () {
      final result = SlipOcrParser.parse('Transaction ID: TRX-123456789');
      final transaction = TransactionModel(
        id: 'firestore-doc-id',
        title: 'Coffee',
        amount: 125,
        date: DateTime(2026, 11, 5),
        isExpense: true,
        category: 'อาหาร',
        transactionNo: result.transactionNumber!,
      );

      expect(transaction.toMap()['transactionNo'], 'TRX-123456789');
    });
  });

  test('SlipInboxDraft persists editable fields and selection state', () {
    final date = DateTime(2026, 11, 5);
    final draft = SlipInboxDraft(
      id: 'slip-1',
      imagePath: 'C:/slips/slip-1.jpg',
      title: 'Coffee',
      amount: 125.5,
      date: date,
      category: 'อาหาร',
      paymentMethod: 'cash',
      isExpense: true,
      selected: false,
      transactionNo: 'TRX-123456',
      assetId: 'asset-1',
    );

    final restored = SlipInboxDraft.fromJson(draft.toJson());

    expect(restored.id, draft.id);
    expect(restored.title, draft.title);
    expect(restored.amount, draft.amount);
    expect(restored.date, date);
    expect(restored.selected, isFalse);
    expect(restored.transactionNo, draft.transactionNo);
    expect(restored.assetId, draft.assetId);
  });
}
