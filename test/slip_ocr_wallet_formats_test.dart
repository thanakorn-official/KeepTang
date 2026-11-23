import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/services/slip_ocr_parser.dart';

void main() {
  // Recreate the receipt layouts with synthetic references and account data.
  final cases = [
    (
      name: 'TrueMoney PromptPay',
      text: '''
true money
฿ 58.00
บัญชีทรูมันนี่ ***-***-0001
Prompt Pay
วันที่ทำรายการ 20 มิ.ย. 2569 12:55:08
เลขที่อ้างอิง 50000012345678
สถานที่ทำรายการ ปทุมธานี
''',
      reference: '50000012345678',
      date: DateTime(2026, 6, 20, 12, 55, 8),
      amount: 58.0,
    ),
    (
      name: 'wallet top-up via K PLUS',
      text: '''
เติมเงินผ่าน K PLUS
วันเวลาที่ทำรายการ 03/08/26 | 12:23:40
วอลเล็ทไอดี 16000000000001
หมายเลขรายการ 120000001
หมายเลขอ้างอิง 0000202608030000001
ยอดเงิน ฿ 200.00
ยอดรวม 200.00 บาท
''',
      reference: '0000202608030000001',
      date: DateTime(2026, 8, 3, 12, 23, 40),
      amount: 200.0,
    ),
    (
      name: 'Paotang with a visibly shortened reference',
      text: '''
เป๋าตัง
ทำรายการสำเร็จ
รหัสอ้างอิง f0000001-a01b-4c02-9d03-0012345b...
16 พ.ย. 2569 10:03 น.
G-Wallet ID: **** 0001
ค่าสินค้า/บริการ 79 บาท
สิทธิไทยช่วยไทยพลัส -20 บาท
จำนวนเงินที่ชำระ 59 บาท
''',
      reference: 'f0000001-a01b-4c02-9d03-0012345b…',
      date: DateTime(2026, 11, 16, 10, 3),
      amount: 59.0,
    ),
    (
      name: 'MAKE by KBank with a mixed-case transaction number',
      text: '''
โอนเงินสำเร็จ make by KBank
23 พ.ย. 2569 17:52
xxx-x-x0001-x
จำนวน
70.00 บาท
ค่าธรรมเนียม
0.00 บาท
เลขที่รายการ: 0463000o9cEx0v3uTeSt
''',
      reference: '0463000o9cEx0v3uTeSt',
      date: DateTime(2026, 11, 23, 17, 52),
      amount: 70.0,
    ),
    (
      name: 'Paotang Pay with a short Buddhist year',
      text: '''
ทำรายการสำเร็จ Paotang Pay
08 พ.ย. 69 18:55
G Wallet: *** ******** 0001
จำนวนเงิน 1.60 บาท
ค่าธรรมเนียม 0 บาท
รหัสอ้างอิง 045300000000000000001
''',
      reference: '045300000000000000001',
      date: DateTime(2026, 11, 8, 18, 55),
      amount: 1.6,
    ),
    (
      name: 'K PLUS with the transaction number below its label',
      text: '''
โอนเงินสำเร็จ
23 พ.ย. 69 00:54 น.
จำนวน:
8.91 บาท
ค่าธรรมเนียม:
0.00 บาท
เลขที่รายการ:
016300000001ATF00001
สแกนตรวจสอบสลิป
''',
      reference: '016300000001ATF00001',
      date: DateTime(2026, 11, 23, 0, 54),
      amount: 8.91,
    ),
    (
      name: 'Krungthai with an OCR dash between date and time',
      text: '''
Krungthai
โอนเงินสำเร็จ
รหัสอ้างอิง A4200b70000cd4e8e
จำนวนเงิน 1,000.00 บาท
ค่าธรรมเนียม 0.00 บาท
วันที่ทำรายการ 02 พ.ย. 2569 – 18:13
''',
      reference: 'A4200b70000cd4e8e',
      date: DateTime(2026, 11, 2, 18, 13),
      amount: 1000.0,
    ),
  ];
  for (final slip in cases) {
    test(slip.name, () {
      final result = SlipOcrParser.parse(slip.text);
      expect(result.referenceNumber, slip.reference);
      expect(result.hasTruncatedReference, slip.reference.endsWith('…'));
      expect(result.date, slip.date);
      expect(result.hasTime, isTrue);
      expect(result.amount, slip.amount);
      expect(result.looksLikeTransferSlip, isTrue);
    });
  }

  test('a labelled reading overrides a guessed reference and timestamp', () {
    final guess = SlipOcrParser.parse('''
Bank transfer receipt
Amount THB 200.00
02/08/26 12:23
1600000000000001
''');
    final labelled = SlipOcrParser.parse(cases[1].text);
    final result = SlipOcrParser.merge(guess, labelled);
    expect(result.referenceNumber, cases[1].reference);
    expect(result.date, cases[1].date);
  });

  test('a truncated reference stays partial beside an unrelated number', () {
    final partial = SlipOcrParser.parse(cases[2].text);
    final unrelated = SlipOcrParser.parse('Transaction no: 1234567890123');
    final result = SlipOcrParser.merge(unrelated, partial);
    expect(result.referenceNumber, cases[2].reference);
    expect(result.hasTruncatedReference, isTrue);
  });
}
