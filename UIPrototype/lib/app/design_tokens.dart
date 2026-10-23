import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFE9774F);
  static const Color primaryDark = Color(0xFFB84A2F);
  static const Color accent = Color(0xFFFFB86B);
  static const Color emergency = Color(0xFFFF6B6B);
  static const Color emergencySoft = Color(0xFFFFE5E5);
  static const Color warning = Color(0xFFFFB86B);
  static const Color success = Color(0xFF5FA76A);
  static const Color background = Color(0xFFFFF8F1);
  static const Color backgroundSecondary = Color(0xFFFFFCF8);
  static const Color backgroundWarm = Color(0xFFFFE8D6);
  static const Color surface = Color(0xFFFFFCF8);
  static const Color surfaceGlass = Color(0xD9FFFCF7);
  static const Color warmSurface = Color(0xFFFFF0E3);
  static const Color peachSurface = Color(0xFFFFD8C2);
  static const Color greenSurface = Color(0xFFFFE9D8);
  static const Color blueSurface = Color(0xFFEAF4F1);
  static const Color purpleSurface = Color(0xFFF0EDFF);
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF3A3A3C);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF8E8E93);
  static const Color border = Color(0x1A7A4B32);
  static const Color chartGreen = Color(0xFF5FA76A);
  static const Color chartBlue = Color(0xFF4F9FA3);
  static const Color chartPurple = Color(0xFF9B78A8);
  static const Color chartOrange = Color(0xFFE99845);
}

class AppGradients {
  AppGradients._();

  static const List<Color> page = [
    Color(0xFFFFF3E8),
    Color(0xFFFFE7D8),
    Color(0xFFFFFAF4),
  ];

  static const List<Color> card = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF7EF),
  ];

  static const List<Color> primaryButton = [
    Color(0xFFE9774F),
    Color(0xFFB84A2F),
  ];

  static const List<Color> warmAdvice = [
    Color(0xFFFFF7EF),
    Color(0xFFFFE2C3),
  ];

  static const List<Color> emergency = [
    Color(0xFFFF8B8B),
    Color(0xFFFF6B6B),
  ];
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.16,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 32;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
