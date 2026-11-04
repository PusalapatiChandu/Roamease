import 'package:flutter/material.dart';

class AppColors {
  // Brand Blues & Navy
  static const Color navyDarkest = Color(0xFF090D16);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color navyMedium = Color(0xFF1E293B);
  static const Color navySurface = Color(0xFF1E3A8A);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color royalBlue = Color(0xFF1D4ED8);
  static const Color lightBlue = Color(0xFF38BDF8);
  static const Color cyan5G = Color(0xFF06B6D4);
  static const Color accentIndigo = Color(0xFF6366F1);

  // Light Theme Neutrals
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Dark Theme Neutrals
  static const Color darkBg = Color(0xFF090E17);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Signal & Status Indicators
  static const Color signalExcellent = Color(0xFF10B981); // 5G / -80 dBm and higher
  static const Color signalGood = Color(0xFF3B82F6);      // -81 to -95 dBm
  static const Color signalFair = Color(0xFFF59E0B);      // -96 to -109 dBm
  static const Color signalPoor = Color(0xFFEF4444);      // <= -110 dBm
  static const Color roamingWarning = Color(0xFFF97316);  // Orange

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient card5GGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient signalGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
