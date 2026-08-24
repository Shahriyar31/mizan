/// Screen 6 of 6 — Save your place.
///
/// Sign-in is required. The app does not open without an account, because
/// everything it keeps for somebody — their reflections, their circles, their
/// record — is keyed to a user id, and a "try it first" mode would either throw
/// all of that away at sign-up or need a whole second, local, eventually-merged
/// copy of it. No step dots and no Skip here: there is nothing left to step
/// through and nothing to skip.
///
/// ── Only one provider, and why that is the compliant choice ───────────
/// The brief asks for Apple, Google and email, with Apple first on iOS. Mizan
/// has no OAuth at all — there is no `signInWithOAuth` call, no
/// `google_sign_in`, no Apple credential flow anywhere in `lib/` — so Apple and
/// Google buttons here would be two buttons that cannot work. The brief's own
/// rule resolves this cleanly: Apple Sign In is mandatory *if any third-party
/// provider is offered*. Offering none means none is required, so email-only is
/// both honest and App Store compliant. When OAuth is added, this screen is the
/// one place that gains buttons.
///
/// The brief's other condition on email is already met: "do not ship a password
/// field without a working reset." The reset exists — a six-digit recovery code
/// through `verifyOTP`, because the Android manifest carries no deep-link intent
/// filter for a reset link.
///
/// ── The two controls go to two different places ───────────────────────
/// Not one action wearing two hats. `/auth` opens in create-account mode;
/// `/auth?login=1` opens in sign-in mode. Both land on the app's single real
/// auth screen — building a second sign-in form inside onboarding would mean two
/// implementations of the same flow drifting apart.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../widgets/onboarding_kit.dart';

class OnbSignInPage extends StatelessWidget {
  const OnbSignInPage({
    super.key,
    required this.onCreateAccount,
    required this.onSignIn,
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return OnbScaffold(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The flow's own gold pill rather than the brief's paper-filled Apple
          // treatment. With a single provider there is no set of provider
          // buttons to be consistent *with*, and the person has pressed this
          // exact button on four screens already.
          OnbPrimaryButton(
            label: 'Continue with email',
            onTap: onCreateAccount,
          ),
          const SizedBox(height: 16),
          OnbQuietButton(
            label: 'Already have an account? ',
            emphasis: 'Sign in',
            onTap: onSignIn,
          ),
          const SizedBox(height: 14),
          _LegalFooter(onTerms: onTerms, onPrivacy: onPrivacy),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnbEyebrow('One last thing'),
          const SizedBox(height: 12),
          Text('Save your place', style: OnbType.heading()),
          const SizedBox(height: 12),
          Text(
            'Your reflections, your circles and your record are tied to your '
            'account — so they follow you to your next phone.',
            style: OnbType.sans(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// "By continuing you agree to our Terms and Privacy Policy."
///
/// Both are real screens in the app, so they are reachable rather than
/// decorative. There is no `url_launcher` in the project and no hosted policy
/// page, and a link that does nothing on the screen where somebody agrees to it
/// is worse than no link.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final base = OnbType.sans(fontSize: 12, height: 1.55);
    final link = base.copyWith(
      color: OnbTok.gold,
      fontWeight: FontWeight.w600,
    );

    return Semantics(
      container: true,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'By continuing you agree to our '),
            TextSpan(
              text: 'Terms',
              style: link,
              // A recogniser rather than a nested GestureDetector, so the tap
              // lands on the word instead of on the whole paragraph.
              recognizer: _tap(onTerms),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: link,
              recognizer: _tap(onPrivacy),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// Recognisers are stateful and want disposing; these two live for exactly as
// long as the screen does and the screen is the last one in the flow, so a
// factory here is honest about the trade rather than pretending otherwise.
TapGestureRecognizer _tap(VoidCallback onTap) =>
    TapGestureRecognizer()..onTap = onTap;
