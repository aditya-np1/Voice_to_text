import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Colors.white;
  static const Color surface = Color(0xFFF8F9FF);
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color secondaryPurple = Color(0xFF483D8B);
  static const Color accentLavender = Color(0xFFEBEBFF);
  static const Color textBlack = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF6E6E73);
  static const Color white = Colors.white;
}

class AppStyles {
  static final TextStyle brandName = GoogleFonts.orbitron(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.textBlack,
    letterSpacing: 2,
  );

  static final TextStyle heading = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  static final TextStyle body = GoogleFonts.poppins(
    fontSize: 16,
    color: AppColors.textGrey,
    height: 1.5,
  );

  static final TextStyle quoteStyle = GoogleFonts.philosopher(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textBlack,
    fontStyle: FontStyle.italic,
  );

  static final BoxDecoration modernCard = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
