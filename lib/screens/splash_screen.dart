import 'package:flutter/material.dart';
import 'dart:async';
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
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), () async {
      // สุ่ม Guest ID ไม่ซ้ำกันให้เครื่องนี้ (ถ้ายังไม่มี) แล้วค่อยถามชื่อผู้ใช้
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 38,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned(
                              top: -8,
                              left: 2,
                              child: Icon(Icons.change_history,
                                  size: 20, color: Colors.black87)),
                          const Positioned(
                              top: -8,
                              right: 2,
                              child: Icon(Icons.change_history,
                                  size: 20, color: Colors.black87)),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          Positioned(
                              top: 14,
                              left: 8,
                              child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle))),
                          Positioned(
                              top: 14,
                              right: 8,
                              child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  T.get('appTitle'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  T.get('loading'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
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
