import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guest_service.dart';
import '../utils/l10n.dart';
import 'dashboard_screen.dart';
import 'guest_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _defaultCategoryIcons = <String, IconData>{
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

  static const _defaultCategoryColors = <String, Color>{
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

  static const _selectableCategoryIcons = <IconData>[
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

  final Map<String, double> _loadingTotals = {};
  final Map<String, Color> _savedCategoryColors = {};
  final Map<String, int> _savedCategoryIconCodes = {};
  double? _loadingBalance;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _prepareAndNavigate();
  }

  Future<void> _prepareAndNavigate() async {
    try {
      final minimumDisplayTime =
          Future<void>.delayed(const Duration(milliseconds: 420));
      final accountLoad = _prepareAccount();
      final initialSnapshot = await accountLoad;
      await minimumDisplayTime;
      if (!mounted) return;

      final destination = GuestService.hasActiveGuest
          ? DashboardScreen(initialSnapshot: initialSnapshot)
          : const GuestSetupScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final eased = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: eased,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(eased),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 520),
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'KeepTang splash screen',
      ));
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<QuerySnapshot?> _prepareAccount() async {
    await GuestService.loadSavedGuest();
    if (!GuestService.hasActiveGuest) return null;

    await GuestService.finishPendingLegacyMigration();
    await GuestService.restoreCustomSettings();
    await _loadSavedCategoryStyles();

    try {
      final snapshot = await GuestService.activeGuestDocument
          .collection('transactions')
          .orderBy('date', descending: true)
          .get()
          .timeout(const Duration(seconds: 8));
      await _animateTransactionSlices(snapshot);
      return snapshot;
    } catch (error) {
      // The dashboard stream still opens if the device is offline or the
      // initial read fails. It can show cached data or retry after launch.
      debugPrint('Could not preload dashboard transactions: $error');
      return null;
    }
  }

  Future<void> _loadSavedCategoryStyles() async {
    final preferences = await SharedPreferences.getInstance();
    final savedColors = preferences.getString('app_category_color_values');
    final savedIcons = preferences.getString('app_category_icon_codes');

    try {
      if (savedColors != null) {
        final decoded = jsonDecode(savedColors);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is int) {
              _savedCategoryColors[entry.key.toString()] =
                  Color(entry.value as int);
            }
          }
        }
      }
      if (savedIcons != null) {
        final decoded = jsonDecode(savedIcons);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is int) {
              _savedCategoryIconCodes[entry.key.toString()] =
                  entry.value as int;
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not restore loading chart styles: $error');
    }
  }

  Future<void> _animateTransactionSlices(QuerySnapshot snapshot) async {
    var balance = 0.0;
    for (final document in snapshot.docs) {
      final data = Map<String, dynamic>.from(
        document.data() as Map<String, dynamic>,
      );
      if (data['deletedAt'] != null || data['hiddenFromDashboard'] == true) {
        continue;
      }

      final amount = data['amount'];
      if (amount is! num) continue;
      final isExpense = data['isExpense'] == 1 || data['isExpense'] == true;
      balance += isExpense ? -amount.toDouble() : amount.toDouble();
    }
    if (!mounted) return;
    setState(() => _loadingBalance = balance);

    final transactions = <_LoadingTransaction>[];
    DateTime? latestDate;
    for (final document in snapshot.docs) {
      final data = Map<String, dynamic>.from(
        document.data() as Map<String, dynamic>,
      );
      if (data['deletedAt'] != null || data['hiddenFromDashboard'] == true) {
        continue;
      }

      final category = data['category'] as String? ?? 'อื่นๆ';
      final rawAmount = data['amount'];
      final rawDate = data['date'];
      if (rawAmount is! num || rawDate is! String) continue;
      final date = DateTime.tryParse(rawDate);
      if (date == null) continue;

      if (latestDate == null || date.isAfter(latestDate)) latestDate = date;
      final amount = rawAmount.toDouble();
      if (amount <= 0) continue;
      transactions.add(
        _LoadingTransaction(category: category, amount: amount, date: date),
      );
    }

    final newestTransactionDate = latestDate;
    if (newestTransactionDate == null || !mounted) return;
    final currentMonthTransactions = transactions
        .where((transaction) =>
            transaction.date.year == newestTransactionDate.year &&
            transaction.date.month == newestTransactionDate.month &&
            transaction.category != 'transfer')
        .toList();
    if (currentMonthTransactions.isEmpty) return;

    final batchSize =
        ((currentMonthTransactions.length + 11) ~/ 12).clamp(1, 1000000);

    for (var start = 0;
        start < currentMonthTransactions.length;
        start += batchSize) {
      if (!mounted) return;
      final end = (start + batchSize).clamp(0, currentMonthTransactions.length);
      setState(() {
        for (final transaction
            in currentMonthTransactions.sublist(start, end)) {
          _loadingTotals.update(
            transaction.category,
            (total) => total + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Color _categoryColor(String category) =>
      _savedCategoryColors[category] ??
      _defaultCategoryColors[category] ??
      Colors.red;

  IconData _categoryIcon(String category) {
    final savedCode = _savedCategoryIconCodes[category];
    if (savedCode != null) {
      for (final icon in _selectableCategoryIcons) {
        if (icon.codePoint == savedCode) return icon;
      }
    }
    return _defaultCategoryIcons[category] ?? Icons.help_outline;
  }

  List<PieChartSectionData> _buildChartSections(Color emptyColor) {
    final total = _loadingTotals.values.fold<double>(
      0,
      (totalSoFar, value) => totalSoFar + value,
    );
    if (total <= 0) {
      return [
        PieChartSectionData(
          color: emptyColor,
          value: 1,
          title: '',
          radius: 65,
        ),
      ];
    }

    return _loadingTotals.entries.map((entry) {
      final percentage = entry.value / total * 100;
      return PieChartSectionData(
        color: _categoryColor(entry.key),
        value: entry.value,
        title: '',
        radius: 65,
        badgeWidget: percentage >= 6
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIcon(entry.key), color: Colors.white, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        badgePositionPercentageOffset: 0.5,
      );
    }).toList();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _loadingBalance = null;
      _loadingTotals.clear();
      _savedCategoryColors.clear();
      _savedCategoryIconCodes.clear();
    });
    _prepareAndNavigate();
  }

  Widget _buildLoadingCenter(BuildContext context) {
    final username = GuestService.username?.trim() ?? '';
    final displayName = username.isEmpty ? T.get('guestMode') : username;
    final locale = Localizations.localeOf(context).toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          T.get('balance'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 8, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _loadingBalance == null
                ? '--'
                : NumberFormat.currency(
                    locale: locale,
                    symbol: '\u0e3f',
                    decimalDigits: 2,
                  ).format(_loadingBalance),
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;
    if (direction != HeroFlightDirection.push) return toHero.child;

    final easedAnimation =
        CurveTween(curve: Curves.easeInOutCubic).animate(animation);
    final sourceOpacity =
        Tween<double>(begin: 1, end: 0).animate(easedAnimation);
    final destinationOpacity =
        Tween<double>(begin: 0, end: 1).animate(easedAnimation);

    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(opacity: sourceOpacity, child: fromHero.child),
        FadeTransition(opacity: destinationOpacity, child: toHero.child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _buildChartSections(
      theme.colorScheme.surfaceContainerHighest,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: _hasError ? _retry : null,
            child: Hero(
              tag: 'keepTangDashboardPieChart',
              flightShuttleBuilder: _buildPieChartFlightShuttle,
              child: SizedBox.square(
                dimension: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 54,
                        sections: sections,
                      ),
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeInOutCubic,
                    ),
                    IgnorePointer(
                      child: SizedBox(
                        width: 104,
                        child: _buildLoadingCenter(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingTransaction {
  const _LoadingTransaction({
    required this.category,
    required this.amount,
    required this.date,
  });

  final String category;
  final double amount;
  final DateTime date;
}
