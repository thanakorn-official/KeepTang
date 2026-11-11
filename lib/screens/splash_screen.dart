import 'dart:async';

import 'package:flutter/material.dart';

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
        const logoColor = Colors.white;

        return Scaffold(
          backgroundColor: AppLogo.backgroundColor,
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
                          key: const ValueKey('logo-loading'),
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
                              AppLogo(
                                size: 104,
                                semanticLabel: T.get('appTitle'),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('app-logo'),
                          width: 184,
                          height: 184,
                          child: AppLogo(
                            size: 184,
                            semanticLabel: T.get('appTitle'),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  T.get('appTitle'),
                  style: const TextStyle(
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
