/// Responsive content width — caps and centers content on tablets so it
/// never simply stretches edge-to-edge, while leaving phones (<600dp)
/// completely unchanged (the cap is effectively infinite below 600dp).
library;

import 'package:flutter/material.dart';

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Explicit override. When null, the width is derived from the current
  /// screen width via [contentMaxWidth].
  final double? maxWidth;

  /// <600dp (phone): unconstrained — identical to today's behaviour.
  /// 600–900dp (medium tablet): capped at 700dp, centered.
  /// >900dp (large tablet): capped at 840dp, centered.
  static double contentMaxWidth(double screenWidth) {
    if (screenWidth < 600) return double.infinity;
    if (screenWidth < 900) return 700;
    return 840;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cap = maxWidth ?? contentMaxWidth(screenWidth);
    if (!cap.isFinite || screenWidth <= cap) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}
