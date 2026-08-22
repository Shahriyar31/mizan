/// Reusable Arabic text widget
/// Always use this instead of raw Text() for Arabic content
/// Handles: RTL, Amiri font, correct line height
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ArabicText extends StatelessWidget {
   ArabicText(
    this.text, {
    super.key,
    this.fontSize = 24,
    Color? color,
    this.textAlign = TextAlign.right,
  })  : _color = color;

  final String text;
  final double fontSize;
  final Color? _color;

  Color get color => _color ?? AppColors.textPrimary;
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
