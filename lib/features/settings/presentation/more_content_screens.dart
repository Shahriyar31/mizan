/// FAQ / How It Works / Terms / Privacy / About — thin wrappers around
/// [MoreContentScreen]. Every screen here describes the app's actual
/// implemented behaviour.
///
/// Terms and Privacy used to say "not yet available", which was the wrong thing
/// for sign-up to link to: the account screen asks people to agree to them
/// before they tap Create account, so the two pages that back that sentence
/// cannot be empty. They now hold plain beta-appropriate text, and every claim
/// in the privacy page was checked against the code rather than assumed —
/// notably that no analytics, crash-reporting or advertising SDK exists anywhere
/// in the project, that the Al-Meezan date of birth is a device preference that
/// is never uploaded, and that "Delete account" clears the device but does not
/// yet remove the server row (so the page says so instead of implying it does).
///
/// Both are deliberately short. They will be written out in full before the app
/// stores, and the "Last updated" line is the one thing to change when they are.
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
          'Using Mizan',
          'Mizan is free to use, and it is early — this is a beta. Things will '
              'change, improve, and occasionally break. Use it as a companion to '
              'your reading, not as a replacement for study with people who know '
              'more than either of us.',
        ),
        (
          'Check what you read',
          'Qur\'an text, translations, tafsir and hadith come from established '
              'published sources, and every screen names the source it is showing '
              'you. Sources can still carry mistakes, and so can the way this app '
              'displays them. For anything you intend to act on or teach, confirm '
              'it against a printed copy or ask a qualified scholar.',
        ),
        (
          'What you share',
          'You keep whatever you write or post. You are the one responsible for '
              'it, so share only what you would be comfortable having read by the '
              'people who can see it — your circle, or everyone on Al-Minbar. '
              'Nothing unlawful, and nothing meant to demean another person.',
        ),
        (
          'No warranty',
          'Mizan is provided as it is, with no guarantee that it will be '
              'available, accurate, or free of faults, and without liability for '
              'loss arising from using it. Keep your own copy of anything you '
              'would be sad to lose.',
        ),
        (
          'Changes',
          'These terms will be rewritten properly before Mizan reaches the app '
              'stores. When they change, the date below changes with them.',
        ),
        ('Last updated', 'August 2026 · beta'),
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
          'The short version',
          'Mizan asks for your name, email and a password, and nothing else. '
              'There is no tracking of any kind in this app — no analytics, no '
              'advertising, no third-party measurement. Most of what you do here '
              'never leaves your phone.',
        ),
        (
          'What stays on your phone',
          'Your reflections and Muhasabah answers, saved vocabulary, reading '
              'position, bookmarks, your streak, and every setting you pick. '
              'These are written to this device only. If you set a date of birth '
              'for Al-Meezan, that stays on the device too — it is never sent '
              'anywhere.',
        ),
        (
          'What is stored on the server',
          'Your email and display name, the circles you belong to, and anything '
              'you deliberately share into a circle or onto Al-Minbar. That is '
              'all. Hosting is Supabase.',
        ),
        (
          'Who can see what you share',
          'What you post into a Halaqa circle is visible to the members of that '
              'circle and to nobody else. Al-Minbar is the public one: anyone '
              'using Mizan can see what you post there, so treat it as public.',
        ),
        (
          'Other services Mizan talks to',
          'Qur\'an text, translations, tafsir, hadith and recitation audio are '
              'fetched from published sources — ummahapi.com, Quran.com, '
              'MP3Quran and EveryAyah. They receive only what you are reading, '
              'such as a surah and ayah number. Your name and email are never '
              'sent to them.',
        ),
        (
          'Permissions',
          'Mizan asks for internet access, permission to show notifications, and '
              'permission to restore your reminders after the phone restarts. '
              'Nothing else — no camera, microphone, location, contacts or photos. '
              'Reminders are built on your phone; no notification passes through '
              'a server.',
        ),
        (
          'Removing things',
          'You can delete anything you posted, and a circle you created. '
              'Delete account, in Settings, signs you out and clears everything '
              'Mizan has stored on this device. To have your account row removed '
              'from the server as well, message whoever sent you Mizan and it '
              'will be done by hand — that step is not yet automatic.',
        ),
        (
          'Age',
          'Mizan is meant for ages 13 and up, and is not directed at children '
              'under 13.',
        ),
        (
          'Still being written',
          'This is a beta, and this policy will be written out in full before '
              'Mizan reaches the app stores. Everything stated above is true of '
              'the app as it stands today.',
        ),
        ('Last updated', 'August 2026 · beta'),
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
