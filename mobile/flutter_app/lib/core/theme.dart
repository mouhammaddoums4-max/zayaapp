import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Barres du téléphone (Android) transparentes : l'application s'affiche en plein écran (main.dart), sous la barre
/// d'état et sous la barre de navigation, qui prennent donc la couleur de l'écran affiché : dégradé de l'accueil,
/// blanc de la barre d'onglets, fond des autres écrans. Pas de voile de contraste ajouté par Android.
/// Icônes sombres sur les écrans clairs ; [zSystemUiOnBrand] sur les écrans au dégradé de marque.
const zSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// Variante pour les écrans au dégradé de marque (accueil) : icônes claires.
const zSystemUiOnBrand = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

/// Tokens de couleur ZAYA — voir documentation/design/DESIGN_SYSTEM.md
class ZColors {
  static const primary = Color(0xFFF5075E);
  static const primaryDark = Color(0xFFC9004A);
  static const primarySoft = Color(0xFFFFE8F0);
  static const gradientStart = Color(0xFFFF2D55);
  static const gradientEnd = Color(0xFFEC0677);
  static const ink = Color(0xFF1B1020);
  static const muted = Color(0xFF6E6475);
  static const line = Color(0xFFEDEDF0);

  /// Fond de toutes les pages : blanc pur (demande du propriétaire), sans teinte rose.
  static const bg = Colors.white;
  static const surface = Colors.white;
  static const verified = Color(0xFF1D7FE0);
  static const premium = Color(0xFFC8962E);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEE4E2);
  static const success = Color(0xFF12805C);

  /// Point « en ligne ».
  static const online = Color(0xFF22C55E);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );
}

class ZSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

ThemeData buildZayaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    // Surfaces neutres : Material 3 teinte sinon feuilles, dialogues et menus avec la couleur de marque (rosé).
    // Le propriétaire veut un blanc franc partout, comme Facebook.
    colorScheme: ColorScheme.fromSeed(
      seedColor: ZColors.primary,
      primary: ZColors.primary,
      onPrimary: Colors.white,
      surface: ZColors.surface,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF7F7F8),
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: const Color(0xFFF0F0F2),
      error: ZColors.danger,
    ),
    scaffoldBackgroundColor: ZColors.bg,
  );
  // Police Inter appliquée à chaque style du thème (google_fonts ne fournit que des TextStyle,
  // compatibles avec le paquet material_ui).
  TextStyle? inter(TextStyle? style) => style == null ? null : GoogleFonts.inter(textStyle: style);
  final t = base.textTheme;
  final text = TextTheme(
    displayLarge: inter(t.displayLarge),
    displayMedium: inter(t.displayMedium),
    displaySmall: inter(t.displaySmall),
    headlineLarge: inter(t.headlineLarge),
    headlineMedium: inter(t.headlineMedium),
    headlineSmall: inter(t.headlineSmall),
    titleLarge: inter(t.titleLarge),
    titleMedium: inter(t.titleMedium),
    titleSmall: inter(t.titleSmall),
    bodyLarge: inter(t.bodyLarge),
    bodyMedium: inter(t.bodyMedium),
    bodySmall: inter(t.bodySmall),
    labelLarge: inter(t.labelLarge),
    labelMedium: inter(t.labelMedium),
    labelSmall: inter(t.labelSmall),
  ).apply(bodyColor: ZColors.ink, displayColor: ZColors.ink);
  TextStyle sora(double size, FontWeight w) =>
      GoogleFonts.sora(fontSize: size, fontWeight: w, color: ZColors.ink, height: 1.2);

  return base.copyWith(
    textTheme: text.copyWith(
      headlineLarge: sora(32, FontWeight.w700),
      headlineMedium: sora(24, FontWeight.w700),
      titleLarge: sora(20, FontWeight.w600),
      titleMedium: sora(17, FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 13, height: 1.4, color: ZColors.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ZColors.bg,
      foregroundColor: ZColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: sora(20, FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: ZColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZColors.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: ZColors.primarySoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? ZColors.primaryDark : ZColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? ZColors.primaryDark : ZColors.muted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ZColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: ZColors.line, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent),
  );
}
