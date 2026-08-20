/// Reusable Arabic text widget
/// Always use this instead of raw Text() for Arabic content
/// Handles: RTL, Amiri font, correct line height
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.color = AppColors.ink,
    this.textAlign = TextAlign.right,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: fontSize,
        color: color,
        height: 1.9,
      ),
    );
  }
}
