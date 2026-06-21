import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
import '../auth/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithOtp(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not send code: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final email = _emailController.text.trim();
    final token = _codeController.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyOtp(email, token);
      // Router redirect navigates to /stories on the signedIn event.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Invalid or expired code: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeEmail() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MagicScaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MagicWordmark(
                    text: 'Dream Book',
                    fontSize: 34,
                    icon: Icons.auto_stories,
                  ),
                  const SizedBox(height: 28),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _codeSent ? 'Check your owl post' : 'Enter the gate',
                          style: AppTheme.displayFont(fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _codeSent
                              ? 'Enter the 6-digit code we emailed you.'
                              : 'Sign in with a one-time email code.',
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            color: MagicColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _emailController,
                          enabled: !_codeSent && !_loading,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          onSubmitted: (_) => _codeSent ? null : _sendCode(),
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _codeController,
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: '6-digit code',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                            onSubmitted: (_) => _verify(),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: AppTheme.bodyFont(
                              fontSize: 13,
                              color: MagicColors.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : (_codeSent ? _verify : _sendCode),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2A1B05),
                                  ),
                                )
                              : Text(_codeSent ? 'Verify' : 'Send code'),
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _loading ? null : _changeEmail,
                                child: const Text('Change email'),
                              ),
                              TextButton(
                                onPressed: _loading ? null : _sendCode,
                                child: const Text('Resend code'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
