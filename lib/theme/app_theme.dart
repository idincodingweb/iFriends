import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryPink = Color(0xFFFF2D75);
  static const Color primaryCoral = Color(0xFFFF5A4E);
  static const Color primaryOrange = Color(0xFFFF8A3D);
  static const Color primaryYellow = Color(0xFFFFB347);

  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color softBg = Color(0xFFFFF5F3);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF8A8A8A);
  static const Color divider = Color(0xFFF1EDEC);

  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentGreen = Color(0xFF10B981);

  static const LinearGradient vibrant = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPink, primaryCoral, primaryOrange],
  );

  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryCoral, primaryPink],
  );

  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryOrange, primaryYellow],
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgWhite,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryCoral,
        secondary: AppColors.primaryPink,
        surface: AppColors.bgWhite,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    );
  }
}
