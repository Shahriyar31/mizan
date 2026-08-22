/// Tactile — plain tap wrappers, no shadow/depth effect.
///
/// These used to add a neumorphic shadow treatment; that's been removed
/// per feedback. Kept as thin pass-through widgets (instead of reverting
/// every call site) so nothing else has to change.
library;

import 'package:flutter/material.dart';

class Tactile extends StatelessWidget {
  const Tactile({
    super.key,
    required this.child,
    this.baseColor,
    this.onTap,
    this.borderRadius = 20,
    this.strength = 1.0,
    this.enabled = true,
    this.raised = true,
  });

  final Widget child;
  final Color? baseColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final double strength;
  final bool enabled;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: child,
    );
  }
}

class TactileChip extends StatelessWidget {
  const TactileChip({
    super.key,
    required this.child,
    required this.baseColor,
    this.onTap,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.strength = 0.8,
    this.raised = true,
  });

  final Widget child;
  final Color baseColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double strength;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

class TactilePill extends StatelessWidget {
  const TactilePill({
    super.key,
    required this.child,
    required this.baseColor,
    this.onTap,
    this.borderRadius = 99,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.strength = 1.0,
    this.raised = true,
  });

  final Widget child;
  final Color baseColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double strength;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}
