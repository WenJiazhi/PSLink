import 'package:flutter/material.dart';
import 'constants.dart';

/// 应用主题配置
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Color(AppColors.primaryColor),
        secondary: Color(AppColors.secondaryColor),
        tertiary: Color(AppColors.accentColor),
        surface: Color(AppColors.surfaceColor),
        error: Color(AppColors.errorColor),
      ),
      scaffoldBackgroundColor: Color(AppColors.backgroundColor),
      cardTheme: CardThemeData(
        color: Color(AppColors.cardColor),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(AppColors.backgroundColor),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: Color(AppColors.textPrimary),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Color(AppColors.textSecondary),
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: Color(AppColors.textPrimary),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(AppColors.primaryColor),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(AppColors.primaryColor),
          side: BorderSide(color: Color(AppColors.primaryColor)),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(AppColors.surfaceColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(AppColors.primaryColor), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Color(AppColors.primaryColor),
        inactiveTrackColor: Color(AppColors.surfaceColor),
        thumbColor: Color(AppColors.accentColor),
        overlayColor: Color(AppColors.primaryColor).withOpacity(0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Color(AppColors.accentColor);
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Color(AppColors.primaryColor);
          }
          return Color(AppColors.surfaceColor);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(AppColors.surfaceColor),
        selectedItemColor: Color(AppColors.accentColor),
        unselectedItemColor: Color(AppColors.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(AppColors.cardColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color(AppColors.cardColor),
        contentTextStyle: TextStyle(color: Color(AppColors.textPrimary)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
