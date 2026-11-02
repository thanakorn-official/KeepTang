import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/transaction_model.dart';
import '../main.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _dashboardScrollController = ScrollController();
  late final Stream<QuerySnapshot> _transactionsStream;
  QuerySnapshot? _cachedSnapshot;
  List<TransactionModel> _cachedParsedTransactions = [];
  List<TransactionModel> _cachedAvailableTransactions = [];
  final Map<String, TransactionModel> _cachedTransactionsById = {};
  String? _cachedPendingDeleteKey;
  List<TransactionModel>? _cachedAccountSource;
  String? _cachedAccountScope;
  List<TransactionModel> _cachedAccountTransactions = [];
  List<TransactionModel>? _cachedGroupSource;
  String? _cachedGroupType;
  List<TransactionModel> _cachedGroupTransactions = [];
  List<TransactionModel>? _cachedVisibleSource;
  String? _cachedVisibleKey;
  List<TransactionModel> _cachedVisibleTransactions = [];
  List<dynamic> _cachedVisibleListItems = [];
  List<TransactionModel> _cachedFilteredScopeTransactions = [];
  int _selectedPaymentPage = 0;
  double _accountSwipeDistance = 0;
  int _overviewSlideDirection = 1;
  String? _selectedChartCategory;
  String? _focusedCategoryAtPointerDown;

  final Map<String, IconData> _categoryIcons = {
    'อาหาร': Icons.restaurant,
    'เดินทาง': Icons.directions_car,
    'ช้อปปิ้ง': Icons.shopping_bag,
    'บิล/ค่าใช้จ่าย': Icons.receipt,
    'เงินเดือน/รายรับ': Icons.account_balance_wallet,
    'ความบันเทิง': Icons.movie,
    'สุขภาพ/พยาบาล': Icons.medical_services,
    'ที่อยู่อาศัย': Icons.home,
    'การศึกษา': Icons.school,
    'การลงทุน': Icons.trending_up,
    'อื่นๆ': Icons.category,
  };

  final Map<String, Color> _categoryColors = {
    'อาหาร': Colors.orange,
    'เดินทาง': Colors.blue,
    'ช้อปปิ้ง': Colors.purple,
    'บิล/ค่าใช้จ่าย': Colors.redAccent,
    'เงินเดือน/รายรับ': Colors.green,
    'ความบันเทิง': Colors.pink,
    'สุขภาพ/พยาบาล': Colors.cyan,
    'ที่อยู่อาศัย': Colors.brown,
    'การศึกษา': Colors.indigo,
    'การลงทุน': Colors.teal,
    'อื่นๆ': Colors.blueGrey,
  };

  final Map<String, IconData> _paymentIcons = {
    'cash': Icons.payments_outlined,
    'promptpay': Icons.account_balance_wallet_outlined,
    'truemoney': Icons.account_balance_wallet,
    'paotang': Icons.wallet,
  };

  final Map<String, Color> _paymentColors = {
    'cash': Colors.green,
    'promptpay': Colors.blue,
    'truemoney': Colors.orange,
    'paotang': Colors.lightBlue,
  };

  final List<Color> _availableColors = [
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.redAccent,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
    Colors.brown,
    Colors.blueGrey,
  ];

  final List<IconData> _selectableCategoryIcons = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.receipt,
    Icons.account_balance_wallet,
    Icons.movie,
    Icons.medical_services,
    Icons.home,
    Icons.school,
    Icons.trending_up,
    Icons.pets,
    Icons.fitness_center,
    Icons.flight,
    Icons.sports_esports,
    Icons.phone_android,
    Icons.build,
    Icons.card_giftcard,
    Icons.category,
  ];

  final List<IconData> _selectablePaymentIcons = [
    Icons.payments_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    Icons.wallet,
    Icons.credit_card,
    Icons.account_balance,
    Icons.qr_code_scanner,
    Icons.contactless,
    Icons.currency_exchange,
    Icons.monetization_on,
    Icons.card_membership,
    Icons.store,
  ];

  final Set<String> _pendingDeleteIds = {};
  final Set<String> _selectedTransactionIds = {};

  CollectionReference get _transactionsCollection => FirebaseFirestore.instance
      .collection('guests')
      .doc(GuestService.guestId)
      .collection('transactions');

  String _groupType = 'monthly';
  String _sortOrder = 'newest';

  Set<String> _selectedTypes = {'income', 'expense'};
  Set<String> _selectedCategories = {};
  Set<String> _selectedPayments = {};
  bool _categoryFilterActive = false;
  bool _paymentFilterActive = false;

  @override
  void initState() {
    super.initState();
    _transactionsStream =
        _transactionsCollection.orderBy('date', descending: true).snapshots();
    _loadCustomSettings();
  }

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    super.dispose();
  }

  void _selectPaymentAccount(int index, {int slideDirection = 1}) {
    final payments = _paymentIcons.keys.toList();
    final targetIndex = index.clamp(0, payments.length).toInt();
    if (targetIndex == _selectedPaymentPage) return;

    setState(() {
      _selectedPaymentPage = targetIndex;
      _overviewSlideDirection = slideDirection;
      _selectedChartCategory = null;
      _selectedTransactionIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dashboardScrollController.hasClients) {
        _dashboardScrollController.jumpTo(0);
      }
    });
  }

  void _handleAccountSwipeEnd(List<String> payments) {
    if (_accountSwipeDistance.abs() < 40) return;
    final direction = _accountSwipeDistance < 0 ? 1 : -1;
    _selectPaymentAccount(
      _selectedPaymentPage + direction,
      slideDirection: direction,
    );
    _accountSwipeDistance = 0;
  }

  Widget _buildAccountOverview({
    required String? paymentScope,
    required List<TransactionModel> accountTransactions,
    required List<TransactionModel> chartTransactions,
    required double income,
    required double expense,
    required double balance,
    required double currentBalance,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _accountSwipeDistance = 0,
      onHorizontalDragUpdate: (details) {
        _accountSwipeDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (_) =>
          _handleAccountSwipeEnd(_paymentIcons.keys.toList()),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: Offset(_overviewSlideDirection * 0.24, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: Column(
          key: ValueKey<String>('overview-${paymentScope ?? 'all'}'),
          children: [
            const SizedBox(height: 24),
            _buildPieChart(
              chartTransactions,
              currentBalance: currentBalance,
            ),
            if (accountTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(T.get('noData'),
                    style: const TextStyle(color: Colors.grey)),
              ),
            _buildSummaryRow(income, expense, balance),
            const Divider(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _getDefaultCategoryIcon(String cat) {
    if (cat == 'transfer') return Icons.swap_horiz;
    switch (cat) {
      case 'อาหาร':
        return Icons.restaurant;
      case 'เดินทาง':
        return Icons.directions_car;
      case 'ช้อปปิ้ง':
        return Icons.shopping_bag;
      case 'บิล/ค่าใช้จ่าย':
        return Icons.receipt;
      case 'เงินเดือน/รายรับ':
        return Icons.account_balance_wallet;
      case 'ความบันเทิง':
        return Icons.movie;
      case 'สุขภาพ/พยาบาล':
        return Icons.medical_services;
      case 'ที่อยู่อาศัย':
        return Icons.home;
      case 'การศึกษา':
        return Icons.school;
      case 'การลงทุน':
        return Icons.trending_up;
      case 'อื่นๆ':
        return Icons.category;
      case 'ไม่ระบุ':
        return Icons.help_outline;
      default:
        return Icons.label;
    }
  }

  Color _getDefaultCategoryColor(String cat) {
    if (cat == 'transfer') return Colors.blueGrey;
    switch (cat) {
      case 'อาหาร':
        return Colors.orange;
      case 'เดินทาง':
        return Colors.blue;
      case 'ช้อปปิ้ง':
        return Colors.purple;
      case 'บิล/ค่าใช้จ่าย':
        return Colors.redAccent;
      case 'เงินเดือน/รายรับ':
        return Colors.green;
      case 'ความบันเทิง':
        return Colors.pink;
      case 'สุขภาพ/พยาบาล':
        return Colors.cyan;
      case 'ที่อยู่อาศัย':
        return Colors.brown;
      case 'การศึกษา':
        return Colors.indigo;
      case 'การลงทุน':
        return Colors.teal;
      case 'อื่นๆ':
        return Colors.blueGrey;
      case 'ไม่ระบุ':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getDefaultPaymentIcon(String pay) {
    switch (pay) {
      case 'cash':
        return Icons.payments_outlined;
      case 'promptpay':
        return Icons.account_balance_wallet_outlined;
      case 'truemoney':
        return Icons.account_balance_wallet;
      case 'paotang':
        return Icons.wallet;
      case 'ไม่ระบุ':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment;
    }
  }

  Color _getDefaultPaymentColor(String pay) {
    switch (pay) {
      case 'cash':
        return Colors.green;
      case 'promptpay':
        return Colors.blue;
      case 'truemoney':
        return Colors.orange;
      case 'paotang':
        return Colors.lightBlue;
      case 'ไม่ระบุ':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _loadCustomSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final customCats = prefs.getString('app_categories_list');
    if (customCats != null) {
      final List<dynamic> decoded = jsonDecode(customCats);
      setState(() {
        _categoryIcons.clear();
        _categoryColors.clear();
        for (var item in decoded) {
          final cat = item.toString();
          _categoryIcons[cat] = _getDefaultCategoryIcon(cat);
          _categoryColors[cat] = _getDefaultCategoryColor(cat);
        }
      });
    }

    final catIconsStr = prefs.getString('app_category_icon_codes');
    if (catIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catIconsStr);
      decoded.forEach((k, v) {
        if (_categoryIcons.containsKey(k)) {
          _categoryIcons[k] = _selectableCategoryIcons.firstWhere(
            (icon) => icon.codePoint == (v as int),
            orElse: () => _getDefaultCategoryIcon(k),
          );
        }
      });
    }

    final catColorsStr = prefs.getString('app_category_color_values');
    if (catColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catColorsStr);
      decoded.forEach((k, v) {
        if (_categoryColors.containsKey(k)) {
          _categoryColors[k] = Color(v as int);
        }
      });
    }

    final customPayments = prefs.getString('app_payments_list');
    if (customPayments != null) {
      final List<dynamic> decoded = jsonDecode(customPayments);
      setState(() {
        _paymentIcons.clear();
        _paymentColors.clear();
        for (var item in decoded) {
          final pay = item.toString();
          _paymentIcons[pay] = _getDefaultPaymentIcon(pay);
          _paymentColors[pay] = _getDefaultPaymentColor(pay);
        }
      });
    }

    final payIconsStr = prefs.getString('app_payment_icon_codes');
    if (payIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payIconsStr);
      decoded.forEach((k, v) {
        if (_paymentIcons.containsKey(k)) {
          _paymentIcons[k] = _selectablePaymentIcons.firstWhere(
            (icon) => icon.codePoint == (v as int),
            orElse: () => _getDefaultPaymentIcon(k),
          );
        }
      });
    }

    final payColorsStr = prefs.getString('app_payment_color_values');
    if (payColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payColorsStr);
      decoded.forEach((k, v) {
        if (_paymentColors.containsKey(k)) {
          _paymentColors[k] = Color(v as int);
        }
      });
    }
  }

  Color _colorOf(String category) {
    if (category == 'transfer') return Colors.blueGrey;
    if (!_categoryColors.containsKey(category)) return Colors.red;
    return _categoryColors[category] ?? Colors.blueGrey;
  }

  IconData _iconOf(String category) {
    if (category == 'transfer') return Icons.swap_horiz;
    if (!_categoryIcons.containsKey(category)) return Icons.help_outline;
    return _categoryIcons[category] ?? _getDefaultCategoryIcon(category);
  }

  IconData _paymentIconOf(String payment) {
    if (!_paymentIcons.containsKey(payment)) return Icons.help_outline;
    return _paymentIcons[payment] ?? _getDefaultPaymentIcon(payment);
  }

  Color _paymentColorOf(String payment) {
    if (!_paymentColors.containsKey(payment)) return Colors.red;
    return _paymentColors[payment] ?? _getDefaultPaymentColor(payment);
  }

  Future<void> _showQuickAddCategoryDialog(
      StateSetter setModalState, ValueChanged<String> onAdded) async {
    final controller = TextEditingController();
    IconData selectedIcon = _selectableCategoryIcons.first;
    Color selectedColor = _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(T.get('addCategory')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: T.get('categoryName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('selectIcon'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectableCategoryIcons.map((icon) {
                      final isSelected =
                          selectedIcon.codePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('pickColor'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected =
                          selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty && !_categoryIcons.containsKey(text)) {
                    setState(() {
                      _categoryIcons[text] = selectedIcon;
                      _categoryColors[text] = selectedColor;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_categories_list',
                        jsonEncode(_categoryIcons.keys.toList()));
                    await prefs.setString(
                        'app_category_icon_codes',
                        jsonEncode(_categoryIcons
                            .map((k, v) => MapEntry(k, v.codePoint))));
                    await prefs.setString(
                        'app_category_color_values',
                        jsonEncode(_categoryColors
                            .map((k, v) => MapEntry(k, v.toARGB32()))));

                    onAdded(text);
                    setModalState(() {});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showQuickAddPaymentDialog(
      StateSetter setModalState, ValueChanged<String> onAdded) async {
    final controller = TextEditingController();
    IconData selectedIcon = _selectablePaymentIcons.first;
    Color selectedColor = _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(T.get('addPayment')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: T.get('paymentName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('selectIcon'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectablePaymentIcons.map((icon) {
                      final isSelected =
                          selectedIcon.codePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('pickColor'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected =
                          selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty && !_paymentIcons.containsKey(text)) {
                    setState(() {
                      _paymentIcons[text] = selectedIcon;
                      _paymentColors[text] = selectedColor;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_payments_list',
                        jsonEncode(_paymentIcons.keys.toList()));
                    await prefs.setString(
                        'app_payment_icon_codes',
                        jsonEncode(_paymentIcons
                            .map((k, v) => MapEntry(k, v.codePoint))));
                    await prefs.setString(
                        'app_payment_color_values',
                        jsonEncode(_paymentColors
                            .map((k, v) => MapEntry(k, v.toARGB32()))));

                    onAdded(text);
                    setModalState(() {});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferSheet(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    String fromPayment = _paymentIcons.keys.first;
    String toPayment = _paymentIcons.keys.length > 1
        ? _paymentIcons.keys.elementAt(1)
        : _paymentIcons.keys.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(T.get('transferBetweenAccounts'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                            labelText: T.get('amountLabel'),
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: fromPayment,
                      decoration: InputDecoration(
                          labelText: T.get('fromAccount'),
                          border: const OutlineInputBorder()),
                      items: _paymentIcons.keys.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              Icon(_paymentIconOf(method),
                                  color: _paymentColorOf(method), size: 20),
                              const SizedBox(width: 8),
                              Text(T.get(method)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => fromPayment = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: toPayment,
                      decoration: InputDecoration(
                          labelText: T.get('toAccount'),
                          border: const OutlineInputBorder()),
                      items: _paymentIcons.keys.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              Icon(_paymentIconOf(method),
                                  color: _paymentColorOf(method), size: 20),
                              const SizedBox(width: 8),
                              Text(T.get(method)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => toPayment = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                            labelText: T.get('optionalNote'),
                            border: const OutlineInputBorder())),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          if (amountController.text.isEmpty ||
                              fromPayment == toPayment) {
                            return;
                          }

                          _transactionsCollection.add({
                            'title': noteController.text.isNotEmpty
                                ? noteController.text
                                : '${T.get('transferredOut')} ${T.get(toPayment)}',
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'date': DateTime.now().toIso8601String(),
                            'isExpense': 1,
                            'category': 'transfer',
                            'paymentMethod': fromPayment,
                          });

                          _transactionsCollection.add({
                            'title': noteController.text.isNotEmpty
                                ? noteController.text
                                : '${T.get('transferredIn')} ${T.get(fromPayment)}',
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'date': DateTime.now().toIso8601String(),
                            'isExpense': 0,
                            'category': 'transfer',
                            'paymentMethod': toPayment,
                          });

                          Navigator.pop(ctx);
                        },
                        child: Text(T.get('confirmTransfer'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat('#,##0.00').format(amount)} ฿',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(double income, double expense, double balance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryItem(T.get('totalIncome'), income, Colors.green),
        _buildSummaryItem(
            T.get('balance'), balance, balance >= 0 ? Colors.blue : Colors.red),
        _buildSummaryItem(T.get('totalExpense'), expense, Colors.redAccent),
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> items, IconData icon,
      ValueChanged<String?> onChanged,
      {bool isActive = false}) {
    final currentValue = items.contains(value) ? value : items.first;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? colors.primaryContainer
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? colors.primary : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isActive ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isDense: true,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 360,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurfaceVariant),
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map((val) =>
                      DropdownMenuItem(value: val, child: Text(T.get(val))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    int selectedCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 1,
              )),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isActive ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        isActive ? Theme.of(context).colorScheme.primary : null,
                  )),
              const SizedBox(width: 4),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$selectedCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down,
                  size: 18,
                  color:
                      isActive ? Theme.of(context).colorScheme.primary : null),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterPanel() {
    final categoryItems = <String, String>{
      for (final category in _categoryIcons.keys) category: T.get(category),
      'transfer': T.get('transfer'),
    };
    final paymentItems = <String, String>{
      for (final payment in _paymentIcons.keys) payment: T.get(payment),
    };
    var draftTypes = Set<String>.from(_selectedTypes);
    var draftCategories = Set<String>.from(_selectedCategories);
    var draftPayments = Set<String>.from(_selectedPayments);
    var draftCategoryFilterActive = _categoryFilterActive;
    var draftPaymentFilterActive = _paymentFilterActive;
    var showAllCategories = false;
    var showAllPayments = false;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setPanelState) {
          final colors = Theme.of(sheetContext).colorScheme;

          Widget selectionSection({
            required String title,
            required Map<String, String> items,
            required Set<String> selectedItems,
            required bool filterActive,
            required bool showAll,
            required ValueChanged<bool> onShowAllChanged,
            required ValueChanged<bool> onFilterActiveChanged,
            required IconData Function(String key) iconForItem,
            required Color Function(String key) colorForItem,
            required ValueChanged<Set<String>> onSelectionChanged,
          }) {
            final visibleItems = showAll
                ? items.entries.toList()
                : items.entries.take(5).toList();
            final allSelected =
                items.isNotEmpty && selectedItems.length == items.length;
            final selectedCount = !filterActive || allSelected
                ? items.length
                : selectedItems.length;
            final optionWidth =
                (MediaQuery.sizeOf(sheetContext).width - 50) / 2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Text(
                            !filterActive || allSelected
                                ? T.get('all')
                                : '$selectedCount ${T.get('selected')}',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          onSelectionChanged(allSelected
                              ? <String>{}
                              : Set<String>.from(items.keys));
                          onFilterActiveChanged(true);
                        },
                        child:
                            Text(T.get(allSelected ? 'clearAll' : 'selectAll')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in visibleItems)
                        SizedBox(
                          width: optionWidth,
                          child: Builder(builder: (context) {
                            final isSelected =
                                selectedItems.contains(entry.key);
                            final itemColor = colorForItem(entry.key);
                            return Material(
                              color: isSelected
                                  ? colors.primaryContainer
                                      .withValues(alpha: 0.5)
                                  : colors.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.45)
                                      : colors.outlineVariant
                                          .withValues(alpha: 0.55),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  final next = Set<String>.from(selectedItems);
                                  if (next.contains(entry.key)) {
                                    next.remove(entry.key);
                                  } else {
                                    next.add(entry.key);
                                  }
                                  onSelectionChanged(next);
                                  onFilterActiveChanged(true);
                                },
                                child: SizedBox(
                                  height: 62,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: itemColor.withValues(
                                                alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(iconForItem(entry.key),
                                              size: 18, color: itemColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(sheetContext)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                    color: colors.onSurface,
                                                    height: 1.15),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 18,
                                          color: isSelected
                                              ? colors.primary
                                              : colors.outlineVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                  if (items.length > 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => onShowAllChanged(!showAll),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(T.get(showAll ? 'showLess' : 'showAll')),
                            const SizedBox(width: 4),
                            Icon(
                              showAll
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(T.get('filters'),
                              style:
                                  Theme.of(sheetContext).textTheme.titleLarge),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                          tooltip: T.get('close'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      children: [
                        selectionSection(
                          title: T.get('filterType'),
                          items: {
                            'income': T.get('income'),
                            'expense': T.get('expense'),
                          },
                          selectedItems: draftTypes,
                          filterActive: true,
                          showAll: true,
                          onShowAllChanged: (_) {},
                          onFilterActiveChanged: (_) {},
                          iconForItem: (type) => type == 'income'
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          colorForItem: (type) =>
                              type == 'income' ? Colors.green : Colors.red,
                          onSelectionChanged: (value) =>
                              setPanelState(() => draftTypes = value),
                        ),
                        selectionSection(
                          title: T.get('filterCategory'),
                          items: categoryItems,
                          selectedItems: draftCategories,
                          filterActive: draftCategoryFilterActive,
                          showAll: showAllCategories,
                          onShowAllChanged: (value) =>
                              setPanelState(() => showAllCategories = value),
                          onFilterActiveChanged: (value) => setPanelState(
                              () => draftCategoryFilterActive = value),
                          iconForItem: _iconOf,
                          colorForItem: _colorOf,
                          onSelectionChanged: (value) =>
                              setPanelState(() => draftCategories = value),
                        ),
                        if (_selectedPaymentPage == 0)
                          selectionSection(
                            title: T.get('filterPayment'),
                            items: paymentItems,
                            selectedItems: draftPayments,
                            filterActive: draftPaymentFilterActive,
                            showAll: showAllPayments,
                            onShowAllChanged: (value) =>
                                setPanelState(() => showAllPayments = value),
                            onFilterActiveChanged: (value) => setPanelState(
                                () => draftPaymentFilterActive = value),
                            iconForItem: _paymentIconOf,
                            colorForItem: _paymentColorOf,
                            onSelectionChanged: (value) =>
                                setPanelState(() => draftPayments = value),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedTypes = {'income', 'expense'};
                                  _selectedCategories.clear();
                                  _selectedPayments.clear();
                                  _categoryFilterActive = false;
                                  _paymentFilterActive = false;
                                });
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: Text(T.get('clearFilters')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTypes = draftTypes;
                                  _selectedCategories = draftCategories;
                                  _selectedPayments = draftPayments;
                                  _categoryFilterActive =
                                      draftCategoryFilterActive;
                                  _paymentFilterActive =
                                      draftPaymentFilterActive;
                                });
                                Navigator.pop(sheetContext);
                              },
                              child: Text(T.get('apply')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    final activeSelections =
        (_selectedTypes.length == 2 ? 0 : _selectedTypes.length) +
            (_categoryFilterActive ? 1 : 0) +
            (_selectedPaymentPage == 0 && _paymentFilterActive ? 1 : 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildDropdown(
            _groupType,
            ['daily', 'weekly', 'monthly', 'yearly', 'none'],
            Icons.date_range,
            (value) => setState(() => _groupType = value!),
            isActive: _groupType != 'monthly',
          ),
          _buildDropdown(
            _sortOrder,
            ['newest', 'oldest', 'highest', 'lowest'],
            Icons.sort,
            (value) => setState(() => _sortOrder = value!),
            isActive: _sortOrder != 'newest',
          ),
          _buildMultiSelectButton(
            label: T.get('filters'),
            icon: Icons.tune,
            isActive: activeSelections > 0,
            selectedCount: activeSelections,
            onTap: _showFilterPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField({
    required String selected,
    required ValueChanged<String?> onChanged,
    required StateSetter setModalState,
    bool outlined = false,
  }) {
    List<DropdownMenuItem<String>> items = _categoryIcons.keys.map((cat) {
      return DropdownMenuItem(
        value: cat,
        child: Row(
          children: [
            Icon(_iconOf(cat), color: _colorOf(cat), size: 20),
            const SizedBox(width: 8),
            Text(T.get(cat)),
          ],
        ),
      );
    }).toList();

    if (selected == 'transfer') {
      items.add(
        DropdownMenuItem(
          value: 'transfer',
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(T.get('transfer')),
            ],
          ),
        ),
      );
    }

    final selectedValue =
        (_categoryIcons.containsKey(selected) || selected == 'transfer')
            ? selected
            : _categoryIcons.keys.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: InputDecoration(
              labelText: T.get('categoryLabel'),
              border: outlined ? const OutlineInputBorder() : null,
            ),
            items: items,
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 28),
          color: Theme.of(context).colorScheme.primary,
          tooltip: T.get('addCategory'),
          onPressed: () {
            _showQuickAddCategoryDialog(setModalState, (newCat) {
              onChanged(newCat);
            });
          },
        ),
      ],
    );
  }

  Widget _buildPaymentField({
    required String selected,
    required ValueChanged<String?> onChanged,
    required StateSetter setModalState,
    bool outlined = false,
  }) {
    List<DropdownMenuItem<String>> paymentItems =
        _paymentIcons.keys.map((method) {
      return DropdownMenuItem(
        value: method,
        child: Row(
          children: [
            Icon(_paymentIconOf(method),
                color: _paymentColorOf(method), size: 20),
            const SizedBox(width: 8),
            Text(T.get(method)),
          ],
        ),
      );
    }).toList();

    final selectedValue = _paymentIcons.containsKey(selected)
        ? selected
        : _paymentIcons.keys.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: InputDecoration(
              labelText: T.get('paymentMethodLabel'),
              border: outlined ? const OutlineInputBorder() : null,
            ),
            items: paymentItems,
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 28),
          color: Theme.of(context).colorScheme.primary,
          tooltip: T.get('addPayment'),
          onPressed: () {
            _showQuickAddPaymentDialog(setModalState, (newPay) {
              onChanged(newPay);
            });
          },
        ),
      ],
    );
  }

  void _showEditDialog(TransactionModel tx) {
    final titleController = TextEditingController(text: tx.title);
    final amountController = TextEditingController(text: tx.amount.toString());
    String selectedCategory =
        (_categoryIcons.containsKey(tx.category) || tx.category == 'transfer')
            ? tx.category
            : _categoryIcons.keys.first;
    String selectedPaymentMethod = _paymentIcons.containsKey(tx.paymentMethod)
        ? tx.paymentMethod
        : _paymentIcons.keys.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(T.get('edit')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleController,
                      decoration:
                          InputDecoration(labelText: T.get('titleLabel'))),
                  const SizedBox(height: 16),
                  TextField(
                      controller: amountController,
                      decoration:
                          InputDecoration(labelText: T.get('amountLabel')),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildCategoryField(
                    selected: selectedCategory,
                    setModalState: setStateDialog,
                    onChanged: (val) =>
                        setStateDialog(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentField(
                    selected: selectedPaymentMethod,
                    setModalState: setStateDialog,
                    onChanged: (val) =>
                        setStateDialog(() => selectedPaymentMethod = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () {
                  _transactionsCollection.doc(tx.id).update({
                    'title': titleController.text,
                    'amount':
                        double.tryParse(amountController.text) ?? tx.amount,
                    'category': selectedCategory,
                    'paymentMethod': selectedPaymentMethod,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });
                  Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleTransactionSelection(TransactionModel tx) {
    setState(() {
      if (!_selectedTransactionIds.add(tx.id)) {
        _selectedTransactionIds.remove(tx.id);
      }
      _selectedChartCategory = null;
    });
  }

  void _clearTransactionSelection() {
    if (_selectedTransactionIds.isEmpty) return;
    setState(() {
      _selectedTransactionIds.clear();
      _selectedChartCategory = null;
    });
  }

  void _showBulkEditSheet() {
    if (_selectedTransactionIds.isEmpty) return;
    var selectedCategory = _categoryIcons.keys.first;
    var selectedPayment = _paymentIcons.keys.first;
    var changeCategory = false;
    var changePayment = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.viewPaddingOf(sheetContext).bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${T.get('editSelected')} (${_selectedTransactionIds.length})',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(T.get('changeCategory')),
                  value: changeCategory,
                  onChanged: (value) =>
                      setSheetState(() => changeCategory = value ?? false),
                ),
                if (changeCategory)
                  _buildCategoryField(
                    selected: selectedCategory,
                    setModalState: setSheetState,
                    onChanged: (value) => setSheetState(
                        () => selectedCategory = value ?? selectedCategory),
                    outlined: true,
                  ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(T.get('changePayment')),
                  value: changePayment,
                  onChanged: (value) =>
                      setSheetState(() => changePayment = value ?? false),
                ),
                if (changePayment)
                  _buildPaymentField(
                    selected: selectedPayment,
                    setModalState: setSheetState,
                    onChanged: (value) => setSheetState(
                        () => selectedPayment = value ?? selectedPayment),
                    outlined: true,
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(T.get('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: !changeCategory && !changePayment
                            ? null
                            : () async {
                                final batch =
                                    FirebaseFirestore.instance.batch();
                                final updatedAt =
                                    DateTime.now().toIso8601String();
                                for (final id
                                    in _selectedTransactionIds.toList()) {
                                  final updates = <String, dynamic>{
                                    'updatedAt': updatedAt,
                                  };
                                  if (changeCategory) {
                                    updates['category'] = selectedCategory;
                                  }
                                  if (changePayment) {
                                    updates['paymentMethod'] = selectedPayment;
                                  }
                                  batch.update(
                                      _transactionsCollection.doc(id), updates);
                                }
                                try {
                                  await batch.commit();
                                  if (mounted) {
                                    setState(
                                        () => _selectedTransactionIds.clear());
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (_) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(T.get('saveError'))),
                                    );
                                  }
                                }
                              },
                        child: Text(T.get('save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isExpense = true;
    String selectedCategory = _categoryIcons.keys.first;
    String selectedPaymentMethod = _paymentIcons.keys.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(T.get('addTransaction'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                            labelText: T.get('titleLabel'),
                            border: const OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                            labelText: T.get('amountLabel'),
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildCategoryField(
                      selected: selectedCategory,
                      outlined: true,
                      setModalState: setModalState,
                      onChanged: (val) =>
                          setModalState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentField(
                      selected: selectedPaymentMethod,
                      outlined: true,
                      setModalState: setModalState,
                      onChanged: (val) =>
                          setModalState(() => selectedPaymentMethod = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(T.get('typeLabel'),
                            style: const TextStyle(fontSize: 16)),
                        ChoiceChip(
                            label: Text(T.get('expense')),
                            selected: isExpense,
                            onSelected: (_) =>
                                setModalState(() => isExpense = true)),
                        ChoiceChip(
                            label: Text(T.get('income')),
                            selected: !isExpense,
                            onSelected: (_) =>
                                setModalState(() => isExpense = false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          if (titleController.text.isEmpty ||
                              amountController.text.isEmpty) {
                            return;
                          }
                          _transactionsCollection.add({
                            'title': titleController.text,
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'date': DateTime.now().toIso8601String(),
                            'isExpense': isExpense ? 1 : 0,
                            'category': selectedCategory,
                            'paymentMethod': selectedPaymentMethod,
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(T.get('save'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isMatchFilters(TransactionModel tx, {String? paymentScope}) {
    if (tx.isExpense && !_selectedTypes.contains('expense')) {
      return false;
    }
    if (!tx.isExpense && !_selectedTypes.contains('income')) {
      return false;
    }

    if (_categoryFilterActive && !_selectedCategories.contains(tx.category)) {
      return false;
    }

    if (paymentScope == null &&
        _paymentFilterActive &&
        !_selectedPayments.contains(tx.paymentMethod)) {
      return false;
    }

    if (paymentScope != null && tx.paymentMethod != paymentScope) {
      return false;
    }

    return true;
  }

  List<TransactionModel> _filterAndSort(
    List<TransactionModel> transactions, {
    String? paymentScope,
  }) {
    final result = transactions
        .where((tx) => _isMatchFilters(tx, paymentScope: paymentScope))
        .toList();

    result.sort((a, b) {
      switch (_sortOrder) {
        case 'newest':
          return b.date.compareTo(a.date);
        case 'oldest':
          return a.date.compareTo(b.date);
        case 'highest':
          return b.amount.compareTo(a.amount);
        case 'lowest':
          return a.amount.compareTo(b.amount);
        default:
          return 0;
      }
    });
    return result;
  }

  String _groupKey(TransactionModel tx) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
        return DateFormat('dd/MM/yyyy', locale).format(tx.date);
      case 'weekly':
        final startOfWeek =
            tx.date.subtract(Duration(days: tx.date.weekday - 1));
        return DateFormat('dd/MM/yyyy', locale).format(startOfWeek);
      case 'monthly':
        return DateFormat('MM/yyyy', locale).format(tx.date);
      case 'yearly':
        return DateFormat('yyyy', locale).format(tx.date);
      default:
        return DateFormat('yyyy', locale).format(tx.date);
    }
  }

  int _compareGroupKeys(String a, String b) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
      case 'weekly':
        final format = DateFormat('dd/MM/yyyy', locale);
        return format.parse(b).compareTo(format.parse(a));
      case 'monthly':
        final format = DateFormat('MM/yyyy', locale);
        return format.parse(b).compareTo(format.parse(a));
      case 'yearly':
        return int.parse(b).compareTo(int.parse(a));
      default:
        return 0;
    }
  }

  String _groupHeader(String key) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
        return '${T.get('date_prefix')} $key';
      case 'weekly':
        final start = DateFormat('dd/MM/yyyy', locale).parse(key);
        final end = start.add(const Duration(days: 6));
        return '${T.get('week_prefix')} $key - ${DateFormat('dd/MM/yyyy', locale).format(end)}';
      case 'monthly':
        return '${T.get('month_prefix')} $key';
      case 'yearly':
        return '${T.get('year_prefix')} $key';
      default:
        return key;
    }
  }

  List<dynamic> _buildListItems(List<TransactionModel> transactions) {
    if (_groupType == 'none' || transactions.isEmpty) return transactions;
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      grouped.putIfAbsent(_groupKey(tx), () => []).add(tx);
    }
    var sortedKeys = grouped.keys.toList()..sort(_compareGroupKeys);
    if (_sortOrder == 'oldest') sortedKeys = sortedKeys.reversed.toList();

    final List<dynamic> items = [];
    for (final key in sortedKeys) {
      items.add(_groupHeader(key));
      items.addAll(grouped[key]!);
    }
    return items;
  }

  Widget _buildPieChart(
    List<TransactionModel> transactions, {
    required double currentBalance,
  }) {
    final Map<String, double> categoryTotals = {};
    for (final tx in transactions) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0.0) + tx.amount;
    }
    final totalSum = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final selectedCategory = categoryTotals.containsKey(_selectedChartCategory)
        ? _selectedChartCategory
        : null;
    final selectedTotal =
        selectedCategory == null ? null : categoryTotals[selectedCategory];
    final selectedPercentage = selectedTotal == null || totalSum == 0
        ? 0.0
        : selectedTotal / totalSum * 100;

    final sections = categoryTotals.entries.map((entry) {
      final percentage = totalSum > 0 ? (entry.value / totalSum * 100) : 0.0;
      final isSelected = entry.key == selectedCategory;
      final isDimmed = selectedCategory != null && !isSelected;
      return PieChartSectionData(
        color: _colorOf(entry.key).withValues(alpha: isDimmed ? 0.2 : 1),
        value: entry.value,
        title: '',
        radius: isSelected ? 72 : 65,
        badgeWidget: (selectedCategory == null && percentage >= 6.0) ||
                (isSelected && percentage >= 6.0)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconOf(entry.key), color: Colors.white, size: 18),
                  const SizedBox(height: 2),
                  Text('${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              )
            : const SizedBox.shrink(),
        badgePositionPercentageOffset: 0.5,
      );
    }).toList();
    if (totalSum <= 0) {
      sections.clear();
      sections.add(
        PieChartSectionData(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          value: 1,
          title: '',
          radius: 65,
        ),
      );
    }

    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final centerContent = selectedCategory == null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                T.get(_selectedTransactionIds.isNotEmpty
                    ? 'selectedNet'
                    : 'currentBalance'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat.currency(
                    locale: locale,
                    symbol: '฿',
                    decimalDigits: 2,
                  ).format(currentBalance),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconOf(selectedCategory),
                  size: 16, color: _colorOf(selectedCategory)),
              const SizedBox(height: 2),
              Text(
                T.get(selectedCategory),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat.currency(
                    locale: locale,
                    symbol: '฿',
                    decimalDigits: 2,
                  ).format(selectedTotal),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${selectedPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          );

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 54,
                  sections: sections,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (index == null ||
                          index < 0 ||
                          index >= categoryTotals.length) {
                        return;
                      }
                      final category = categoryTotals.keys.elementAt(index);
                      final focusedCategoryAtPointerDown =
                          _focusedCategoryAtPointerDown;
                      _focusedCategoryAtPointerDown = null;
                      setState(() {
                        _selectedChartCategory =
                            focusedCategoryAtPointerDown == category
                                ? null
                                : category;
                      });
                    },
                  ),
                ),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeInOutCubic,
              ),
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    key: ValueKey<String>(
                      selectedCategory ?? 'current-balance',
                    ),
                    width: 104,
                    child: centerContent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupHeaderWidget(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 16, top: 16, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  void _handleDelete(BuildContext context, TransactionModel tx) {
    setState(() => _pendingDeleteIds.add(tx.id));
    bool isUndone = false;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            content: Text(
              '${T.get('deleted')} ${tx.title}',
              style: const TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: T.get('undo'),
              textColor: Colors.amberAccent,
              onPressed: () {
                isUndone = true;
                setState(() => _pendingDeleteIds.remove(tx.id));
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (!isUndone && reason != SnackBarClosedReason.action) {
        _transactionsCollection.doc(tx.id).delete();
        _pendingDeleteIds.remove(tx.id);
      }
    });
  }

  Future<void> _hideTransactionFromDashboard(
      BuildContext context, TransactionModel tx,
      {required bool hidden}) async {
    try {
      await _transactionsCollection
          .doc(tx.id)
          .update({'hiddenFromDashboard': hidden});
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
              '${T.get(hidden ? 'hiddenFromDashboard' : 'shownOnDashboard')}: ${tx.title}'),
          action: SnackBarAction(
            label: T.get('undo'),
            onPressed: () => _transactionsCollection
                .doc(tx.id)
                .update({'hiddenFromDashboard': !hidden}),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('saveError'))),
      );
    }
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final formattedAmount = NumberFormat('#,##0.00', locale).format(tx.amount);
    final formattedDate =
        DateFormat('dd/MM/yyyy HH:mm', locale).format(tx.date);
    final amountColor = tx.isExpense ? Colors.red : Colors.green;

    final isCategoryValid =
        _categoryIcons.containsKey(tx.category) || tx.category == 'transfer';
    final isPaymentValid = _paymentIcons.containsKey(tx.paymentMethod);

    final categoryColor = isCategoryValid ? _colorOf(tx.category) : Colors.red;
    final categoryIcon =
        isCategoryValid ? _iconOf(tx.category) : Icons.help_outline;
    final paymentIcon =
        isPaymentValid ? _paymentIconOf(tx.paymentMethod) : Icons.help_outline;
    final paymentColor =
        isPaymentValid ? _paymentColorOf(tx.paymentMethod) : Colors.red;
    final isSelected = _selectedTransactionIds.contains(tx.id);
    final isHidden = tx.hiddenFromDashboard;
    final isSelecting = _selectedTransactionIds.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    final mutedColor = colors.onSurfaceVariant.withValues(alpha: 0.68);

    return Dismissible(
      key: ValueKey(tx.id),
      direction:
          isSelecting ? DismissDirection.none : DismissDirection.horizontal,
      background: Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Icon(
              isHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(T.get(isHidden ? 'showOnDashboard' : 'hideFromDashboard'),
                style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            const SizedBox(width: 8),
            Text(T.get('delete'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _hideTransactionFromDashboard(
            context,
            tx,
            hidden: !isHidden,
          );
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(T.get('deleteConfirmTitle')),
                content: Text(T.get('deleteConfirmContent')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(T.get('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(T.get('delete')),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _handleDelete(context, tx),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _toggleTransactionSelection(tx),
        onTap: () {
          if (isSelecting) {
            _toggleTransactionSelection(tx);
          } else {
            _showEditDialog(tx);
          }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isHidden
              ? colors.surfaceContainerHighest.withValues(alpha: 0.72)
              : (isSelected ? colors.primaryContainer : null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: colors.primary.withValues(alpha: 0.6))
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected && !isHidden
                  ? colors.primary
                  : mutedColor.withValues(alpha: 0.16),
              child: Icon(
                isSelected && !isHidden ? Icons.check_rounded : categoryIcon,
                color: isHidden
                    ? mutedColor
                    : (isSelected ? colors.onPrimary : categoryColor),
              ),
            ),
            title: Text(
              tx.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHidden ? mutedColor : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate,
                    style: isHidden ? TextStyle(color: mutedColor) : null),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(categoryIcon,
                        size: 14, color: isHidden ? mutedColor : categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      tx.category == 'transfer'
                          ? T.get('transfer')
                          : (isCategoryValid
                              ? T.get(tx.category)
                              : tx.category),
                      style: TextStyle(
                          fontSize: 12,
                          color: isHidden ? mutedColor : categoryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(' • '),
                    Icon(paymentIcon,
                        size: 14, color: isHidden ? mutedColor : paymentColor),
                    const SizedBox(width: 4),
                    Text(
                      isPaymentValid
                          ? T.get(tx.paymentMethod)
                          : tx.paymentMethod,
                      style: TextStyle(
                          fontSize: 12,
                          color: isHidden ? mutedColor : paymentColor),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tx.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isHidden ? mutedColor : amountColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tx.isExpense ? '-' : '+'}$formattedAmount ฿',
                  style: TextStyle(
                      color: isHidden ? mutedColor : amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<TransactionModel> allTransactions, {
    String? paymentScope,
  }) {
    final isSelecting = _selectedTransactionIds.isNotEmpty;
    if (!identical(_cachedAccountSource, allTransactions) ||
        _cachedAccountScope != paymentScope) {
      _cachedAccountSource = allTransactions;
      _cachedAccountScope = paymentScope;
      _cachedAccountTransactions = paymentScope == null
          ? allTransactions.where((tx) => !tx.hiddenFromDashboard).toList()
          : allTransactions
              .where((tx) =>
                  tx.paymentMethod == paymentScope && !tx.hiddenFromDashboard)
              .toList();
      _cachedGroupSource = null;
    }
    final accountTransactions = _cachedAccountTransactions;

    if (!identical(_cachedGroupSource, accountTransactions) ||
        _cachedGroupType != _groupType) {
      _cachedGroupSource = accountTransactions;
      _cachedGroupType = _groupType;
      if (_groupType != 'none' && accountTransactions.isNotEmpty) {
        final latestKey = _groupKey(accountTransactions.first);
        _cachedGroupTransactions = accountTransactions
            .where((tx) => _groupKey(tx) == latestKey)
            .toList();
      } else {
        _cachedGroupTransactions = accountTransactions;
      }
      _cachedVisibleSource = null;
    }

    final typeKey = _selectedTypes.toList()..sort();
    final categoryKey = _selectedCategories.toList()..sort();
    final paymentKey = _selectedPayments.toList()..sort();
    final visibleKey = jsonEncode([
      paymentScope,
      _sortOrder,
      _groupType,
      typeKey,
      _categoryFilterActive,
      categoryKey,
      _paymentFilterActive,
      paymentKey,
    ]);
    if (!identical(_cachedVisibleSource, allTransactions) ||
        _cachedVisibleKey != visibleKey) {
      _cachedVisibleSource = allTransactions;
      _cachedVisibleKey = visibleKey;
      _cachedVisibleTransactions =
          _filterAndSort(allTransactions, paymentScope: paymentScope);
      _cachedVisibleListItems = _buildListItems(_cachedVisibleTransactions);
      _cachedFilteredScopeTransactions = _cachedGroupTransactions
          .where((tx) => _isMatchFilters(tx, paymentScope: paymentScope))
          .toList();
    }
    final filteredScopeTransactions = _cachedFilteredScopeTransactions;
    final selectedTransactions = _selectedTransactionIds
        .map((id) => _cachedTransactionsById[id])
        .whereType<TransactionModel>()
        .where((tx) => !tx.hiddenFromDashboard)
        .where((tx) => paymentScope == null || tx.paymentMethod == paymentScope)
        .toList();
    final allFilteredTx =
        isSelecting ? selectedTransactions : filteredScopeTransactions;
    final filteredForStats =
        allFilteredTx.where((tx) => tx.category != 'transfer').toList();

    final totalIncome = filteredForStats
        .where((tx) => !tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final totalExpense = filteredForStats
        .where((tx) => tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);

    final realIncome = allFilteredTx
        .where((tx) => !tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final realExpense = allFilteredTx
        .where((tx) => tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final realBalance = realIncome - realExpense;
    final currentBalance = accountTransactions.fold<double>(
      0,
      (total, tx) => total + (tx.isExpense ? -tx.amount : tx.amount),
    );
    final selectedNet = selectedTransactions.fold<double>(
      0,
      (total, tx) => total + (tx.isExpense ? -tx.amount : tx.amount),
    );

    // Keep the full filtered list visible during selection so more rows can be
    // tapped and added; only the dashboard totals are based on selected rows.
    final listItems = _cachedVisibleListItems;
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final selectedNetLabel = NumberFormat.currency(
      locale: locale,
      symbol: '฿',
      decimalDigits: 2,
    ).format(selectedNet);

    return CustomScrollView(
      controller: _dashboardScrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildAccountOverview(
                paymentScope: paymentScope,
                accountTransactions:
                    isSelecting ? selectedTransactions : accountTransactions,
                chartTransactions: filteredForStats,
                income: totalIncome,
                expense: totalExpense,
                balance: realBalance,
                currentBalance: isSelecting ? selectedNet : currentBalance,
              ),
              if (isSelecting)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${_selectedTransactionIds.length} ${T.get('selectedTransactions')}'),
                            const SizedBox(height: 2),
                            Text(
                              '${T.get('selectedNet')}: $selectedNetLabel',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: T.get('cancel'),
                        onPressed: _clearTransactionSelection,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _showBulkEditSheet,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(T.get('editSelected')),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(T.get('history'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        isSelecting
                            ? T.get('tapToSelectMore')
                            : T.get('longPressToSelect'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildFilterBar(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        listItems.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text(
                        accountTransactions.isEmpty
                            ? T.get('noData')
                            : T.get('noMatch'),
                        style: const TextStyle(color: Colors.grey))),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = listItems[index];
                    if (item is String) return _buildGroupHeaderWidget(item);
                    return _buildTransactionItem(
                        context, item as TransactionModel);
                  },
                  childCount: listItems.length,
                ),
              ),
      ],
    );
  }

  Widget _buildPaymentPageSelector(List<String> payments) {
    final selectedIndex =
        _selectedPaymentPage.clamp(0, payments.length).toInt();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface,
          border:
              Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedIndex,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  menuMaxHeight: 400,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurfaceVariant),
                  items: [
                    DropdownMenuItem<int>(
                      value: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 20, color: colors.primary),
                          const SizedBox(width: 10),
                          Text(T.get('primaryPayment')),
                          const SizedBox(width: 8),
                          Text(
                            '· ${T.get('allAccounts')}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var index = 0; index < payments.length; index++)
                      DropdownMenuItem<int>(
                        value: index + 1,
                        child: Row(
                          children: [
                            Icon(_paymentIconOf(payments[index]),
                                size: 20,
                                color: _paymentColorOf(payments[index])),
                            const SizedBox(width: 10),
                            Text(
                              T.get(payments[index]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (index) {
                    if (index == null) return;
                    _selectPaymentAccount(
                      index,
                      slideDirection: index >= selectedIndex ? 1 : -1,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSkeleton() {
    final skeletonColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block({double? width, required double height, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: skeletonColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(child: block(width: 176, height: 176, radius: 88)),
        const SizedBox(height: 24),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(height: 12, width: 62),
                    const SizedBox(height: 10),
                    block(height: 22),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        block(height: 18, width: 150),
        const SizedBox(height: 12),
        for (var index = 0; index < 5; index++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: skeletonColor.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                block(width: 42, height: 42, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(height: 14, width: 132),
                      const SizedBox(height: 8),
                      block(height: 11, width: 92),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                block(height: 16, width: 68),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return Listener(
          onPointerDown: (_) {
            _focusedCategoryAtPointerDown = _selectedChartCategory;
            if (_selectedChartCategory != null) {
              setState(() => _selectedChartCategory = null);
            }
          },
          onPointerCancel: (_) => _focusedCategoryAtPointerDown = null,
          child: Scaffold(
            appBar: AppBar(
              title: Text(T.get('appTitle')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: T.get('transferBetweenAccounts'),
                  onPressed: () => _showTransferSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: T.get('settings'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                    if (mounted) {
                      setState(() => _selectedPaymentPage = 0);
                    }
                    _loadCustomSettings();
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _buildPaymentPageSelector(_paymentIcons.keys.toList()),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _transactionsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text(T.get('loadError')));
                        }
                        if (!snapshot.hasData) {
                          return _buildDashboardSkeleton();
                        }

                        final querySnapshot = snapshot.data!;
                        if (!identical(_cachedSnapshot, querySnapshot)) {
                          _cachedSnapshot = querySnapshot;
                          _cachedParsedTransactions =
                              querySnapshot.docs.map((doc) {
                            final data = Map<String, dynamic>.from(
                                doc.data() as Map<String, dynamic>);
                            data['id'] = doc.id;
                            return TransactionModel.fromMap(data);
                          }).toList();
                          _cachedPendingDeleteKey = null;
                        }
                        final pendingDeleteKey =
                            (_pendingDeleteIds.toList()..sort()).join('\u0000');
                        if (_cachedPendingDeleteKey != pendingDeleteKey) {
                          _cachedPendingDeleteKey = pendingDeleteKey;
                          _cachedAvailableTransactions =
                              _cachedParsedTransactions
                                  .where((tx) =>
                                      !_pendingDeleteIds.contains(tx.id))
                                  .toList();
                          _cachedTransactionsById
                            ..clear()
                            ..addEntries(_cachedAvailableTransactions
                                .map((tx) => MapEntry(tx.id, tx)));
                        }
                        final allTransactions = _cachedAvailableTransactions;

                        final payments = _paymentIcons.keys.toList();
                        final selectedIndex = _selectedPaymentPage
                            .clamp(0, payments.length)
                            .toInt();
                        return _buildContent(
                          allTransactions,
                          paymentScope: selectedIndex == 0
                              ? null
                              : payments[selectedIndex - 1],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddTransactionSheet(context),
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }
}
