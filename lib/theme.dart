import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Unsere Lieblingsfarbe: Dunkelgrün.
const darkGreen = Color(0xFF1B5E20);

/// Pastellfarben für den Cute-Look: Minze, Rosa und Vanille.
class Cute {
  static const mint = Color(0xFFE6F7DF);
  static const mintDeep = Color(0xFFC9E8C0);
  static const page = Color(0xFFF2FAEE);
  static const pink = Color(0xFFFFE4EC);
  static const pinkDeep = Color(0xFFF6CDD8);
  static const rose = Color(0xFFD9567A);
  static const vanilla = Color(0xFFFFF2C9);
  static const vanillaDeep = Color(0xFFF7E3A6);
  static const honey = Color(0xFFB07A0C);
  static const leaf = Color(0xFF2D5A34);
}

const fontFamily = 'Fredoka';

ThemeData appTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: darkGreen,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        tertiary: light ? Cute.rose : const Color(0xFFFFB1C6),
        tertiaryContainer: light ? Cute.pink : const Color(0xFF5C2A39),
        onTertiaryContainer: light ? const Color(0xFF8A2E4A) : Cute.pink,
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(26),
  );
  final base = ThemeData(brightness: brightness, fontFamily: fontFamily);
  final text = base.textTheme.apply(
    bodyColor: light ? Cute.leaf : null,
    displayColor: light ? darkGreen : null,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: fontFamily,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    scaffoldBackgroundColor: light ? Cute.page : null,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? Cute.page : null,
      foregroundColor: light ? darkGreen : null,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: light ? darkGreen : scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      shape: rounded,
      elevation: light ? 2 : 0,
      shadowColor: light ? const Color(0x661B5E20) : null,
      color: light ? Colors.white : scheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: light ? Cute.mint : null,
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      enabledBorder: light
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Cute.mintDeep, width: 2),
            )
          : null,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: light ? Cute.mintDeep : scheme.outline,
          width: 2,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: light ? darkGreen : null,
      foregroundColor: light ? Colors.white : null,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : null,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: light ? darkGreen : scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? (light ? Colors.white : scheme.onPrimaryContainer)
              : (light ? const Color(0xFF7FA885) : scheme.onSurfaceVariant),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? (light ? darkGreen : scheme.onSurface)
              : (light ? const Color(0xFF7FA885) : scheme.onSurfaceVariant),
        ),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
