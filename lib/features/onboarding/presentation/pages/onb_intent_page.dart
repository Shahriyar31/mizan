/// Screen 5 of 6 — What brings you here?
///
/// Asked last, on purpose. It is the only screen whose answer changes the app,
/// and asking it after the person has seen the layers, the three rooms and the
/// daily rhythm gets a truthful answer rather than a guess. Put this screen
/// first and you get whichever row sounds most virtuous.
///
/// ── The answer is honoured or it should not be asked ──────────────────
/// Each row carries the route the app will open on, once, immediately after
/// sign-in. The answer is written to disk the moment it is tapped — see
/// [OnboardingAnswersController.setIntent] for why that matters at the sign-in
/// boundary — and it stays readable afterwards so Settings can show it and
/// change it, which is what the helper line promises in writing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/onboarding_answers.dart';
import '../widgets/onboarding_kit.dart';

class OnbIntentPage extends ConsumerWidget {
  const OnbIntentPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(onboardingAnswersProvider).intent;

    return OnbScaffold(
      step: 4,
      onSkip: onSkip,
      footer: OnbPrimaryButton(label: 'Continue', onTap: onContinue),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnbEyebrow('So we start you well'),
          const SizedBox(height: 12),
          Text('What brings you here?', style: OnbType.heading()),
          const SizedBox(height: 12),
          Text(
            'Pick one — it decides what your Home opens on. You can change it '
            'any time in Settings.',
            style: OnbType.sans(fontSize: 13.5),
          ),
          const SizedBox(height: 22),
          for (final intent in MizanIntent.values) ...[
            if (intent != MizanIntent.values.first) const SizedBox(height: 10),
            _IntentRow(
              intent: intent,
              selected: chosen == intent,
              onTap: () => ref
                  .read(onboardingAnswersProvider.notifier)
                  .setIntent(intent),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntentRow extends StatelessWidget {
  const _IntentRow({
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  final MizanIntent intent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // inMutuallyExclusiveGroup, so a screen reader announces this as one of a
      // set of choices rather than as four unrelated buttons.
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '${intent.title}. ${intent.subtitle}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color: selected ? OnbTok.gold13 : OnbTok.paper045,
            border: Border.all(color: selected ? OnbTok.gold : OnbTok.gold24),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(intent.icon, size: 23, color: OnbTok.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intent.title,
                      style: OnbType.sans(
                        fontSize: 15,
                        weight: FontWeight.w600,
                        color: OnbTok.paper,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      intent.subtitle,
                      style: OnbType.sans(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Decorative: the Semantics wrapper above already says selected.
              ExcludeSemantics(
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 21,
                  color: selected ? OnbTok.gold : OnbTok.gold45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
