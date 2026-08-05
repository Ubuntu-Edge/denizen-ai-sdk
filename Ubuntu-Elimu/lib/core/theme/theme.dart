import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class UETheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: UEColors.indigo,
      scaffoldBackgroundColor: UEColors.bgPrimary,
      fontFamily: 'Inter',
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: UEColors.indigo,
        secondary: UEColors.violet,
        surface: UEColors.bgCard,
        error: UEColors.pdfColor,
      ),
    );
  }
}
