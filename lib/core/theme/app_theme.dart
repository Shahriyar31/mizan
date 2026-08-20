/// Taddabur app theme
/// Assembles colors and typography into Flutter ThemeData
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.parchment,
        primaryColor: AppColors.jade,
        colorScheme: const ColorScheme.light(
          primary: AppColors.jade,
          secondary: AppColors.gold,
          surface: AppColors.white,
          background: AppColors.parchment,
          error: AppColors.error,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.night,
          foregroundColor: AppColors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.muted,
          elevation: 0,
        ),
      );
}
