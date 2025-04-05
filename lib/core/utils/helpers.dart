import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  // Format numbers with commas
  static String formatNumber(double number) {
    return NumberFormat.decimalPattern().format(number);
  }

  // Format dates
  static String formatDate(DateTime date, {String format = 'dd MMM yyyy'}) {
    return DateFormat(format).format(date);
  }

  // Responsive width calculation
  static double responsiveWidth(BuildContext context) {
    return MediaQuery.of(context).size.width > 600 ? 500 : double.infinity;
  }

  // Show loading overlay
  static void showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// Add this helper class
class Breakpoints {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;
}