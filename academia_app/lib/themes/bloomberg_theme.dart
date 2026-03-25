import 'package:flutter/material.dart';

/// Thème Bloomberg Terminal pour les jeux économiques premium
class BloombergTheme {
  // Couleurs principales
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFFFFD700);  // Or
  static const Color green = Color(0xFF00FF00);  // Vert financier
  static const Color red = Color(0xFFFF0000);    // Rouge financier
  static const Color text = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);
  
  // Couleurs de marché
  static const Color marketUp = Color(0xFF00FF88);
  static const Color marketDown = Color(0xFFFF4444);
  static const Color marketNeutral = Color(0xFF888888);
  
  // Couleurs de graphiques
  static const Color chartLine = Color(0xFF00FF00);
  static const Color chartFill = Color.fromRGBO(0, 255, 0, 0.2);
  static const Color gridLines = Color(0xFF333333);
  
  // Rayons
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  
  // Espacements
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  
  // Thème complet
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: green,
      surface: surface,
      background: background,
      error: red,
      onPrimary: background,
      onSecondary: background,
      onSurface: text,
      onBackground: text,
      onError: background,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      iconTheme: IconThemeData(
        color: text,
        size: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: BorderSide(
          color: gridLines,
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: TextStyle(
          fontFamily: 'RobotoMono',
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: TextStyle(
          fontFamily: 'RobotoMono',
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: text,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      displayMedium: TextStyle(
        color: text,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      displaySmall: TextStyle(
        color: text,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      headlineLarge: TextStyle(
        color: text,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      headlineSmall: TextStyle(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'RobotoMono',
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'RobotoMono',
      ),
      titleSmall: TextStyle(
        color: text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: 'RobotoMono',
      ),
      bodyLarge: TextStyle(
        color: text,
        fontSize: 16,
        fontFamily: 'RobotoMono',
      ),
      bodyMedium: TextStyle(
        color: text,
        fontSize: 14,
        fontFamily: 'RobotoMono',
      ),
      bodySmall: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontFamily: 'RobotoMono',
      ),
      labelLarge: TextStyle(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'RobotoMono',
      ),
      labelMedium: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'RobotoMono',
      ),
      labelSmall: TextStyle(
        color: textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        fontFamily: 'RobotoMono',
      ),
    ),
    iconTheme: IconThemeData(
      color: text,
      size: 24,
    ),
    dividerTheme: DividerThemeData(
      color: gridLines,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: gridLines),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: gridLines),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: accent),
      ),
      labelStyle: TextStyle(
        color: textSecondary,
        fontFamily: 'RobotoMono',
      ),
      hintStyle: TextStyle(
        color: textTertiary,
        fontFamily: 'RobotoMono',
      ),
    ),
  );
  
  // Styles de texte spécifiques
  static TextStyle get headerStyle => TextStyle(
    color: accent,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'RobotoMono',
  );
  
  static TextStyle get subheaderStyle => TextStyle(
    color: text,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: 'RobotoMono',
  );
  
  static TextStyle get bodyStyle => TextStyle(
    color: text,
    fontSize: 14,
    fontFamily: 'RobotoMono',
  );
  
  static TextStyle get captionStyle => TextStyle(
    color: textSecondary,
    fontSize: 12,
    fontFamily: 'RobotoMono',
  );
  
  // Styles de marché
  static TextStyle get marketUpStyle => TextStyle(
    color: marketUp,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: 'RobotoMono',
  );
  
  static TextStyle get marketDownStyle => TextStyle(
    color: marketDown,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: 'RobotoMono',
  );
  
  // Décorations de boîtes
  static BoxDecoration get primaryBox => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: gridLines),
  );
  
  static BoxDecoration get accentBox => BoxDecoration(
    color: accent.withOpacity(0.1),
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: accent.withOpacity(0.3)),
  );
  
  static BoxDecoration get successBox => BoxDecoration(
    color: green.withOpacity(0.1),
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: green.withOpacity(0.3)),
  );
  
  static BoxDecoration get errorBox => BoxDecoration(
    color: red.withOpacity(0.1),
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: red.withOpacity(0.3)),
  );
}
