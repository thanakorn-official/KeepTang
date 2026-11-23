import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountService {
  AccountService._();

  static const _preferAccountKey = 'prefer_email_account';
  static User? _user;

  static User? get user => _user;

  static String get displayName {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _user?.email?.split('@').first ?? '';
  }

  static Future<void> restoreSession() async {
    _user = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8));
  }

  static Future<bool> prefersAccount() async =>
      (await SharedPreferences.getInstance()).getBool(_preferAccountKey) ??
      false;

  static Future<void> continueAsGuest() async {
    await (await SharedPreferences.getInstance()).remove(_preferAccountKey);
  }

  static Future<void> signIn(String email, String password) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    _user = credential.user;
  }

  static Future<void> register(String email, String password) async {
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    _user = credential.user;
  }

  static Future<void> sendPasswordReset(String email, String language) async {
    final auth = FirebaseAuth.instance;
    await auth.setLanguageCode(language);
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Return the same confirmation whether or not the email has an account.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  static Future<void> updateDisplayName(String name) async {
    await _user?.updateDisplayName(name);
    _user = FirebaseAuth.instance.currentUser;
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferAccountKey, true);
    await FirebaseAuth.instance.signOut();
    _user = null;
  }
}
