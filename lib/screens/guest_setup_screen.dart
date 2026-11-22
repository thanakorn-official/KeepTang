import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import '../widgets/app_logo.dart';
import '../widgets/skeleton_loader.dart';
import 'dashboard_screen.dart';

enum _GuestSetupMode { choose, create, restore, created }

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
  static const _starterCategoryIcons = <String, IconData>{
    'อาหาร': Icons.restaurant,
    'เดินทาง': Icons.directions_car,
    'ช้อปปิ้ง': Icons.shopping_bag,
    'บิล/ค่าใช้จ่าย': Icons.receipt_long,
    'เงินเดือน/รายรับ': Icons.account_balance_wallet,
    'ความบันเทิง': Icons.movie,
    'สุขภาพ/พยาบาล': Icons.medical_services,
    'ที่อยู่อาศัย': Icons.home,
    'การศึกษา': Icons.school,
    'การลงทุน': Icons.trending_up,
    'อื่นๆ': Icons.category,
  };
  final _usernameController =
      TextEditingController(text: GuestService.username);
  final _guestIdController = TextEditingController();
  final _firstPaymentController = TextEditingController();
  final Set<String> _selectedCategories = {};
  _GuestSetupMode _mode = _GuestSetupMode.choose;
  bool _busy = false;
  String? _errorKey;
  int _setupStep = 0;

  bool get _isCreating => _mode == _GuestSetupMode.create;

  bool get _isRestoring => _mode == _GuestSetupMode.restore;

  @override
  void dispose() {
    _usernameController.dispose();
    _guestIdController.dispose();
    _firstPaymentController.dispose();
    super.dispose();
  }

  void _setMode(_GuestSetupMode mode) {
    setState(() {
      _mode = mode;
      _errorKey = null;
      _setupStep = 0;
    });
  }

  Future<void> _copyGuestId() async {
    final id = GuestService.guestId;
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.get('guestIdCopied'))),
    );
  }

  Future<void> _start() async {
    if (_busy || (!_isCreating && !_isRestoring)) return;
    final isRestoring = _isRestoring;
    final inputVal =
        (isRestoring ? _guestIdController : _usernameController).text.trim();
    if (inputVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isRestoring
                ? T.get('restoreGuestIdEmpty')
                : T.get('usernameEmpty'))),
      );
      return;
    }
    final firstPayment = _firstPaymentController.text.trim();
    if (!isRestoring && firstPayment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('firstPaymentRequired'))),
      );
      return;
    }
    if (!isRestoring && firstPayment == _unspecified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('firstPaymentReserved'))),
      );
      return;
    }
    if (!isRestoring && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('starterCategoryRequired'))),
      );
      return;
    }

    setState(() {
      _busy = true;
      _errorKey = null;
    });

    try {
      if (isRestoring) {
        final restored = await GuestService.restoreGuest(inputVal);
        if (!mounted) return;
        if (!restored) {
          setState(() => _errorKey = 'restoreGuestIdNotFound');
          return;
        }
        await GuestService.restoreCustomSettings();
        if (mounted) _openDashboard();
        return;
      }

      if (!GuestService.hasActiveGuest) {
        await GuestService.createGuest(inputVal);
      }
      if (!GuestService.hasActiveGuest) {
        throw StateError('Guest account was not activated.');
      }
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
      if (mounted) _setMode(_GuestSetupMode.created);
    } catch (error) {
      debugPrint('Could not complete guest setup: $error');
      if (mounted) {
        setState(() => _errorKey =
            isRestoring ? 'restoreGuestIdError' : 'createGuestIdError');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDashboard() {
    if (!GuestService.hasActiveGuest) {
      _setMode(_GuestSetupMode.choose);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  void _continueSetup() {
    if (_busy || !_isCreating || _setupStep >= 2) return;
    if (_setupStep == 0 && _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('usernameEmpty'))),
      );
      return;
    }
    if (_setupStep == 1) {
      final payment = _firstPaymentController.text.trim();
      if (payment.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.get('firstPaymentRequired'))),
        );
        return;
      }
      if (payment == _unspecified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.get('firstPaymentReserved'))),
        );
        return;
      }
    }
    setState(() => _setupStep++);
  }

  Widget _buildSetupProgress(ColorScheme scheme) {
    final labels = [
      T.get('setupStepName'),
      T.get('setupStepPayment'),
      T.get('setupStepCategories'),
    ];
    final icons = [
      Icons.person_outline,
      Icons.account_balance_wallet_outlined,
      Icons.category_outlined
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == _setupStep;
          final complete = index < _setupStep;
          final color = active || complete ? scheme.primary : scheme.outline;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(complete ? Icons.check : icons[index],
                      size: 16, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
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
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth < 360 ? 20.0 : 28.0;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPreferences(scheme),
                          const SizedBox(height: 22),
                          AppLogo(
                            size: 88,
                            semanticLabel: T.get('appTitle'),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            T.get('appTitle'),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (_mode != _GuestSetupMode.created) ...[
                            const SizedBox(height: 8),
                            Text(
                              T.get(switch (_mode) {
                                _GuestSetupMode.choose => 'guestAccessPrompt',
                                _GuestSetupMode.restore => 'restoreTagline',
                                _ => 'guestTagline',
                              }),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_mode == _GuestSetupMode.choose) ...[
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _setMode(_GuestSetupMode.create),
                                icon: const Icon(Icons.person_add_outlined),
                                label: Text(T.get('createGuestId')),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _setMode(_GuestSetupMode.restore),
                                icon: const Icon(Icons.key_outlined),
                                label: Text(T.get('useExistingGuestId')),
                              ),
                            ),
                          ],
                          if (_mode == _GuestSetupMode.created) ...[
                            const SizedBox(height: 14),
                            _buildGuestIdCard(scheme),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _openDashboard,
                                child: Text(T.get('startButton')),
                              ),
                            ),
                          ],
                          if (_isCreating) _buildSetupProgress(scheme),
                          if (_isRestoring ||
                              (_isCreating && _setupStep == 0)) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _isRestoring
                                  ? _guestIdController
                                  : _usernameController,
                              enabled: !_busy,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _isRestoring ? _start() : _continueSetup(),
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
                          ],
                          if (_isCreating && _setupStep == 1) ...[
                            const SizedBox(height: 20),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            T.get('firstPaymentTitle'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _firstPaymentController,
                                      enabled: !_busy,
                                      textInputAction: TextInputAction.next,
                                      maxLength: 40,
                                      decoration: InputDecoration(
                                        labelText: T.get('firstPaymentLabel'),
                                        hintText: T.get('accountNameHint'),
                                        prefixIcon: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                        ),
                                        counterText: '',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_isCreating && _setupStep == 2) ...[
                            const SizedBox(height: 14),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      T.get('starterCategoriesTitle'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      T.get('starterCategoriesHint'),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    ..._starterCategories.map(
                                      (category) => CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        value: _selectedCategories
                                            .contains(category),
                                        title: Text(category),
                                        secondary: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: scheme.primaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _starterCategoryIcons[category] ??
                                                Icons.category_outlined,
                                            size: 19,
                                            color: scheme.primary,
                                          ),
                                        ),
                                        onChanged: _busy
                                            ? null
                                            : (checked) => setState(() {
                                                  if (checked == true) {
                                                    _selectedCategories
                                                        .add(category);
                                                  } else {
                                                    _selectedCategories
                                                        .remove(category);
                                                  }
                                                }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_errorKey case final errorKey?) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                T.get(errorKey),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ],
                          if (_isCreating || _isRestoring) ...[
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _busy
                                    ? null
                                    : _isRestoring
                                        ? _start
                                        : _setupStep < 2
                                            ? _continueSetup
                                            : _start,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _busy
                                    ? const SkeletonPulse(
                                        child: SkeletonBlock(
                                          width: 110,
                                          height: 18,
                                        ),
                                      )
                                    : Text(
                                        _isRestoring
                                            ? T.get('restoreButton')
                                            : _setupStep < 2
                                                ? T.get('continue')
                                                : T.get('createGuestId'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (_isCreating && _setupStep > 0) {
                                        setState(() {
                                          _setupStep--;
                                          _errorKey = null;
                                        });
                                      } else {
                                        _setMode(_GuestSetupMode.choose);
                                      }
                                    },
                              icon: const Icon(Icons.arrow_back),
                              label: Text(T.get('back')),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(
                                        _isRestoring
                                            ? _GuestSetupMode.create
                                            : _GuestSetupMode.restore,
                                      ),
                              child: Text(
                                T.get(_isRestoring
                                    ? 'createGuestId'
                                    : 'useExistingGuestId'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuestIdCard(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  T.get('guestIdCardTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: T.get('copyGuestId'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                icon: Icon(
                  Icons.copy_outlined,
                  size: 19,
                  color: scheme.primary,
                ),
                onPressed: _copyGuestId,
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              GuestService.guestId,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            T.get('guestIdHint'),
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
