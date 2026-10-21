class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String category;
  final String paymentMethod;
  final DateTime? updatedAt;
  final double vatAmount;
  final String taxId;
  final String branchCode;
  final String invoiceNo;
  final String customerName;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.category,
    this.paymentMethod = 'cash',
    this.updatedAt,
    double? vatAmount,
    this.taxId = '',
    this.branchCode = '',
    String? invoiceNo,
    String? customerName,
  })  : vatAmount = vatAmount ?? amount - (amount / 1.07),
        invoiceNo = invoiceNo ?? id,
        customerName = customerName ?? title;

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      isExpense: map['isExpense'] == 1 || map['isExpense'] == true,
      category: map['category'] ?? 'อื่นๆ',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      vatAmount: (map['vatAmount'] as num?)?.toDouble(),
      taxId: map['taxId'] ?? '',
      branchCode: map['branchCode'] ?? '',
      invoiceNo: map['invoiceNo'],
      customerName: map['customerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'isExpense': isExpense ? 1 : 0,
      'category': category,
      'paymentMethod': paymentMethod,
      'vatAmount': vatAmount,
      'taxId': taxId,
      'branchCode': branchCode,
      'invoiceNo': invoiceNo,
      'customerName': customerName,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
