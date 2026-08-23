/// Create an account, or sign in to one — real Supabase Auth, over the network.
///
/// ── What this screen used to claim, and why that had to go ─────────────
/// Both this file's own header and the line under its title used to say the
/// account was local and that nothing was uploaded. That was true of an earlier
/// build and is not true of this one: sign-up posts an email address, a password
/// and a display name to Supabase, and the display name is mirrored into
/// `public.users`. A privacy claim that is false is worse than no claim, so the
/// copy now says plainly what leaves the device and what does not.
///
/// ── Signing in is optional, and stays optional ─────────────────────────
/// There is no router guard anywhere in the app. Every tab works signed out,
/// reading and layer progress live in SQLite on the device either way, and this
/// screen is reachable only from Settings › account. The subtitle says what an
/// account is *for* — carrying Halaqa circles and Al-Minbar posts to a second
/// device — rather than implying it is required.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../data/auth_repository.dart';
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;

  /// The message under the form, and whether it is a failure or a next step.
  /// A single field for both so the two can never be shown at once.
  AuthResult? _result;

  @override
  void initState() {
    super.initState();
    // The button enables itself the moment the form is valid, so it has to
    // rebuild as the user types. Cheaper than a Form + GlobalKey for three
    // fields, and it means the *same* validator decides both the enabled state
    // and the message, instead of two rules drifting apart.
    for (final c in [_name, _email, _password]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    // Editing after a rejection clears it: leaving "Wrong email or password"
    // under a field the user is busy correcting reads as if it were about the
    // new value.
    setState(() {
      if (_result?.isFailure == true) _result = null;
    });
  }

  String? get _localError => _isLogin
      ? AuthRepository.validateLogIn(
          email: _email.text,
          password: _password.text,
        )
      : AuthRepository.validateSignUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );

  bool get _canSubmit => !_busy && _localError == null;

  Future<void> _submit() async {
    // Two guards, not one. `_busy` stops a second tap while the request is in
    // flight; the validity check stops a submit arriving from the keyboard's
    // "done" key, which fires whether or not the button is enabled.
    if (!_canSubmit) {
      final error = _localError;
      if (error != null) setState(() => _result = AuthResult.failure(error));
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
    });

    final controller = ref.read(authControllerProvider.notifier);
    final result = _isLogin
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

    if (result.isOk) {
      setState(() => _busy = false);
      context.go('/settings');
      return;
    }

    setState(() {
      _busy = false;
      _result = result;
      // A notice means the account exists and needs confirming, so the next
      // useful action is logging in — not filling this form in again. The
      // password is kept: the same one will work once the link is clicked.
      if (result.outcome == AuthOutcome.notice) _isLogin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(MizanGeometry.gutter, 6, 12, 2),
              child: Row(
                children: [
                  MizanIconTile(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Back',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MizanGeometry.gutter,
                  10,
                  MizanGeometry.gutter,
                  40,
                ),
                children: [
                  Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: MizanType.screenTitle(color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to reach your Halaqa circles and your '
                            'Al-Minbar posts from any device.'
                        : 'Optional. An account carries your Halaqa circles and '
                            'Al-Minbar posts between devices — everything you '
                            'read stays on this one either way.',
                    style: MizanType.body(color: p.muted),
                  ),
                  const SizedBox(height: 26),

                  if (!_isLogin) ...[
                    const _Label('Name'),
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      style: MizanType.body(color: p.ink),
                      decoration: const InputDecoration(
                        hintText: 'The name your circle will see',
                      ),
                      onSubmitted: (_) => _emailFocus.requestFocus(),
                    ),
                    const SizedBox(height: 18),
                  ],

                  const _Label('Email'),
                  TextField(
                    controller: _email,
                    focusNode: _emailFocus,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    style: MizanType.body(color: p.ink),
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 18),

                  const _Label('Password'),
                  TextField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: !_busy,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      _isLogin
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    style: MizanType.body(color: p.ink),
                    decoration: InputDecoration(
                      hintText:
                          _isLogin ? 'Your password' : 'At least 6 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 20,
                          color: p.muted,
                        ),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_result?.message != null) ...[
                    const SizedBox(height: 16),
                    _Message(result: _result!),
                  ],

                  const SizedBox(height: 26),
                  MizanButton(
                    label: _busy
                        ? (_isLogin ? 'Signing in…' : 'Creating…')
                        : (_isLogin ? 'Log in' : 'Create account'),
                    expand: true,
                    // Null while invalid or in flight, which is what greys the
                    // button out — there is no second disabled flag to keep in
                    // step with it.
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 10),
                  MizanButton.quiet(
                    label: _isLogin
                        ? 'No account yet? Create one'
                        : 'Already have an account? Log in',
                    expand: true,
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _result = null;
                            }),
                  ),
                  const SizedBox(height: 18),
                  // Said here as well as on the welcome screen, because this is
                  // the one place somebody might assume they are being made to
                  // sign up.
                  Text(
                    'You can keep using Mizan without an account. Reading, '
                    'layers and progress are stored on this device.',
                    textAlign: TextAlign.center,
                    style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  FIELD LABEL + MESSAGE
// ══════════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 7),
        child: MizanSectionLabel(text),
      );
}

/// The one line under the form. A failure is bordered in the error colour; a
/// next-step notice is bordered in sage, because "check your email" is good news
/// and a red box would read as a rejection of a sign-up that worked.
class _Message extends StatelessWidget {
  const _Message({required this.result});

  final AuthResult result;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final failed = result.isFailure;
    // The palette carries no error token — the Mizan spec never defines one —
    // so a failure borrows the accent's weight rather than introducing a red
    // that belongs to no theme. Sage for the notice, which is a real token.
    final edge = failed ? p.accentText : p.sage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: MizanGeometry.cardBorderRadius,
        border: Border.all(color: edge.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.mark_email_read_outlined,
            size: 19,
            color: edge,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              result.message!,
              style: MizanType.body(color: p.ink).copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
