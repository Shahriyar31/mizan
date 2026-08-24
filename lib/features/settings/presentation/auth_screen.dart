/// Create an account, sign in to one, or get back into one — real Supabase Auth,
/// over the network.
///
/// ── What this screen used to claim, and why that had to go ─────────────
/// Both this file's own header and the line under its title used to say the
/// account was local and that nothing was uploaded. That was true of an earlier
/// build and is not true of this one: sign-up posts an email address, a password
/// and a display name to Supabase, and the display name is mirrored into
/// `public.users`. A privacy claim that is false is worse than no claim, so the
/// copy now says plainly what leaves the device and what does not.
///
/// ── Four modes, one screen ─────────────────────────────────────────────
/// This was a `bool _isLogin`. It is now a four-state [_Mode], because two ways
/// of being permanently locked out had no way out of them:
///
///  * **A forgotten password.** There was no reset anywhere in the app, and the
///    reflections, circles and record are all tied to the account. So a forgotten
///    password did not mean an inconvenience, it meant the work was gone.
///  * **A confirmation email that never arrived.** Sign-up tells the person to
///    check their inbox. If that email is filtered, deleted or simply lost, the
///    account exists but cannot be used: signing up again answers "that email
///    already has an account", and logging in answers "please confirm your email
///    first". A closed loop, with the account visible through the glass.
///
/// Both are handled here rather than on new routes, because the recovery modes
/// share the email field, the busy flag, the single message slot and the whole
/// validation apparatus with the two modes that were already here. A separate
/// route would have duplicated all of it.
///
/// ── Signing in is required, and this screen is the gate ────────────────
/// It used to be optional, and this header used to say so. It is not any more:
/// `AppRouter` guards every route except `/welcome` and `/auth`, so a person
/// without a session reaches exactly this screen and nothing else. The reason is
/// that everything the app keeps for somebody — reflections, circles, their
/// record — is keyed to a user id, and the alternative was a second, local,
/// eventually-merged copy of every one of those features.
///
/// Two consequences live in this file. `/auth?from=welcome` marks the two ways
/// in from the onboarding flow, which changes where a success lands: back to
/// Settings is right for somebody who came from Settings to fix their account,
/// and wrong for somebody who has just finished onboarding and asked, on Screen
/// 5, for a particular room. And the back tile cannot go to Settings while
/// signed out, because the guard would bounce it straight back here; it returns
/// to the welcome flow instead, which is the only other signed-out surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../../onboarding/domain/session_gate.dart';
import '../data/auth_repository.dart';
import '../domain/settings_providers.dart';

/// The four things this screen can be.
///
/// [requestCode] and [enterCode] are the two halves of a password reset. They are
/// two modes rather than one because the person has to leave the app to fetch the
/// code, and a single screen holding an email field, a code field and a new
/// password field would show all three at once — two of them unusable, with no
/// indication of which one to fill first.
enum _Mode { logIn, signUp, requestCode, enterCode }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.startOnLogin = false,
    this.fromWelcome = false,
  });

  final bool startOnLogin;

  /// True when the onboarding flow handed the person here.
  ///
  /// Decides two things, both of which would be wrong the other way round: a
  /// success lands on the room they asked for on Screen 5 rather than on
  /// Settings, and the back tile returns to the flow rather than to Settings,
  /// which the router would bounce.
  final bool fromWelcome;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late _Mode _mode = widget.startOnLogin ? _Mode.logIn : _Mode.signUp;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;

  /// The message under the form, and whether it is a failure or a next step.
  /// A single field for both so the two can never be shown at once.
  AuthResult? _result;

  List<TextEditingController> get _controllers =>
      [_name, _email, _password, _code, _newPassword];

  @override
  void initState() {
    super.initState();
    // The button enables itself the moment the form is valid, so it has to
    // rebuild as the user types. Cheaper than a Form + GlobalKey for five
    // fields, and it means the *same* validator decides both the enabled state
    // and the message, instead of two rules drifting apart.
    for (final c in _controllers) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _newPasswordFocus.dispose();
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

  // ── Validation ────────────────────────────────────────────────────

  String? get _localError {
    switch (_mode) {
      case _Mode.logIn:
        return AuthRepository.validateLogIn(
          email: _email.text,
          password: _password.text,
        );
      case _Mode.signUp:
        return AuthRepository.validateSignUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      case _Mode.requestCode:
        return AuthRepository.validateEmail(_email.text);
      case _Mode.enterCode:
        if (_code.text.trim().length < 6) return 'Enter the six-digit code.';
        if (_newPassword.text.length < 6) return 'Use at least 6 characters.';
        return null;
    }
  }

  bool get _canSubmit => !_busy && _localError == null;

  /// Whether to offer sending the confirmation email again.
  ///
  /// Only when it is the actual next step, which is exactly the two moments the
  /// word "confirm" appears in a result: the notice after a sign-up that needs
  /// confirming, and the failure when logging in to an unconfirmed account. A
  /// permanent "resend confirmation" control on the log-in screen would be noise
  /// for everybody else, and slightly alarming — it implies something is wrong.
  bool get _offerResend {
    if (_mode != _Mode.logIn) return false;
    final message = _result?.message?.toLowerCase();
    return message != null && message.contains('confirm');
  }

  // ── Actions ───────────────────────────────────────────────────────

  /// Where a successful sign-in goes, and the one place the onboarding answer is
  /// honoured.
  ///
  /// From Settings, back to Settings: that person came here to fix their account
  /// and expects to be returned to where they were. From the welcome flow, the
  /// room they picked on Screen 5 — taken and marked consumed in a single step,
  /// so it decides the first launch and no launch after it. Home when they
  /// skipped the question, which is a valid answer and must not be guessed at.
  ///
  /// This is the account boundary the brief warns about: an answer collected in
  /// onboarding and dropped here is the most common bug in a flow like this, and
  /// it is silent — the app simply opens on the wrong screen and nobody can say
  /// why.
  Future<void> _leaveOnSuccess() async {
    if (!widget.fromWelcome) {
      if (!mounted) return;
      context.go('/settings');
      return;
    }

    // Read the notifier before the await. This State can be disposed while the
    // stored answer is being read, and `ref` is not usable after that.
    final answers = ref.read(onboardingAnswersProvider.notifier);
    final landing = await answers.takeLanding();
    if (!mounted) return;
    context.go(landing ?? '/home');
  }

  /// Wraps every network action in the same busy/mounted/message discipline, so
  /// no individual handler can forget to clear `_busy` on some path.
  Future<AuthResult?> _run(Future<AuthResult> Function() action) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await action();
    if (!mounted) return null;
    setState(() => _busy = false);
    return result;
  }

  Future<void> _submit() async {
    // Two guards, not one. `_busy` stops a second tap while the request is in
    // flight; the validity check stops a submit arriving from the keyboard's
    // "done" key, which fires whether or not the button is enabled.
    if (!_canSubmit) {
      final error = _localError;
      if (error != null) setState(() => _result = AuthResult.failure(error));
      return;
    }

    switch (_mode) {
      case _Mode.logIn:
      case _Mode.signUp:
        await _submitCredentials();
      case _Mode.requestCode:
        await _sendCode(advance: true);
      case _Mode.enterCode:
        await _completeReset();
    }
  }

  Future<void> _submitCredentials() async {
    final controller = ref.read(authControllerProvider.notifier);
    final isLogin = _mode == _Mode.logIn;
    final result = await _run(
      () => isLogin
          ? controller.logIn(email: _email.text, password: _password.text)
          : controller.signUp(
              name: _name.text,
              email: _email.text,
              password: _password.text,
            ),
    );
    if (result == null) return;

    if (result.isOk) {
      // `_run` already returned null if this State was disposed, but the
      // analyser cannot see through that indirection, and a redundant check is
      // cheaper than a lint suppression that would also hide a real one later.
      if (!mounted) return;
      await _leaveOnSuccess();
      return;
    }

    setState(() {
      _result = result;
      // A notice means the account exists and needs confirming, so the next
      // useful action is logging in — not filling this form in again. The
      // password is kept: the same one will work once the email is confirmed.
      if (result.outcome == AuthOutcome.notice) _mode = _Mode.logIn;
    });
  }

  /// Asks for a code. Used both by the "Send me a code" button and by "Send a
  /// new code" on the next screen, which is why advancing the mode is a flag
  /// rather than being baked in.
  Future<void> _sendCode({required bool advance}) async {
    final emailError = AuthRepository.validateEmail(_email.text);
    if (emailError != null) {
      setState(() => _result = AuthResult.failure(emailError));
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    final result = await _run(() => controller.requestPasswordReset(_email.text));
    if (result == null) return;
    setState(() {
      // Carried across deliberately. "A code is on its way" has to be readable
      // on the screen where the code gets typed, not on the one being left.
      _result = result;
      if (advance && !result.isFailure) _mode = _Mode.enterCode;
    });
  }

  /// Verifies the code, then sets the password — two calls, one button.
  ///
  /// Split across two screens this would have been worse in two ways: the code
  /// has an expiry, and it would be running while somebody thinks up a password;
  /// and it would cost an extra screen for no decision. Nothing is cleared on
  /// failure — a wrong sixth digit should not cost somebody the password they
  /// just typed.
  Future<void> _completeReset() async {
    final controller = ref.read(authControllerProvider.notifier);

    final verified = await _run(
      () => controller.verifyRecoveryCode(email: _email.text, code: _code.text),
    );
    if (verified == null) return;
    if (!verified.isOk) {
      setState(() => _result = verified);
      return;
    }

    final saved = await _run(() => controller.setNewPassword(_newPassword.text));
    if (saved == null) return;

    if (saved.isOk) {
      // The same landing as a successful log-in, because that is what this now
      // is: the person is signed in on the new password.
      if (!mounted) return;
      await _leaveOnSuccess();
      return;
    }
    setState(() => _result = saved);
  }

  Future<void> _resendConfirmation() async {
    final result = await _run(
      () => ref
          .read(authControllerProvider.notifier)
          .resendConfirmation(_email.text),
    );
    if (result == null) return;
    setState(() => _result = result);
  }

  /// The back tile. Inside a recovery mode it steps back to log-in rather than
  /// leaving — abandoning the whole screen because somebody wanted to correct a
  /// mistyped email address would be a trap of its own.
  void _back() {
    if (_mode == _Mode.requestCode || _mode == _Mode.enterCode) {
      setState(() {
        _mode = _Mode.logIn;
        _result = null;
        _code.clear();
        _newPassword.clear();
      });
      return;
    }
    // Settings only while there is a session. Signed out, the router guard would
    // send `/settings` straight back to this screen and reset the mode with it,
    // which reads as the button being broken. The welcome flow is the only other
    // surface that exists without an account, so that is where back goes.
    context.go(SessionGate.signedIn ? '/settings' : '/welcome');
  }

  // ── Copy ──────────────────────────────────────────────────────────

  String get _title {
    switch (_mode) {
      case _Mode.logIn:
        return 'Welcome back';
      case _Mode.signUp:
        return 'Create your account';
      case _Mode.requestCode:
        return 'Reset your password';
      case _Mode.enterCode:
        return 'Check your email';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case _Mode.logIn:
        return 'Sign in to reach your Halaqa circles and your Al-Minbar posts '
            'from any device.';
      case _Mode.signUp:
        return 'Your reflections, your circles and your record are tied to '
            'your account — so they follow you to your next phone.';
      case _Mode.requestCode:
        return 'Enter the address you signed up with and we will email you a '
            'six-digit code.';
      case _Mode.enterCode:
        return 'Type the six-digit code from the email, then choose a new '
            'password. The code lasts one hour.';
    }
  }

  String get _primaryLabel {
    if (_busy) {
      switch (_mode) {
        case _Mode.logIn:
          return 'Signing in…';
        case _Mode.signUp:
          return 'Creating…';
        case _Mode.requestCode:
          return 'Sending…';
        case _Mode.enterCode:
          return 'Saving…';
      }
    }
    switch (_mode) {
      case _Mode.logIn:
        return 'Log in';
      case _Mode.signUp:
        return 'Create account';
      case _Mode.requestCode:
        return 'Send me a code';
      case _Mode.enterCode:
        return 'Set new password';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final isRecovery = _mode == _Mode.requestCode || _mode == _Mode.enterCode;

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
                    onTap: _busy ? null : _back,
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
                  Text(_title, style: MizanType.screenTitle(color: p.ink)),
                  const SizedBox(height: 8),
                  Text(_subtitle, style: MizanType.body(color: p.muted)),
                  const SizedBox(height: 26),

                  if (_mode == _Mode.signUp) ...[
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

                  // Shown in every mode except the code screen, where the
                  // address has already been used and changing it would
                  // invalidate the code that was just sent.
                  if (_mode != _Mode.enterCode) ...[
                    const _Label('Email'),
                    TextField(
                      controller: _email,
                      focusNode: _emailFocus,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _mode == _Mode.requestCode
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      style: MizanType.body(color: p.ink),
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                      ),
                      onSubmitted: (_) => _mode == _Mode.requestCode
                          ? _submit()
                          : _passwordFocus.requestFocus(),
                    ),
                  ],

                  if (_mode == _Mode.logIn || _mode == _Mode.signUp) ...[
                    const SizedBox(height: 18),
                    const _Label('Password'),
                    TextField(
                      controller: _password,
                      focusNode: _passwordFocus,
                      enabled: !_busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _mode == _Mode.logIn
                            ? AutofillHints.password
                            : AutofillHints.newPassword,
                      ],
                      style: MizanType.body(color: p.ink),
                      decoration: InputDecoration(
                        hintText: _mode == _Mode.logIn
                            ? 'Your password'
                            : 'At least 6 characters',
                        suffixIcon: _ObscureToggle(
                          obscure: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],

                  if (_mode == _Mode.enterCode) ...[
                    const _Label('Six-digit code'),
                    TextField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      style: MizanType.body(color: p.ink),
                      decoration: const InputDecoration(
                        hintText: '000000',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _newPasswordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 18),
                    const _Label('New password'),
                    TextField(
                      controller: _newPassword,
                      focusNode: _newPasswordFocus,
                      enabled: !_busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      style: MizanType.body(color: p.ink),
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        suffixIcon: _ObscureToggle(
                          obscure: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],

                  // Directly under the password, where somebody realises they
                  // cannot remember it — not buried at the bottom of the screen
                  // under the create-account toggle.
                  if (_mode == _Mode.logIn)
                    Align(
                      alignment: Alignment.centerRight,
                      child: MizanButton.quiet(
                        label: 'Forgot password?',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  // The email carries over. Making somebody
                                  // retype an address they typed ten seconds
                                  // ago is the sort of thing that makes a
                                  // recovery flow feel like a punishment.
                                  _mode = _Mode.requestCode;
                                  _result = null;
                                }),
                      ),
                    ),

                  if (_result?.message != null) ...[
                    const SizedBox(height: 16),
                    _Message(result: _result!),
                  ],

                  if (_offerResend) ...[
                    const SizedBox(height: 10),
                    MizanButton.quiet(
                      label: 'Resend confirmation email',
                      expand: true,
                      onPressed: _busy ? null : _resendConfirmation,
                    ),
                  ],

                  const SizedBox(height: 26),
                  MizanButton(
                    label: _primaryLabel,
                    expand: true,
                    // Null while invalid or in flight, which is what greys the
                    // button out — there is no second disabled flag to keep in
                    // step with it.
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 10),

                  if (_mode == _Mode.enterCode)
                    MizanButton.quiet(
                      label: 'Send a new code',
                      expand: true,
                      onPressed: _busy ? null : () => _sendCode(advance: false),
                    )
                  else if (isRecovery)
                    MizanButton.quiet(
                      label: 'Back to log in',
                      expand: true,
                      onPressed: _busy ? null : _back,
                    )
                  else
                    MizanButton.quiet(
                      label: _mode == _Mode.logIn
                          ? 'No account yet? Create one'
                          : 'Already have an account? Log in',
                      expand: true,
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _mode = _mode == _Mode.logIn
                                    ? _Mode.signUp
                                    : _Mode.logIn;
                                _result = null;
                              }),
                    ),

                  const SizedBox(height: 18),
                  // This used to read "You can keep using Mizan without an
                  // account", which stopped being true the moment the router
                  // started guarding every route. Leaving it would have been the
                  // worst kind of stale copy: a promise, made at the exact
                  // moment somebody is deciding whether to trust the app, that
                  // the next tap breaks.
                  //
                  // What replaces it is the consent line, because this is where
                  // consent is actually given — the onboarding flow's own
                  // sign-in screen carries the same sentence, and somebody who
                  // arrives here from Settings has never seen that one.
                  if (!isRecovery) _LegalLine(palette: p),
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
//  LEGAL LINE
// ══════════════════════════════════════════════════════════════════════

/// "By continuing you agree to our Terms and Privacy Policy", with both
/// tappable.
///
/// A `RichText` with `TapGestureRecognizer` would be the tidier widget, but a
/// recogniser has to be disposed and this is a stateless leaf. A `Wrap` of small
/// `GestureDetector`s costs a few more lines and cannot leak. It also wraps
/// correctly at every width the app supports, which a single centred line of
/// rich text does not.
///
/// Both destinations are in `AppRouter._openRoutes` — a link to terms you cannot
/// open until after you have accepted them is not a link.
class _LegalLine extends StatelessWidget {
  const _LegalLine({required this.palette});

  final MizanPalette palette;

  @override
  Widget build(BuildContext context) {
    final plain = MizanType.body(color: palette.muted).copyWith(fontSize: 12.5);
    final link = plain.copyWith(
      color: palette.accentText,
      fontWeight: FontWeight.w600,
    );

    Widget tap(String label, String route) => GestureDetector(
          onTap: () => context.push(route),
          // The text is 12.5pt, well under the 44pt minimum on its own, so the
          // padding is what makes it reachable rather than decoration.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Text(label, style: link),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: plain),
        tap('Terms', '/settings/more/terms'),
        Text(' and ', style: plain),
        tap('Privacy Policy', '/settings/more/privacy'),
        Text('.', style: plain),
      ],
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

/// The eye in the corner of a password field. Extracted only because there are
/// now three password fields across the four modes and they must not drift.
class _ObscureToggle extends StatelessWidget {
  const _ObscureToggle({required this.obscure, required this.onPressed});

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        size: 20,
        color: p.muted,
      ),
      tooltip: obscure ? 'Show password' : 'Hide password',
      onPressed: onPressed,
    );
  }
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
