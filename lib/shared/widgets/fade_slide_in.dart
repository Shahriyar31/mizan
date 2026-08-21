library;

import 'package:flutter/material.dart';

/// Fades and slides a child in with a short delay keyed off [index] — used
/// wherever a block of reading content should feel like it's being told
/// rather than dumped on screen at once (Discover layers, Quran tafseer
/// paragraphs). One small widget so every screen gets the same rhythm.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 60 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
