/// Minbar screen — placeholder
/// TODO: Implement Minbar screen
library;

import 'package:flutter/material.dart';

class MinbarScreen extends StatelessWidget {
  const MinbarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Center(
        child: Text(
          'Minbar',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
