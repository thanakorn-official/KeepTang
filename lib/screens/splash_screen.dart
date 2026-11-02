import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
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
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _showLoading = true);

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    await GuestService.ensureGuest();
    await GuestService.restoreCustomSettings();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GuestService.hasUsername
            ? const DashboardScreen()
            : const GuestSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        final isSystemDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final logoColor = isSystemDark ? Colors.white : Colors.black;
        final splashBackground =
            isSystemDark ? const Color(0xFF121212) : Colors.white;

        return Scaffold(
          backgroundColor: splashBackground,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: _showLoading
                      ? SizedBox(
                          key: const ValueKey('cat-loading'),
                          width: 184,
                          height: 184,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 144,
                                height: 144,
                                child: CircularProgressIndicator(
                                  strokeWidth: 5,
                                  color: logoColor,
                                  backgroundColor:
                                      logoColor.withValues(alpha: 0.16),
                                ),
                              ),
                              Image.asset(
                                'assets/splash_cat_face.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.contain,
                                color: logoColor,
                                semanticLabel: T.get('appTitle'),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('bill-cat-logo'),
                          width: 184,
                          height: 184,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned(
                                top: -30,
                                left: 0,
                                right: 0,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.34, end: 0),
                                  duration: const Duration(milliseconds: 850),
                                  curve: Curves.easeOutBack,
                                  builder: (context, offset, child) =>
                                      Transform.translate(
                                    offset: Offset(0, offset * 100),
                                    child: child,
                                  ),
                                  child: Image.asset(
                                    'assets/splash_cat_peek.png',
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                    color: logoColor,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/splash_bill.png',
                                  fit: BoxFit.contain,
                                  color: logoColor,
                                  semanticLabel: T.get('appTitle'),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  T.get('appTitle'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: logoColor,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _showLoading
                      ? Padding(
                          key: const ValueKey('loading-text'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            T.get('loading'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: logoColor.withValues(alpha: 0.72),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('no-loading-text'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
