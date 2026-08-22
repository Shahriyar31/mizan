/// FAQ / How It Works / Terms / Privacy / About — thin wrappers around
/// [MoreContentScreen]. FAQ and How It Works describe the app's actual
/// implemented behavior. Terms and Privacy have no real legal text
/// anywhere in this project — their screens say so rather than
/// inventing legal claims; replace with real copy before release.
library;

import 'package:flutter/material.dart';

import 'more_screen.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'FAQ',
      sections: [
        (
          'Do I need an account?',
          'No. Quran reading, Tafsir, Seerah, Sahaba and Prophet stories, '
              '99 Names, and Quran audio all work fully without signing in.',
        ),
        (
          'What does signing in do?',
          'An account (via Supabase) lets your Halaqa circles and Al-Minbar '
              'posts sync and be visible to others. It is only needed for '
              'those community features.',
        ),
        (
          'Where is my reading data stored?',
          'Reading progress, saved vocabulary, and reflections are stored '
              'locally on your device.',
        ),
        (
          'Does Quran audio work offline?',
          'No — audio streams live from MP3Quran\'s servers. A working '
              'connection is needed to listen.',
        ),
        (
          'Can I change the Arabic font or text size?',
          'Yes, in Settings → Personalisation. Changes apply to the Quran '
              'reader immediately.',
        ),
      ],
    );
  }
}

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'How Taddabur Works',
      sections: [
        (
          'Quran',
          'Read every surah with translation, and reveal word-by-word '
              'meanings by tapping any Arabic word.',
        ),
        (
          'Discover',
          'Explore the 99 Names of Allah, the 25 Prophets, Sahaba, and the '
              'Seerah — each with sourced content.',
        ),
        (
          'Growth',
          'Track vocabulary you\'ve saved and reflections you\'ve written, '
              'and use Al-Meezan to reflect on time given to you.',
        ),
        (
          'Halaqa',
          'Create or join a small private circle to share Quran/Discover '
              'content with people you choose — requires an account.',
        ),
        (
          'Al-Minbar',
          'A public feed where signed-in users can share content and react '
              '— requires an account.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'Terms & Conditions',
      sections: [
        (
          'Not yet available',
          'This app does not have finished Terms & Conditions text yet. '
              'This page exists so the structure is in place — real legal '
              'copy needs to be written and added here before release.',
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'Privacy Policy',
      sections: [
        (
          'Not yet available',
          'This app does not have a finished Privacy Policy yet. This page '
              'exists so the structure is in place — real privacy copy '
              'needs to be written and added here before release.',
        ),
        (
          'What is true today',
          'Reading progress and preferences are stored locally on your '
              'device. Halaqa/Al-Minbar activity is stored in Supabase '
              'only if you create an account.',
        ),
      ],
    );
  }
}

class AboutTaddaburScreen extends StatelessWidget {
  const AboutTaddaburScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'About Taddabur',
      sections: [
        (
          'تَدَبُّر — Taddabur',
          'Every claim in this app carries its source — a Qur\'anic '
              'reference, a named hadith collection, or a named sirah work. '
              'Nothing unsourced is shown.',
        ),
        ('Version', '0.1.0'),
      ],
    );
  }
}
