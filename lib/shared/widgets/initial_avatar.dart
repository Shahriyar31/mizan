/// InitialAvatar — a circular avatar showing a person's initials.
///
/// The app has no photos (and, being local-first, no accounts yet), so people
/// are represented by their initials on a colour picked deterministically from
/// their name. The same name always gets the same colour, which quietly helps
/// you recognise who's who across the feed and the member ring.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.dimmed = false,
  });

  final String name;
  final double size;

  /// When true (e.g. a member who's gone quiet) the avatar is desaturated so
  /// the eye skips past it.
  final bool dimmed;

  // A small palette of identity colours, all from the app's tokens.
  static List<Color> get _palette => [
    AppColors.gold,
    AppColors.jade,
    AppColors.jadeLight,
    AppColors.amber,
    AppColors.violet,
    AppColors.success,
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get _color => _palette[name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final base = _color;
    final fg = dimmed ? AppColors.muted : base;
    final bg = (dimmed ? AppColors.muted : base).withValues(alpha: 0.16);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        _initials,
        style: AppTypography.labelLarge(color: fg).copyWith(
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
