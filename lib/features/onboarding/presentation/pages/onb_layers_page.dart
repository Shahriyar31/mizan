/// Screen 2 of 6 — One ayah, six ways in.
///
/// The layer system, demonstrated rather than described. The panel is a real
/// ayah with its six real layer names and a real gloss under each, because a
/// screen that says "six powerful layers of insight" and shows nothing teaches
/// the reader that the app talks like a brochure.
///
/// ── Why rows 4, 5 and 6 fade ──────────────────────────────────────────
/// Not to hide them, and not because they are locked. The fade is the shape of
/// the idea: the list keeps going past what fits, so six reads as "there is more
/// here than one screen" rather than as a feature count. Take one or take all
/// six — the fade says the choice is real.
library;

import 'package:flutter/material.dart';

import '../widgets/onboarding_kit.dart';

class OnbLayersPage extends StatelessWidget {
  const OnbLayersPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return OnbScaffold(
      step: 1,
      onSkip: onSkip,
      footer: OnbPrimaryButton(label: 'Continue', onTap: onContinue),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnbEyebrow('How Mizan reads'),
          const SizedBox(height: 12),
          Text('One ayah, six ways in', style: OnbType.heading()),
          const SizedBox(height: 12),
          Text(
            'Most apps give you a translation and stop. Mizan opens every '
            'verse into six layers — take one, or take all six.',
            style: OnbType.sans(fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          const _LayerPanel(),
        ],
      ),
    );
  }
}

class _LayerPanel extends StatelessWidget {
  const _LayerPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OnbTok.card,
        border: Border.all(color: OnbTok.gold28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The ayah and its translation both stay readable to a screen reader.
          // Hiding either one is a common shortcut and it is wrong in both
          // directions: hide the Arabic and a sighted-and-blind bilingual reader
          // loses the verse, hide the English and everyone else loses the point.
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'وَاعْتَصِمُوا بِحَبْلِ اللَّهِ',
              style: OnbType.arabic(fontSize: 22),
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'And hold fast to the rope of Allah.',
            style: OnbType.quote(fontSize: 15.5),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: OnbTok.gold22),
          const SizedBox(height: 14),
          for (final layer in _layers)
            Padding(
              padding: EdgeInsets.only(
                bottom: layer == _layers.last ? 0 : 9,
              ),
              child: Opacity(
                // The brief's .62 / .44 / .3 on rows 4, 5 and 6. Applied to the
                // row, not to the text colour, so the numeral and the name fade
                // together and the row keeps its internal contrast.
                opacity: layer.opacity,
                child: _LayerRow(layer),
              ),
            ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow(this.layer);

  final _Layer layer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 13,
          child: Text(
            '${layer.number}',
            style: OnbType.sans(
              fontSize: 13,
              color: OnbTok.gold,
              weight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            layer.name,
            style: OnbType.sans(
              fontSize: 13.5,
              weight: FontWeight.w600,
              color: OnbTok.paper,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: layer.glossArabic == null
              ? Text(
                  layer.gloss,
                  style: OnbType.sans(
                    fontSize: 12.5,
                    color: OnbTok.mistDim,
                    height: 1.5,
                  ),
                )
              // The Words layer's gloss opens on the Arabic word itself, so the
              // one Arabic fragment inside an English line is set in Amiri
              // rather than left to the sans fallback, which renders Arabic
              // without its joins.
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: layer.glossArabic,
                        style: OnbType.arabic(fontSize: 13.5, height: 1.5)
                            .copyWith(color: OnbTok.mist),
                      ),
                      TextSpan(
                        text: layer.gloss,
                        style: OnbType.sans(
                          fontSize: 12.5,
                          color: OnbTok.mistDim,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

@immutable
class _Layer {
  const _Layer({
    required this.number,
    required this.name,
    required this.gloss,
    this.glossArabic,
    this.opacity = 1.0,
  });

  final int number;
  final String name;
  final String gloss;
  final String? glossArabic;
  final double opacity;
}

const _layers = <_Layer>[
  _Layer(
    number: 1,
    name: 'Words',
    glossArabic: 'حَبْل',
    gloss: ' — a rope, a bond, a covenant',
  ),
  _Layer(
    number: 2,
    name: 'Context',
    gloss: 'Two tribes, one truce, year 3 AH',
  ),
  _Layer(
    number: 3,
    name: 'Scholars',
    gloss: 'Four readings of "the rope"',
  ),
  _Layer(
    number: 4,
    name: 'Isnad',
    gloss: 'Who carried it, name by name',
    opacity: 0.62,
  ),
  _Layer(
    number: 5,
    name: 'Similar',
    gloss: 'Nine ayat echo this image',
    opacity: 0.44,
  ),
  _Layer(
    number: 6,
    name: 'Reflection',
    gloss: 'What are you holding onto?',
    opacity: 0.3,
  ),
];
