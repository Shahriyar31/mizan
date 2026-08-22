/// ContentVisuals — the single source of truth for how each content type looks.
///
/// The README's vision for Al-Minbar is that every content type is a distinct
/// "physical material" (a Qur'an card feels different from a companion's story).
/// Both the Halaqa feed and the Al-Minbar feed render shared content, so this
/// mapping lives in one shared place — change a colour or icon here and every
/// card in the app updates together.
///
/// Colours are only ever [AppColors] tokens (never raw hex), per the project's
/// colour-system rule.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/shared_content.dart';

class ContentVisuals {
  const ContentVisuals({
    required this.background,
    required this.accent,
    required this.icon,
  });

  /// The card's material background.
  final Color background;

  /// The type's identity colour — used for the badge and the type icon.
  final Color accent;

  /// The small glyph shown in the type badge.
  final IconData icon;

  static ContentVisuals of(ContentType type) => switch (type) {
        ContentType.quran =>  ContentVisuals(
            background: AppColors.cardQuranBg,
            accent: AppColors.gold,
            icon: Icons.menu_book_rounded,
          ),
        ContentType.hadith =>  ContentVisuals(
            background: AppColors.cardHadithBg,
            accent: AppColors.jadeLight,
            icon: Icons.format_quote_rounded,
          ),
        ContentType.sahabi =>  ContentVisuals(
            background: AppColors.slate,
            accent: AppColors.gold,
            icon: Icons.person_outline_rounded,
          ),
        ContentType.name =>  ContentVisuals(
            background: AppColors.cardNameBg,
            accent: AppColors.goldSoft,
            icon: Icons.auto_awesome_rounded,
          ),
        ContentType.prophet =>  ContentVisuals(
            background: AppColors.cardProphetBg,
            accent: AppColors.success,
            icon: Icons.auto_stories_rounded,
          ),
        ContentType.seerah =>  ContentVisuals(
            background: AppColors.cardSeerahBg,
            accent: AppColors.violet,
            icon: Icons.history_edu_rounded,
          ),
      };
}
