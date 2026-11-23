import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/account_service.dart';
import '../services/guest_service.dart';
import '../utils/l10n.dart';
import '../widgets/app_logo.dart';
import 'guest_setup_screen.dart';
import 'splash_screen.dart';

enum _AccountForm { signIn, register, reset }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _AccountForm _mode = _AccountForm.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  bool _resetSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _switchTo(_AccountForm mode) {
    final email = _email.text;
    _form.currentState?.reset();
    _email.text = email;
    _password.clear();
    _confirmation.clear();
    setState(() {
      _mode = mode;
      _error = null;
      _resetSent = false;
      _showPassword = false;
    });
  }

  Future<void> _submit() async {
    if (_busy || _form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _resetSent = false;
    });
    try {
      final email = _email.text.trim();
      if (_mode == _AccountForm.reset) {
        await AccountService.sendPasswordReset(email, languageNotifier.value);
        if (mounted) setState(() => _resetSent = true);
        return;
      }
      if (_mode == _AccountForm.register) {
        await AccountService.register(email, _password.text);
      } else {
        await AccountService.signIn(email, _password.text);
      }
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _errorFor(error.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'authUnavailable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorFor(String code) => switch (code) {
        'invalid-email' => 'authInvalidEmail',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'user-disabled' =>
          'authInvalidCredentials',
        'email-already-in-use' => 'authEmailInUse',
        'weak-password' ||
        'password-does-not-meet-requirements' =>
          'authWeakPassword',
        'too-many-requests' => 'authTooManyAttempts',
        'network-request-failed' => 'authNetworkError',
        'operation-not-allowed' => 'authProviderDisabled',
        _ => 'authUnavailable',
      };

  Future<void> _continueAsGuest() async {
    setState(() => _busy = true);
    try {
      await AccountService.continueAsGuest();
      if (!mounted) return;
      final destination = GuestService.hasActiveGuest
          ? const SplashScreen()
          : const GuestSetupScreen();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'authUnavailable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registering = _mode == _AccountForm.register;
    final resetting = _mode == _AccountForm.reset;
    final theme = Theme.of(context);
    final title = T.get(switch (_mode) {
      _AccountForm.signIn => 'authSignIn',
      _AccountForm.register => 'authRegister',
      _AccountForm.reset => 'authResetPassword',
    });

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(actions: [
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => languageNotifier.value =
                    languageNotifier.value == 'th' ? 'en' : 'th',
            icon: const Icon(Icons.language),
            label: Text(languageNotifier.value == 'th' ? 'EN' : 'ไทย'),
          ),
        ]),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 76)),
                        const SizedBox(height: 20),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          T.get(
                              resetting ? 'authResetHelp' : 'authAccountHelp'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: resetting
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: resetting ? (_) => _submit() : null,
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? null
                                  : T.get('authInvalidEmail'),
                          decoration: InputDecoration(
                            labelText: T.get('authEmail'),
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                        ),
                        if (!resetting) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: !_showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: [
                              registering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: registering
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted:
                                registering ? null : (_) => _submit(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return T.get('authPasswordRequired');
                              }
                              return registering && value.length < 6
                                  ? T.get('authWeakPassword')
                                  : null;
                            },
                            decoration: InputDecoration(
                              labelText: T.get('authPassword'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: T.get(_showPassword
                                    ? 'authHidePassword'
                                    : 'authShowPassword'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _showPassword = !_showPassword),
                                icon: Icon(_showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                              ),
                            ),
                          ),
                        ],
                        if (registering) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmation,
                            enabled: !_busy,
                            obscureText: !_showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) => value == _password.text
                                ? null
                                : T.get('authPasswordMismatch'),
                            decoration: InputDecoration(
                              labelText: T.get('authConfirmPassword'),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
                        if (_error != null || _resetSent) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              T.get(_error ?? 'authResetSent'),
                              style: TextStyle(
                                color: _error == null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  resetting ? T.get('authSendReset') : title),
                        ),
                        if (_mode == _AccountForm.signIn) ...[
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _switchTo(_AccountForm.reset),
                            child: Text(T.get('authForgotPassword')),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _switchTo(_AccountForm.register),
                            child: Text(T.get('authRegister')),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _continueAsGuest,
                            child: Text(T.get('authContinueGuest')),
                          ),
                        ] else
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _switchTo(_AccountForm.signIn),
                            child: Text(T.get('authBackToSignIn')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
