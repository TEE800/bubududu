import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Unsere Lieblingsfarbe: Dunkelgrün.
const darkGreen = Color(0xFF1B5E20);

ThemeData appTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: darkGreen,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFF6FAF4) : null,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? darkGreen : null,
      foregroundColor: light ? Colors.white : null,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      shape: rounded,
      elevation: 0,
      color: light ? Colors.white : scheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: light ? darkGreen : null,
      foregroundColor: light ? Colors.white : null,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // Weiche Übergänge zwischen Seiten.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
