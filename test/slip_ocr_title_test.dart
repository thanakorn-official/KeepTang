import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/services/slip_ocr_parser.dart';

void main() {
  test('prefers a transaction memo to the quoted merchant and payee', () {
    final result = SlipOcrParser.parse('''
ชำระเงินสำเร็จ
ชื่อร้านค้า บริษัท ตัวอย่าง จำกัด
ผู้รับเงิน: คุณ สมชาย
หมายเหตุ: ค่าส่งสินค้า
จำนวนเงิน 299.00 บาท
''');

    expect(result.title, 'ค่าส่งสินค้า');
  });

  test('reads the recipient under a bank heading and omits the account', () {
    final result = SlipOcrParser.parse('''
Transfer successful
From: Mr. Charlie Example
Recipient's   name:
Kasikorn Bank PCL
Mr. Alan Example XXX-X-54321-X
Amount: 900.00 THB
''');

    expect(result.title, 'Mr. Alan Example');
  });

  test('uses the sender name for a slip that says payment received', () {
    final result = SlipOcrParser.parse('''
Payment received
From: Jane Example
To: KeepTang Shop
Amount: THB 999.00
''');

    expect(result.title, 'Jane Example');
  });

  test('reads the second party name on a Thai slip without name labels', () {
    final result = SlipOcrParser.parse('''
โอนเงินสำเร็จ
นาย สมชาย ทดสอบ
XXX-X-01010-X
บริษัท ร้านตัวอย่าง จำกัด
XXX-X-02020-X
500.00 บาท
''');

    expect(result.title, 'บริษัท ร้านตัวอย่าง จำกัด');
  });

  test('keeps a merchant name that contains a digit', () {
    final result = SlipOcrParser.parse('''
Merchant: 7-Eleven
Total: 150.00 THB
''');

    expect(result.title, '7-Eleven');
  });

  test('handles Thai OCR word breaks and decomposed vowels', () {
    final result = SlipOcrParser.parse('''
โอน เงิน ส\u0E4D\u0E32เร็จ
ชื่อ ผู้ รับ โอน
นาย สาธิต ทดสอบ
จำนวนเงิน 349.00 บาท
เลขอ้างอิง: CB001234
''');

    expect(result.title, 'นาย สาธิต ทดสอบ');
    expect(result.looksLikeTransferSlip, isTrue);
  });

  test('does not reuse IDs, bank names or amounts as a transaction title', () {
    final result = SlipOcrParser.parse('''
Transfer successful
Merchant ID: 123456
To: KBank
XXX-X-12345-X
150.00 THB
Reference: GG80230466
''');

    expect(result.title, isNull);
    expect(result.referenceNumber, 'GG80230466');
  });
}
