import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return _theme(Brightness.light);
  }

  static ThemeData dark() {
    return _theme(Brightness.dark);
  }

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: brightness,
      primary: AppColors.primaryBlue,
      secondary: AppColors.cyan,
      error: AppColors.errorRed,
      surface: isDark ? const Color(0xFF111827) : AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF020617)
          : AppColors.background,
      fontFamily: 'SF Pro Display',
      textTheme: _textTheme(isDark),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF020617)
            : AppColors.background,
        foregroundColor: isDark ? Colors.white : AppColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF111827) : AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : AppColors.border,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        indicatorColor: AppColors.primaryBlue.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : null,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : AppColors.border,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? const Color(0xFF94A3B8) : AppColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBlue;
          }
          return isDark ? const Color(0xFF334155) : AppColors.border;
        }),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.navy,
          backgroundColor: isDark
              ? const Color(0xFF0F172A)
              : AppColors.primaryBlue.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          foregroundColor: AppColors.primaryBlue,
          side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: .35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : AppColors.border,
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final color = isDark ? Colors.white : AppColors.navy;
    final muted = isDark ? const Color(0xFFCBD5E1) : AppColors.muted;

    return TextTheme(
      displaySmall: TextStyle(
        color: color,
        fontSize: 34,
        height: 1.05,
        fontWeight: FontWeight.w900,
      ),
      headlineMedium: TextStyle(
        color: color,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: TextStyle(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: TextStyle(color: color, fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: muted, fontSize: 13, height: 1.45),
      labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
