import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/transaction_model.dart';
import '../main.dart';
import '../services/export_service.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  CollectionReference get _transactionsCollection => FirebaseFirestore.instance
      .collection('guests')
      .doc(GuestService.guestId)
      .collection('transactions');

  String _groupType = 'monthly';
  String _sortOrder = 'newest';


  Set<String> _selectedTypes = {
    'income',
    'expense'
  };
  Set<String> _selectedCategories = {};
  Set<String> _selectedPayments = {};

  @override
  void initState() {
    super.initState();
    _loadCustomSettings();
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


  Future<void> _showMultiSelectDialog({
    required String title,
    required Map<String, String> items,
    required Set<String> selectedItems,
    required ValueChanged<Set<String>> onConfirm,
  }) async {

    Set<String> tempSelected = Set.from(selectedItems);
    if (tempSelected.isEmpty && items.isNotEmpty) {
      tempSelected.addAll(items.keys);
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tempSelected.length} / ${items.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final entry = items.entries.elementAt(index);
                          final isSelected = tempSelected.contains(entry.key);
                          return Material(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: CheckboxListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              title: Text(entry.value,
                                  style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                              value: isSelected,
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              onChanged: (bool? checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    tempSelected.add(entry.key);
                                  } else {
                                    tempSelected.remove(entry.key);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempSelected.addAll(items.keys);
                    });
                  },
                  child: Text(T.get('selectAll')),
                ),
                TextButton(
                  onPressed: () => setDialogState(tempSelected.clear),
                  child: Text(T.get('clearAll')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(ctx);
                  },
                  child: Text(T.get('apply')),
                ),
              ],
            );
          },
        );
      },
    );
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
                      final isSelected = selectedColor.toARGB32() == color.toARGB32();
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
                      final isSelected = selectedColor.toARGB32() == color.toARGB32();
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
                        decoration: const InputDecoration(
                            labelText: 'จำนวนเงิน',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: fromPayment,
                      decoration: const InputDecoration(
                          labelText: 'จากบัญชี (ต้นทาง)',
                          border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(
                          labelText: 'เข้าบัญชี (ปลายทาง)',
                          border: OutlineInputBorder()),
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
                        decoration: const InputDecoration(
                            labelText: 'บันทึกช่วยจำ (ไม่บังคับ)',
                            border: OutlineInputBorder())),
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
                                : 'โอนออกไป ${T.get(toPayment)}',
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
                                : 'รับโอนจาก ${T.get(fromPayment)}',
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
      ValueChanged<String?> onChanged) {
    final currentValue = items.contains(value) ? value : items.first;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(icon, size: 16),
          ),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          items: items
              .map((val) =>
                  DropdownMenuItem(value: val, child: Text(T.get(val))))
              .toList(),
          onChanged: onChanged,
        ),
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

  String _filterSummary(int selectedCount) =>
      selectedCount == 0 ? T.get('all') : '$selectedCount ${T.get('selected')}';

  void _showTypeFilter() {
    _showMultiSelectDialog(
      title: T.get('selectType'),
      items: {'income': T.get('income'), 'expense': T.get('expense')},
      selectedItems: _selectedTypes,
      onConfirm: (value) => setState(() => _selectedTypes = value),
    );
  }

  void _showCategoryFilter() {
    final items = <String, String>{
      for (final category in _categoryIcons.keys) category: T.get(category),
      'transfer': T.get('transfer'),
    };
    _showMultiSelectDialog(
      title: T.get('selectCategory'),
      items: items,
      selectedItems: _selectedCategories,
      onConfirm: (value) => setState(() {
        _selectedCategories = value.length == items.length ? <String>{} : value;
      }),
    );
  }

  void _showPaymentFilter() {
    final items = <String, String>{
      for (final payment in _paymentIcons.keys) payment: T.get(payment),
    };
    _showMultiSelectDialog(
      title: T.get('selectPayment'),
      items: items,
      selectedItems: _selectedPayments,
      onConfirm: (value) => setState(() {
        _selectedPayments = value.length == items.length ? <String>{} : value;
      }),
    );
  }

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(T.get('filters'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.filter_list),
                title: Text(T.get('filterType')),
                subtitle: Text(_filterSummary(
                    _selectedTypes.length == 2 ? 0 : _selectedTypes.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTypeFilter();
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(T.get('filterCategory')),
                subtitle: Text(_filterSummary(_selectedCategories.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCategoryFilter();
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(T.get('filterPayment')),
                subtitle: Text(_filterSummary(_selectedPayments.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPaymentFilter();
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTypes = {'income', 'expense'};
                    _selectedCategories.clear();
                    _selectedPayments.clear();
                  });
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(T.get('clearFilters')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final activeSelections =
        (_selectedTypes.length == 2 ? 0 : _selectedTypes.length) +
            _selectedCategories.length +
            _selectedPayments.length;
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
          ),
          _buildDropdown(
            _sortOrder,
            ['newest', 'oldest', 'highest', 'lowest'],
            Icons.sort,
            (value) => setState(() => _sortOrder = value!),
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


  bool _isMatchFilters(TransactionModel tx) {

    if (tx.isExpense && !_selectedTypes.contains('expense')) {
      return false;
    }
    if (!tx.isExpense && !_selectedTypes.contains('income')) {
      return false;
    }


    if (_selectedCategories.isNotEmpty &&
        !_selectedCategories.contains(tx.category)) {
      return false;
    }


    if (_selectedPayments.isNotEmpty &&
        !_selectedPayments.contains(tx.paymentMethod)) {
      return false;
    }

    return true;
  }

  List<TransactionModel> _filterAndSort(List<TransactionModel> transactions) {
    final result = transactions.where((tx) => _isMatchFilters(tx)).toList();

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

  Widget _buildPieChart(List<TransactionModel> transactions) {
    final Map<String, double> categoryTotals = {};
    for (final tx in transactions) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0.0) + tx.amount;
    }
    final totalSum = categoryTotals.values.fold(0.0, (a, b) => a + b);

    final sections = categoryTotals.entries.map((entry) {
      final percentage = totalSum > 0 ? (entry.value / totalSum * 100) : 0.0;
      return PieChartSectionData(
        color: _colorOf(entry.key),
        value: entry.value,
        title: '',
        radius: 65,
        badgeWidget: percentage >= 6.0
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

    return Column(
      children: [
        SizedBox(
            height: 200,
            child: PieChart(PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 40, sections: sections))),
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
            duration: const Duration(seconds: 4),
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

  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final formattedAmount = NumberFormat('#,##0.00', locale).format(tx.amount);
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm', locale).format(tx.date);
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

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
      onDismissed: (_) => _handleDelete(context, tx),
      child: InkWell(
        onTap: () => _showEditDialog(tx),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor.withValues(alpha: 0.2),
              child: Icon(categoryIcon, color: categoryColor),
            ),
            title: Text(tx.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(categoryIcon, size: 14, color: categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      tx.category == 'transfer'
                          ? T.get('transfer')
                          : (isCategoryValid
                              ? T.get(tx.category)
                              : tx.category),
                      style: TextStyle(
                          fontSize: 12,
                          color: categoryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(' • '),
                    Icon(paymentIcon, size: 14, color: paymentColor),
                    const SizedBox(width: 4),
                    Text(
                      isPaymentValid
                          ? T.get(tx.paymentMethod)
                          : tx.paymentMethod,
                      style: TextStyle(fontSize: 12, color: paymentColor),
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
                  color: amountColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tx.isExpense ? '-' : '+'}$formattedAmount ฿',
                  style: TextStyle(
                      color: amountColor,
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

  Widget _buildContent(List<TransactionModel> allTransactions) {
    List<TransactionModel> scopeTransactions = allTransactions;
    if (_groupType != 'none' && allTransactions.isNotEmpty) {
      final latestKey = _groupKey(allTransactions.first);
      scopeTransactions =
          allTransactions.where((tx) => _groupKey(tx) == latestKey).toList();
    }

    final allFilteredTx =
        scopeTransactions.where((tx) => _isMatchFilters(tx)).toList();

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

    final exportTransactions = _filterAndSort(scopeTransactions);
    final listItems = _buildListItems(_filterAndSort(allTransactions));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 24),
              if (allTransactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(T.get('noData'),
                      style: const TextStyle(color: Colors.grey)),
                )
              else if (filteredForStats.isNotEmpty)
                _buildPieChart(filteredForStats),
              if (allTransactions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: exportTransactions.isEmpty
                          ? null
                          : () => ExportService.exportToCsv(exportTransactions),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(T.get('exportCsv')),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildSummaryRow(totalIncome, totalExpense, realBalance),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(T.get('history'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(T.get('swipeToDelete'),
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
                    child: Text(T.get('noMatch'),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return Scaffold(
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
                  _loadCustomSettings();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _transactionsCollection
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(T.get('loadError')));
                }

                final allTransactions = snapshot.data!.docs
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return TransactionModel.fromMap(data);
                    })
                    .where((tx) => !_pendingDeleteIds.contains(tx.id))
                    .toList();

                return _buildContent(allTransactions);
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTransactionSheet(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

