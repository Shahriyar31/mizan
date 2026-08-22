/// Sign up / log in — local account, no network.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/settings_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startOnLogin = false});

  final bool startOnLogin;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isLogin = widget.startOnLogin;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    final error = _isLogin
        ? await controller.logIn(
            email: _email.text,
            password: _password.text,
          )
        : await controller.signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    setState(() => _busy = false);
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isLogin ? 'Welcome back' : 'Create your account',
                style: AppTypography.displayLarge(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Sign in to the account saved on this device.'
                    : 'Your account stays on this device. Nothing is uploaded.',
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (!_isLogin) ...[
                _Label('Name'),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  style: AppTypography.bodyLarge(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'How should we greet you?'),
                ),
                const SizedBox(height: 18),
              ],
              _Label('Email'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: AppTypography.bodyLarge(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 18),
              _Label('Password'),
              TextField(
                controller: _password,
                obscureText: _obscure,
                style: AppTypography.bodyLarge(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _isLogin ? 'Your password' : 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _error!,
                    style: AppTypography.bodySmall(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.night),
                        ),
                      )
                    : Text(_isLogin ? 'Log in' : 'Create account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        }),
                child: Text(
                  _isLogin
                      ? 'No account yet? Create one'
                      : 'Already set up? Log in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.labelSmall(color: AppColors.muted),
        ),
      );
}
