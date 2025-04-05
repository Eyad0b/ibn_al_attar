import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const primary = Color(0xFF6A1B9A);
  static const primaryDark = Color(0xFF38006B);
  static const primaryLight = Color(0xFF9C4DCC);

  // Secondary Colors
  static const secondary = Color(0xFF26A69A);
  static const secondaryDark = Color(0xFF00766C);
  static const secondaryLight = Color(0xFF64FFDA);

  // Status Colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const error = Color(0xFFF44336);
  static const info = Color(0xFF2196F3);

  // Background & Surface
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFBDBDBD);

  // Text Colors
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textDisabled = Color(0xFF9E9E9E);

  // Text Colors
  static const textPrimaryLight = Color(0xFFF5F1F1);
  static const textSecondaryLight = Color(0xFF757575);
  static const textDisabledLight = Color(0xFF9E9E9E);

  // Custom Colors
  static const deepPurpleAccent = Color(0xFF7C4DFF);
  static const gradientStart = Color(0xFF6A1B9A);
  static const gradientEnd = Color(0xFF9C4DCC);

  // Helper method for gradients
  static LinearGradient primaryGradient({Alignment begin = Alignment.centerLeft}) {
    return LinearGradient(
      begin: begin,
      end: Alignment.centerRight,
      colors: [gradientStart, gradientEnd],
    );
  }
}