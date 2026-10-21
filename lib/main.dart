import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

final ValueNotifier<String> themeNotifier = ValueNotifier<String>('light');

final ValueNotifier<String> languageNotifier = ValueNotifier<String>('th');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();

  final savedLang = prefs.getString('selected_language') ?? 'th';
  languageNotifier.value = savedLang == 'en' ? 'en' : 'th';

  final savedTheme = prefs.getString('app_theme_mode') ?? 'light';
  themeNotifier.value = savedTheme == 'dark' ? 'dark' : 'light';

  languageNotifier.addListener(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'selected_language',
      languageNotifier.value,
    );
  });

  themeNotifier.addListener(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'app_theme_mode',
      themeNotifier.value,
    );
  });

  runApp(const KeepTangApp());
}

class KeepTangApp extends StatelessWidget {
  const KeepTangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, _) {
        return ValueListenableBuilder<String>(
          valueListenable: themeNotifier,
          builder: (context, currentThemeKey, _) {
            return MaterialApp(
              title: currentLang == 'th' ? 'เก็บตัง' : 'KeepTang',
              debugShowCheckedModeBanner: false,
              locale: Locale(currentLang),
              supportedLocales: const [
                Locale('th'),
                Locale('en'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppThemes.getTheme(currentThemeKey),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
