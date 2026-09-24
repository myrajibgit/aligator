import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF3730A3); // deep indigo
  static const Color secondary = Color(0xFF7C3AED); // violet
  static const Color accent = Color(0xFF06B6D4); // cyan accent

  static const Color surfaceLight = Color(0xFFFDFBFF);
  static const Color backgroundLight = Color(0xFFF5F3F7);

  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color backgroundDark = Color(0xFF141218);
}

TextTheme _buildTextTheme(TextTheme base) {
  return GoogleFonts.interTextTheme(base);
}

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.accent,
    surface: AppColors.surfaceLight,
    brightness: Brightness.light,
  ),

  textTheme: _buildTextTheme(ThemeData.light().textTheme),

  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1C1B1F),
    ),
  ),

  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Colors.black.withOpacity(0.06),
      ),
    ),
  ),

  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),

  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: AppColors.primary.withOpacity(0.12),

    iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
      (states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(
            color: AppColors.primary,
          );
        }

        return const IconThemeData(
          color: Color(0xFF6B7280),
        );
      },
    ),

    labelTextStyle:
        MaterialStateProperty.resolveWith<TextStyle>(
      (states) {
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(MaterialState.selected)
              ? AppColors.primary
              : const Color(0xFF6B7280),
        );
      },
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.accent,
    surface: AppColors.surfaceDark,
    brightness: Brightness.dark,
  ),

  textTheme: _buildTextTheme(ThemeData.dark().textTheme),

  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    backgroundColor: AppColors.surfaceDark,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),

  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Colors.white.withOpacity(0.07),
      ),
    ),
  ),

  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),

  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surfaceDark,

    indicatorColor: AppColors.primary.withOpacity(0.18),

    iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
      (states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(
            color: Color(0xFF818CF8),
          );
        }

        return const IconThemeData(
          color: Color(0xFF9CA3AF),
        );
      },
    ),

    labelTextStyle:
        MaterialStateProperty.resolveWith<TextStyle>(
      (states) {
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(MaterialState.selected)
              ? const Color(0xFF818CF8)
              : const Color(0xFF9CA3AF),
        );
      },
    ),
  ),
);
