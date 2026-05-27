import 'package:flutter/material.dart';
import '../models/server.dart';

class AppTheme {
  AppTheme._();

  // ── Core Colors ────────────────────────────────────────────
  static const Color background = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF1A1D27);
  static const Color surfaceVariant = Color(0xFF22263A);
  static const Color border = Color(0xFF2D3148);
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color textPrimary = Color(0xFFF0F2FF);
  static const Color textSecondary = Color(0xFF8A90B0);
  static const Color textMuted = Color(0xFF4F556E);

  // ── Environment Colors ─────────────────────────────────────
  static const Color devColor = Color(0xFF4DC0FA);
  static const Color qaColor = Color(0xFFFFC94D);
  static const Color prodColor = Color(0xFFFF6B6B);

  // ── Status Colors ──────────────────────────────────────────
  static const Color statusOnline = Color(0xFF4ADE80);
  static const Color statusDegraded = Color(0xFFFBBF24);
  static const Color statusOffline = Color(0xFFF87171);

  // ── Environment helpers ────────────────────────────────────
  static Color envColor(ServerEnvironment env) {
    switch (env) {
      case ServerEnvironment.dev:
        return devColor;
      case ServerEnvironment.qa:
        return qaColor;
      case ServerEnvironment.prod:
        return prodColor;
    }
  }

  static String envLabel(ServerEnvironment env) {
    switch (env) {
      case ServerEnvironment.dev:
        return 'DEV';
      case ServerEnvironment.qa:
        return 'QA';
      case ServerEnvironment.prod:
        return 'PROD';
    }
  }

  static Color statusColor(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return statusOnline;
      case ServerStatus.degraded:
        return statusDegraded;
      case ServerStatus.offline:
        return statusOffline;
    }
  }

  static String statusLabel(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return 'Online';
      case ServerStatus.degraded:
        return 'Degraded';
      case ServerStatus.offline:
        return 'Offline';
    }
  }

  // ── Theme ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'monospace',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
        dividerColor: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}
