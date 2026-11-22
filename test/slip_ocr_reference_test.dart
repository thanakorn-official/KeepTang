import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/services/slip_ocr_parser.dart';

void main() {
  test('reads a split English label and reference with OCR spacing', () {
    final result = SlipOcrParser.parse('''
Bank transfer receipt
Amount THB 360.00
Transaction
Reference No. : TXN ‐ ００１２
３４５６
Date: 2026-11-21
''');
    expect(result.referenceNumber, 'TXN-00123456');
    expect(result.looksLikeTransferSlip, isTrue);
  });

  test('reads a reference after a spaced Thai transfer label', () {
    final result = SlipOcrParser.parse('''
โอนเงินสำเร็จ
จำนวนเงิน 70.50 บาท
หมาย เลข อ้าง อิง การ โอน
๐๐๑๒ ๓๔๕๖ ๗๘๙๐
''');
    expect(result.referenceNumber, '001234567890');
    expect(result.amount, 70.50);
  });

  test('reads the Thai reference code label before inline Thai digits', () {
    final result = SlipOcrParser.parse('รหัสอ้างอิงที่： ๐๐๑๒๓๔๕๖๗๘');
    expect(result.referenceNumber, '0012345678');
    expect(result.looksLikeTransferSlip, isFalse);
  });

  test('reads the Thai reference after a separated clock on the same line', () {
    final result =
        SlipOcrParser.parse('เวลา 14:24 น. | รหัสอ้างอิง: TH-00123456');
    expect(result.referenceNumber, 'TH-00123456');
  });

  test('rejoins Thai reference label syllables split over three OCR lines', () {
    final result = SlipOcrParser.parse('''
โอนเงินสำเร็จ
ยอดเงิน 80.00 บาท
ร หั ส
อ้ า ง
อิ ง : KT-００１２３４５６
''');
    expect(result.referenceNumber, 'KT-00123456');
    expect(result.looksLikeTransferSlip, isTrue);
  });

  test('prefers a qualified Thai transaction reference to a generic one', () {
    for (final label in [
      'รหัสอ้างอิงของรายการโอนเงิน',
      'รหัสอ้างอิงธุรกรรม',
    ]) {
      final result = SlipOcrParser.parse('''
รหัสอ้างอิง: GEN-00123456
$label
BANK-00123456
''');
      expect(result.referenceNumber, 'BANK-00123456', reason: label);
    }
  });

  test('recognizes words split inside an English reference label', () {
    final result = SlipOcrParser.parse('''
Trans action
Ref er ence N o. : ENG-00123456
''');
    expect(result.referenceNumber, 'ENG-00123456');
  });

  test('recognizes RRN labels without losing a reference prefix', () {
    expect(
      SlipOcrParser.parse('RRN: 001234567890').referenceNumber,
      '001234567890',
    );
    expect(
      SlipOcrParser.parse('Reference No.: RRN-001234567890').referenceNumber,
      'RRN-001234567890',
    );
  });

  test('prefers the bank transaction ID to order and numbered references', () {
    final result = SlipOcrParser.parse('''
Order Reference: ORDER-123456
Ref. 1: 123456789012345
Reference: GENERIC-112233
Transfer ID: BANK-000456789; Fee 0.00
''');
    expect(result.referenceNumber, 'BANK-000456789');
  });

  test('keeps a short complete reference separate from the next account', () {
    final result = SlipOcrParser.parse('''
Ref. No.: A1B2C3
1234567890
''');
    expect(result.referenceNumber, 'A1B2C3');
  });

  test('keeps a complete code separate from an ambiguous numeric next line',
      () {
    final result = SlipOcrParser.parse('Ref No.: A1B2C3\n5000');
    expect(result.referenceNumber, 'A1B2C3');
  });

  test('does not infer references from dates or unrelated field values', () {
    final values = [
      'Date: 2026-11-21',
      '21 November 2026',
      '21 / 11 / 2026',
      'Account: 1234567890',
      '123-4-56789-0',
      'XXX-X-12345-X',
      '1-2345-67890-12-3',
      'Fee: 123456.50',
    ];
    for (final value in values) {
      final result = SlipOcrParser.parse('Reference number:\n$value');
      expect(result.referenceNumber, isNull, reason: value);
    }
  });

  test('long account or tax IDs after a field label are not fallback refs', () {
    final result = SlipOcrParser.parse('''
Transfer successful
Amount THB 100.00
21/11/2026
Account ID
ABC0011223344556677
Tax ID
999901234567890123
''');
    expect(result.referenceNumber, isNull);
  });

  test('a grouped standalone code can be used with bank transfer context', () {
    const code = '00012 34567 890123';
    final result = SlipOcrParser.parse('''
Transfer successful
Amount THB 100.00
Date: 21/11/2026
$code
''');
    expect(result.referenceNumber, '0001234567890123');
    expect(SlipOcrParser.parse(code).referenceNumber, isNull);
  });
}
