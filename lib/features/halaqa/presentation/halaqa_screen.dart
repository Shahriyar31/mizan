/// Halaqa screen — placeholder
/// TODO: Implement Halaqa screen
library;

import 'package:flutter/material.dart';

class HalaqaScreen extends StatelessWidget {
  const HalaqaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Center(
        child: Text(
          'Halaqa',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
