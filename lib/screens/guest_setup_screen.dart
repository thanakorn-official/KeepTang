import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import 'dashboard_screen.dart';

class GuestSetupScreen extends StatefulWidget {
  const GuestSetupScreen({super.key});

  @override
  State<GuestSetupScreen> createState() => _GuestSetupScreenState();
}

class _GuestSetupScreenState extends State<GuestSetupScreen> {
  static const _unspecified = '\u0e44\u0e21\u0e48\u0e23\u0e30\u0e1a\u0e38';
  static const _starterCategories = [
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
    'อื่นๆ',
  ];
  final _controller = TextEditingController();
  final _firstPaymentController = TextEditingController();
  final Set<String> _selectedCategories = {};
  bool _busy = false;
  bool _isRestoring = false;

  @override
  void dispose() {
    _controller.dispose();
    _firstPaymentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstTimeAdviceDialog();
    });
  }

  void _showFirstTimeAdviceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(T.get('guestIdAdviceTitle'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.get('guestIdAdviceIntro'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    GuestService.guestId,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy,
                        size: 18, color: Theme.of(ctx).colorScheme.primary),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: GuestService.guestId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(T.get('guestIdCopied'))),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💡 ${T.get('guestIdAdviceBody')}',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(T.get('guestIdAdviceDone')),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final inputVal = _controller.text.trim();
    if (inputVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isRestoring
                ? T.get('restoreGuestIdEmpty')
                : T.get('usernameEmpty'))),
      );
      return;
    }
    final firstPayment = _firstPaymentController.text.trim();
    if (!_isRestoring && firstPayment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('firstPaymentRequired'))),
      );
      return;
    }
    if (!_isRestoring && firstPayment == _unspecified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('firstPaymentReserved'))),
      );
      return;
    }
    if (!_isRestoring && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('starterCategoryRequired'))),
      );
      return;
    }

    setState(() => _busy = true);

    if (_isRestoring) {
      await GuestService.setCustomGuestId(inputVal);
      await GuestService.restoreCustomSettings();
    } else {
      await GuestService.setUsername(inputVal);
      final prefs = await SharedPreferences.getInstance();
      final categories = _starterCategories
          .where(_selectedCategories.contains)
          .toList()
        ..add(_unspecified);
      await prefs.setString('app_categories_list', jsonEncode(categories));
      await prefs.setString(
        'app_payments_list',
        jsonEncode([firstPayment, _unspecified]),
      );
      await GuestService.saveCustomSettings();
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  Widget _buildPreferences(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.language, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(T.get('language'))),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'th', label: Text('ไทย')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {languageNotifier.value},
                onSelectionChanged: (value) {
                  languageNotifier.value = value.first;
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.contrast, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(T.get('theme'))),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'light',
                    label: Text(T.get('lightMode')),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text(T.get('darkMode')),
                  ),
                ],
                selected: {themeNotifier.value},
                onSelectionChanged: (value) {
                  themeNotifier.value = value.first;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPreferences(scheme),
                    const SizedBox(height: 28),
                    Image.asset(
                      'assets/splash_bill_base.png',
                      width: 104,
                      height: 104,
                      fit: BoxFit.contain,
                      color: scheme.onSurface,
                      semanticLabel: T.get('appTitle'),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      T.get('appTitle'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRestoring
                          ? T.get('restoreTagline')
                          : T.get('guestTagline'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${T.get('guestIdLabel')} ${GuestService.guestId}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _start(),
                      maxLength: _isRestoring ? 50 : 30,
                      decoration: InputDecoration(
                        labelText: _isRestoring
                            ? T.get('restoreGuestIdLabel')
                            : T.get('usernameLabel'),
                        prefixIcon: Icon(_isRestoring
                            ? Icons.vpn_key
                            : Icons.person_outline),
                        counterText: '',
                      ),
                    ),
                    if (!_isRestoring) ...[
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    color: scheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(T.get('firstPaymentTitle'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))),
                                const Icon(Icons.star,
                                    size: 16, color: Colors.orange),
                              ]),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _firstPaymentController,
                                textInputAction: TextInputAction.next,
                                maxLength: 40,
                                decoration: InputDecoration(
                                  labelText: T.get('firstPaymentLabel'),
                                  prefixIcon:
                                      const Icon(Icons.payments_outlined),
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(T.get('starterCategoriesTitle'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(T.get('starterCategoriesHint'),
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              ..._starterCategories.map((category) =>
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value:
                                        _selectedCategories.contains(category),
                                    title: Text(category),
                                    onChanged: (checked) => setState(() {
                                      if (checked == true) {
                                        _selectedCategories.add(category);
                                      } else {
                                        _selectedCategories.remove(category);
                                      }
                                    }),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _start,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isRestoring
                                    ? T.get('restoreButton')
                                    : T.get('startButton'),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isRestoring = !_isRestoring;
                          _controller.clear();
                        });
                      },
                      child: Text(
                        _isRestoring
                            ? T.get('restoreSwitchBack')
                            : T.get('restoreSwitchTo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
