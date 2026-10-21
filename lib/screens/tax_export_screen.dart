import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/tax_export_service.dart';

class TaxExportScreen extends StatefulWidget {
  const TaxExportScreen(
      {super.key, required this.transactions, required this.company});

  final List<TransactionModel> transactions;
  final CompanyModel company;

  @override
  State<TaxExportScreen> createState() => _TaxExportScreenState();
}

class _TaxExportScreenState extends State<TaxExportScreen> {
  late DateTime _selectedMonth;
  var _type = _TaxType.sales;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  List<TransactionModel> get _transactions => widget.transactions.where((tx) {
        final matchesMonth = tx.date.year == _selectedMonth.year &&
            tx.date.month == _selectedMonth.month;
        final matchesType =
            _type == _TaxType.sales ? !tx.isExpense : tx.isExpense;
        return matchesMonth && matchesType;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final txs = _transactions;
    final beforeVat =
        txs.fold(0.0, (sum, tx) => sum + tx.amount - tx.vatAmount);
    final vat = txs.fold(0.0, (sum, tx) => sum + tx.vatAmount);
    final total = txs.fold(0.0, (sum, tx) => sum + tx.amount);
    final monthYear = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('RD Tax Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_TaxType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tax Type'),
                  items: const [
                    DropdownMenuItem(
                        value: _TaxType.sales, child: Text('Sales')),
                    DropdownMenuItem(
                        value: _TaxType.purchase, child: Text('Purchase')),
                  ],
                  onChanged: (value) => setState(() => _type = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<DateTime>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month / Year'),
                  items: [
                    for (var offset = 0; offset < 24; offset++)
                      DropdownMenuItem(
                        value: DateTime(
                            DateTime.now().year, DateTime.now().month - offset),
                        child: Text(DateFormat('MMMM yyyy').format(DateTime(
                            DateTime.now().year,
                            DateTime.now().month - offset))),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedMonth = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            children: [
              _SummaryCard(label: 'Total Items', value: '${txs.length}'),
              _SummaryCard(
                  label: 'Before VAT', value: beforeVat.toStringAsFixed(2)),
              _SummaryCard(label: 'Total VAT', value: vat.toStringAsFixed(2)),
              _SummaryCard(
                  label: 'Grand Total', value: total.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: txs.isEmpty
                    ? null
                    : () => TaxExportService.exportRdPrepCsv(txs),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export CSV'),
              ),
              OutlinedButton.icon(
                onPressed: txs.isEmpty
                    ? null
                    : () => TaxExportService.exportPrintablePdf(
                        txs, widget.company, monthYear),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Validation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final tx in txs) _ValidationRow(transaction: tx),
        ],
      ),
    );
  }
}

enum _TaxType { sales, purchase }

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              Text(value, style: Theme.of(context).textTheme.titleMedium)
            ],
          ),
        ),
      );
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final invalid = !RegExp(r'^\d{13}$').hasMatch(transaction.taxId) ||
        transaction.branchCode.trim().isEmpty;
    return Card(
      color: invalid ? Theme.of(context).colorScheme.errorContainer : null,
      child: ListTile(
        title: Text(transaction.customerName),
        subtitle: Text(
            '${transaction.invoiceNo} • Tax ID: ${transaction.taxId} • Branch: ${transaction.branchCode}'),
        trailing: Text(transaction.amount.toStringAsFixed(2)),
      ),
    );
  }
}
