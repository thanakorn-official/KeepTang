import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../main.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import 'splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _categories = [
    'อาหาร',
    'เดินทาง',
    'ช้อปปิ้ง',
    'บิล/ค่าใช้จ่าย',
    'เงินเดือน/รายรับ',
    'ความบันเทิง',
    'สุขภาพ/พยาบาล',
    'ที่อยู่อาศัย',
    'การศึกษา',
    'การลงทุน',
    'อื่นๆ'
  ];

  List<String> _payments = ['cash', 'promptpay', 'truemoney', 'paotang'];

  Map<String, int> _categoryIconCodes = {};
  Map<String, int> _paymentIconCodes = {};
  Map<String, int> _categoryColorValues = {};
  Map<String, int> _paymentColorValues = {};

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  IconData _getCategoryIcon(String cat) {
    if (_categoryIconCodes.containsKey(cat)) {
      return IconData(_categoryIconCodes[cat]!, fontFamily: 'MaterialIcons');
    }
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
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String cat) {
    if (_categoryColorValues.containsKey(cat)) {
      return Color(_categoryColorValues[cat]!);
    }
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
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getPaymentIcon(String pay) {
    if (_paymentIconCodes.containsKey(pay)) {
      return IconData(_paymentIconCodes[pay]!, fontFamily: 'MaterialIcons');
    }
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

  Color _getPaymentColor(String pay) {
    if (_paymentColorValues.containsKey(pay)) {
      return Color(_paymentColorValues[pay]!);
    }
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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final customCats = prefs.getString('app_categories_list');
    if (customCats != null) {
      final List<dynamic> decoded = jsonDecode(customCats);
      setState(() {
        _categories = decoded.map((e) => e.toString()).toList();
      });
    }

    final catIconsStr = prefs.getString('app_category_icon_codes');
    if (catIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catIconsStr);
      setState(() {
        _categoryIconCodes = decoded.map((k, v) => MapEntry(k, v as int));
      });
    }

    final catColorsStr = prefs.getString('app_category_color_values');
    if (catColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catColorsStr);
      setState(() {
        _categoryColorValues = decoded.map((k, v) => MapEntry(k, v as int));
      });
    }

    final customPayments = prefs.getString('app_payments_list');
    if (customPayments != null) {
      final List<dynamic> decoded = jsonDecode(customPayments);
      setState(() {
        _payments = decoded.map((e) => e.toString()).toList();
      });
    }

    final payIconsStr = prefs.getString('app_payment_icon_codes');
    if (payIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payIconsStr);
      setState(() {
        _paymentIconCodes = decoded.map((k, v) => MapEntry(k, v as int));
      });
    }

    final payColorsStr = prefs.getString('app_payment_color_values');
    if (payColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payColorsStr);
      setState(() {
        _paymentColorValues = decoded.map((k, v) => MapEntry(k, v as int));
      });
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_categories_list', jsonEncode(_categories));
    await prefs.setString(
        'app_category_icon_codes', jsonEncode(_categoryIconCodes));
    await prefs.setString(
        'app_category_color_values', jsonEncode(_categoryColorValues));
    await GuestService.saveCustomSettings();
  }

  Future<void> _savePayments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_payments_list', jsonEncode(_payments));
    await prefs.setString(
        'app_payment_icon_codes', jsonEncode(_paymentIconCodes));
    await prefs.setString(
        'app_payment_color_values', jsonEncode(_paymentColorValues));
    await GuestService.saveCustomSettings();
  }

  void _showCategoryDialog(StateSetter setModalState, {String? oldCategory}) {
    final isEditing = oldCategory != null;
    final controller =
        TextEditingController(text: isEditing ? oldCategory : '');
    IconData selectedIcon = isEditing
        ? _getCategoryIcon(oldCategory)
        : _selectableCategoryIcons.first;
    Color selectedColor =
        isEditing ? _getCategoryColor(oldCategory) : _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? T.get('editItem') : T.get('addCategory')),
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
                      final isSelected = selectedColor.value == color.value;
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
                                    color: Colors.black.withOpacity(0.3),
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
                  if (text.isNotEmpty) {
                    setState(() {
                      if (isEditing) {
                        final index = _categories.indexOf(oldCategory);
                        if (index != -1) _categories[index] = text;
                        if (oldCategory != text) {
                          _categoryIconCodes.remove(oldCategory);
                          _categoryColorValues.remove(oldCategory);
                        }
                      } else if (!_categories.contains(text)) {
                        _categories.add(text);
                      }
                      _categoryIconCodes[text] = selectedIcon.codePoint;
                      _categoryColorValues[text] = selectedColor.value;
                    });
                    await _saveCategories();
                    setModalState(() {});
                  }
                  if (mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDialog(StateSetter setModalState, {String? oldPayment}) {
    final isEditing = oldPayment != null;
    final controller = TextEditingController(
        text: isEditing
            ? (T.get(oldPayment) == oldPayment ? oldPayment : T.get(oldPayment))
            : '');
    IconData selectedIcon =
        isEditing ? _getPaymentIcon(oldPayment) : _selectablePaymentIcons.first;
    Color selectedColor =
        isEditing ? _getPaymentColor(oldPayment) : _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? T.get('editItem') : T.get('addPayment')),
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
                      final isSelected = selectedColor.value == color.value;
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
                                    color: Colors.black.withOpacity(0.3),
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
                  if (text.isNotEmpty) {
                    setState(() {
                      if (isEditing) {
                        final index = _payments.indexOf(oldPayment);
                        if (index != -1) _payments[index] = text;
                        if (oldPayment != text) {
                          _paymentIconCodes.remove(oldPayment);
                          _paymentColorValues.remove(oldPayment);
                        }
                      } else if (!_payments.contains(text)) {
                        _payments.add(text);
                      }
                      _paymentIconCodes[text] = selectedIcon.codePoint;
                      _paymentColorValues[text] = selectedColor.value;
                    });
                    await _savePayments();
                    setModalState(() {});
                  }
                  if (mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDeleteCategory(String category) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(T.get('deleteConfirmTitle')),
        content: Text('${T.get('deleteConfirmContent')} ${T.get(category)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(T.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(T.get('delete')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeletePayment(String payment) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(T.get('deleteConfirmTitle')),
        content: Text('${T.get('deleteConfirmContent')} ${T.get(payment)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(T.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(T.get('delete')),
          ),
        ],
      ),
    );
  }

  void _openManageCategoriesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Scaffold(
              appBar: AppBar(title: Text(T.get('manageCategories'))),
              body: ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 80,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final catColor = _getCategoryColor(cat);
                  return Dismissible(
                    key: ValueKey(cat),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await _confirmDeleteCategory(cat);
                    },
                    onDismissed: (direction) async {
                      setState(() {
                        _categories.remove(cat);
                        _categoryIconCodes.remove(cat);
                        _categoryColorValues.remove(cat);
                      });
                      await _saveCategories();
                      setModalState(() {});
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(T.get('delete'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: catColor.withOpacity(0.2),
                          child: Icon(_getCategoryIcon(cat), color: catColor),
                        ),
                        title: Text(T.get(cat),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _showCategoryDialog(setModalState,
                            oldCategory: cat),
                      ),
                    ),
                  );
                },
              ),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 8),
                child: FloatingActionButton.extended(
                  onPressed: () => _showCategoryDialog(setModalState),
                  icon: const Icon(Icons.add),
                  label: Text(T.get('addCategory')),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openManagePaymentsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Scaffold(
              appBar: AppBar(title: Text(T.get('managePayments'))),
              body: ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 80,
                ),
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final pay = _payments[index];
                  final payColor = _getPaymentColor(pay);
                  return Dismissible(
                    key: ValueKey(pay),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await _confirmDeletePayment(pay);
                    },
                    onDismissed: (direction) async {
                      setState(() {
                        _payments.remove(pay);
                        _paymentIconCodes.remove(pay);
                        _paymentColorValues.remove(pay);
                      });
                      await _savePayments();
                      setModalState(() {});
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(T.get('delete'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: payColor.withOpacity(0.2),
                          child: Icon(_getPaymentIcon(pay), color: payColor),
                        ),
                        title: Text(T.get(pay),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () =>
                            _showPaymentDialog(setModalState, oldPayment: pay),
                      ),
                    ),
                  );
                },
              ),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 8),
                child: FloatingActionButton.extended(
                  onPressed: () => _showPaymentDialog(setModalState),
                  icon: const Icon(Icons.add),
                  label: Text(T.get('addPayment')),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: GuestService.username);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.get('changeUsername')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: T.get('usernameLabel'),
            prefixIcon: const Icon(Icons.person_outline),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(T.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(T.get('save')),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.get('usernameEmpty'))),
        );
      }
      return;
    }
    await GuestService.setUsername(name);
    setState(() {});
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(T.get('signOutConfirmTitle')),
        content: Text(T.get('signOutConfirmContent')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(T.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(T.get('signOutConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await GuestService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  Widget _buildGuestCard() {
    final name = GuestService.username ?? '';
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(initial,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(T.get('guestMode'),
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 2),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: GuestService.guestId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(T.get('guestIdCopied'))),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                        '${T.get('guestIdLabel')} ${GuestService.guestId}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: T.get('changeUsername'),
          onPressed: _changeUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return Scaffold(
          appBar: AppBar(title: Text(T.get('settings'))),
          body: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              Text(T.get('account'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildGuestCard(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: Text(T.get('signOut')),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: Text(T.get('manageCategories')),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _openManageCategoriesScreen,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.payment_outlined),
                      title: Text(T.get('managePayments')),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _openManagePaymentsScreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(T.get('theme')),
                  trailing: ValueListenableBuilder<String>(
                    valueListenable: themeNotifier,
                    builder: (context, currentTheme, _) {
                      return DropdownButton<String>(
                        value: currentTheme,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                              value: 'light', child: Text(T.get('lightMode'))),
                          DropdownMenuItem(
                              value: 'dark', child: Text(T.get('darkMode'))),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            themeNotifier.value = val;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('app_theme_mode', val);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(T.get('language')),
                  trailing: DropdownButton<String>(
                    value: currentLang,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                          value: 'th', child: Text(T.get('thaiLanguage'))),
                      DropdownMenuItem(
                          value: 'en', child: Text(T.get('englishLanguage'))),
                    ],
                    onChanged: (val) {
                      if (val != null) languageNotifier.value = val;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(T.get('about'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(T.get('app_version'),
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(T.get('about_desc'),
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
