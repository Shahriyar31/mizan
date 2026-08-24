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
          'Yes. Mizan opens on the sign-in screen and an account is created '
              'once, in about a minute, with an email and a password. It is '
              'what carries your reflections, your circles and your record '
              'across to your next phone.',
        ),
        (
          'What does my account actually hold?',
          'Your Halaqa circles and your Al-Minbar posts live on the server, so '
              'the people in your circles can see what you share. Your reading '
              'progress, saved vocabulary and reflections stay on this device.',
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
          'Yes, in Settings → Appearance. Changes apply to the Quran '
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
      title: 'How Mizan Works',
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
          'Create or join a small private circle — up to eight people — and '
              'share Quran or Discover content with people you choose.',
        ),
        (
          'Al-Minbar',
          'A public feed where you can share what struck you and react to '
              'what others shared. Reactions only, never comments.',
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
          'Reading progress, saved vocabulary, reflections and preferences are '
              'stored locally on your device. What you share to a Halaqa circle '
              'or to Al-Minbar is stored on our server (Supabase) along with '
              'your email and display name, because those features exist to be '
              'seen by other people.',
        ),
      ],
    );
  }
}

class AboutMizanScreen extends StatelessWidget {
  const AboutMizanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoreContentScreen(
      title: 'About Mizan',
      sections: [
        (
          'ميزان — Mizan',
          'Every claim in this app carries its source — a Qur\'anic '
              'reference, a named hadith collection, or a named sirah work. '
              'Nothing unsourced is shown.',
        ),
        ('Version', '0.1.0'),
      ],
    );
  }
}
