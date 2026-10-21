import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';
import 'guest_service.dart';

class ExportService {
  static Future<void> exportCsv(DateTime selectedMonth, String type) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('guests')
        .doc(GuestService.guestId)
        .collection('transactions')
        .get();
    final transactions = snapshot.docs
        .map((doc) => TransactionModel.fromMap({...doc.data(), 'id': doc.id}))
        .where((tx) =>
            !tx.title.contains('โอน') &&
            !tx.title.contains('รับโอน') &&
            tx.date.year == selectedMonth.year &&
            tx.date.month == selectedMonth.month &&
            (type == 'Sales' ? !tx.isExpense : tx.isExpense))
        .toList();
    final rows = <List<String>>[
      const [
        'Seq',
        'Date',
        'InvoiceNo',
        'CustomerName',
        'TaxID',
        'Branch',
        'BeforeVat',
        'VatAmount',
        'TotalAmount',
      ],
      ..._taxRows(transactions),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}tax_report_${selectedMonth.year}${selectedMonth.month.toString().padLeft(2, '0')}.csv',
    );
    await file.writeAsString('\uFEFF$csv', encoding: utf8);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<void> exportToCsv(List<TransactionModel> transactions) async {
    final rows = <List<dynamic>>[
      [
        'ลำดับที่',
        'วันที่ใบกำกับภาษี',
        'เลขที่ใบกำกับภาษี',
        'ชื่อผู้ซื้อ/ผู้ขาย',
        'เลขประจำตัวผู้เสียภาษี',
        'สาขา',
        'มูลค่าสินค้า/บริการ',
        'จำนวนภาษีมูลค่าเพิ่ม',
        'จำนวนเงินรวม',
      ],
      for (final entry in transactions.indexed) _row(entry.$1 + 1, entry.$2),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}thai_tax_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString('\uFEFF$csv', encoding: utf8);

    await Share.shareXFiles([XFile(file.path)]);
  }

  static List<dynamic> _row(int index, TransactionModel transaction) {
    final total = transaction.amount;
    final beforeVat = total / 1.07;
    final vat = total - beforeVat;

    return [
      index,
      _formatDate(transaction.date),
      transaction.id,
      transaction.title,
      '',
      '',
      beforeVat.toStringAsFixed(2),
      vat.toStringAsFixed(2),
      total.toStringAsFixed(2),
    ];
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static List<List<String>> _taxRows(List<TransactionModel> transactions) {
    final specified = <TransactionModel>[];
    final retailByDate = <DateTime, List<TransactionModel>>{};
    for (final tx in transactions) {
      if (tx.taxId.trim().isEmpty) {
        final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
        (retailByDate[date] ??= []).add(tx);
      } else {
        specified.add(tx);
      }
    }

    final rows = <_TaxRow>[
      for (final tx in specified) _TaxRow.fromTransaction(tx),
      for (final entry in retailByDate.entries)
        _TaxRow.retail(entry.key, entry.value),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return [
      for (var index = 0; index < rows.length; index++)
        rows[index].toCsv(index + 1),
    ];
  }
}

class _TaxRow {
  const _TaxRow({
    required this.date,
    required this.invoiceNo,
    required this.customerName,
    required this.taxId,
    required this.branch,
    required this.beforeVat,
    required this.vatAmount,
    required this.totalAmount,
  });

  factory _TaxRow.fromTransaction(TransactionModel tx) => _TaxRow(
        date: tx.date,
        invoiceNo: tx.invoiceNo,
        customerName: tx.customerName,
        taxId: tx.taxId,
        branch: tx.branchCode,
        beforeVat: tx.amount - tx.vatAmount,
        vatAmount: tx.vatAmount,
        totalAmount: tx.amount,
      );

  factory _TaxRow.retail(DateTime date, List<TransactionModel> txs) => _TaxRow(
        date: date,
        invoiceNo:
            'ABB${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}-001 to 099',
        customerName: 'ลูกค้าทั่วไป (ขายปลีก)',
        taxId: '',
        branch: '',
        beforeVat: txs.fold(0.0, (runningTotal, tx) => runningTotal + tx.amount - tx.vatAmount),
        vatAmount: txs.fold(0.0, (runningTotal, tx) => runningTotal + tx.vatAmount),
        totalAmount: txs.fold(0.0, (runningTotal, tx) => runningTotal + tx.amount),
      );

  final DateTime date;
  final String invoiceNo;
  final String customerName;
  final String taxId;
  final String branch;
  final double beforeVat;
  final double vatAmount;
  final double totalAmount;

  List<String> toCsv(int sequence) => [
        '$sequence',
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        invoiceNo,
        customerName,
        taxId,
        branch,
        beforeVat.toStringAsFixed(2),
        vatAmount.toStringAsFixed(2),
        totalAmount.toStringAsFixed(2),
      ];
}
