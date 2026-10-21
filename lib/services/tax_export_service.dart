import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';

class CompanyModel {
  const CompanyModel({
    required this.name,
    required this.taxId,
    required this.branch,
  });

  final String name;
  final String taxId;
  final String branch;
}

class TaxExportService {
  static Future<void> exportRdPrepCsv(List<TransactionModel> txs) async {
    final csv = const ListToCsvConverter().convert([
      for (final entry in txs.indexed) _row(entry.$1 + 1, entry.$2),
    ]);
    final file = await _tempFile('rd_prep', 'csv');
    await file.writeAsString('\uFEFF$csv', encoding: utf8);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<void> exportPrintablePdf(
    List<TransactionModel> txs,
    CompanyModel comp,
    String monthYear,
  ) async {
    final totals = _totals(txs);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('RD Tax Report',
              style:
                  const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Month/Year: $monthYear'),
          pw.Text(
              '${comp.name} | Tax ID: ${comp.taxId} | Branch: ${comp.branch}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Seq',
              'Date',
              'Invoice No.',
              'Name',
              'Tax ID',
              'Branch',
              'Before VAT',
              'VAT',
              'Total'
            ],
            data: [
              for (final entry in txs.indexed) _row(entry.$1 + 1, entry.$2)
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Totals - Before VAT: ${_money(totals.beforeVat)}   VAT: ${_money(totals.vat)}   Total: ${_money(totals.total)}',
            style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ),
    );
    final file = await _tempFile('rd_tax_report', 'pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static List<String> _row(int sequence, TransactionModel tx) {
    final beforeVat = tx.amount - tx.vatAmount;
    return [
      sequence.toString(),
      DateFormat('yyyy-MM-dd').format(tx.date),
      tx.invoiceNo,
      tx.customerName,
      tx.taxId,
      tx.branchCode,
      _money(beforeVat),
      _money(tx.vatAmount),
      _money(tx.amount),
    ];
  }

  static _TaxTotals _totals(List<TransactionModel> txs) => txs.fold(
        const _TaxTotals(),
        (totals, tx) =>
            totals.add(tx.amount - tx.vatAmount, tx.vatAmount, tx.amount),
      );

  static String _money(double value) => value.toStringAsFixed(2);

  static Future<File> _tempFile(String prefix, String extension) async {
    final directory = await getTemporaryDirectory();
    return File(
        '${directory.path}${Platform.pathSeparator}${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension');
  }
}

class _TaxTotals {
  const _TaxTotals({this.beforeVat = 0, this.vat = 0, this.total = 0});

  final double beforeVat;
  final double vat;
  final double total;

  _TaxTotals add(double beforeVat, double vat, double total) => _TaxTotals(
        beforeVat: this.beforeVat + beforeVat,
        vat: this.vat + vat,
        total: this.total + total,
      );
}
