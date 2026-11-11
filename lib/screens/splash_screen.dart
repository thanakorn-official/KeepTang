import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../main.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import '../widgets/app_logo.dart';
import 'dashboard_screen.dart';
import 'guest_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _finishController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _finishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _prepareAndNavigate();
  }

  Future<void> _prepareAndNavigate() async {
    try {
      await Future.wait<void>([
        Future<void>.delayed(const Duration(milliseconds: 1400)),
        _prepareGuest(),
      ]);
      if (!mounted) return;

      await _finishController.forward();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              GuestService.hasUsername
                  ? const DashboardScreen()
                  : const GuestSetupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 280),
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

  Future<void> _prepareGuest() async {
    await GuestService.ensureGuest();
    await GuestService.restoreCustomSettings();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _finishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = math.min(MediaQuery.sizeOf(context).width * 0.6, 240.0);

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, language, child) => Scaffold(
        backgroundColor: AppLogo.backgroundColor,
        body: Center(
          child: AnimatedBuilder(
            animation: _finishController,
            builder: (context, child) {
              final progress = _finishController.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: logoSize,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: 1 - Curves.easeIn.transform(progress),
                          child: RotationTransition(
                            turns: _ringController,
                            child: SvgPicture.asset(
                              'assets/branding/loading_rings.svg',
                              width: logoSize,
                              height: logoSize,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/branding/loading_receipt.svg',
                          width: logoSize,
                          height: logoSize,
                          semanticsLabel: T.get('appTitle'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: 1 - progress,
                    child: Column(
                      children: [
                        Text(
                          T.get('appTitle'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_hasError) ...[
                          Text(
                            T.get('loadingFailed'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _hasError = false);
                              _prepareAndNavigate();
                            },
                            child: Text(
                              T.get('retry'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ] else
                          Text(
                            T.get('loading'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
