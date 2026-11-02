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
                          key: const ValueKey('bill-loading'),
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
                                'assets/splash_bill_base.png',
                                width: 76,
                                height: 76,
                                fit: BoxFit.contain,
                                color: logoColor,
                                semanticLabel: T.get('appTitle'),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('bill-logo'),
                          width: 184,
                          height: 184,
                          child: Image.asset(
                            'assets/splash_bill_base.png',
                            fit: BoxFit.contain,
                            color: logoColor,
                            semanticLabel: T.get('appTitle'),
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
