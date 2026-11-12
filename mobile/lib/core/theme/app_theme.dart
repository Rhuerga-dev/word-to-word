import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores y letras de Word to Word (los mismos que la web).
class W {
  static const accent = Color(0xFF1F4FD1);
  static const yellow = Color(0xFFFFE45C);
  static const yellowInk = Color(0xFF2A2300);
  static const good = Color(0xFF1E8A55);
  static const warn = Color(0xFFB7791F);
  static const bad = Color(0xFFC43C3C);
  static const bg = Color(0xFFEEF2F7);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16212E);
  static const muted = Color(0xFF4D5A6B);
  static const line = Color(0xFFD3DBE6);

  // Dirección "Llamada": la voz en el centro.
  static const navy = Color(0xFF0F2A86);
  static const blueDeep = Color(0xFF163A9E);
  static const mist = Color(0xFFC8D6FF);
  static const ringLight = Color(0xFFDFE7FF);
  static const ringMid = Color(0xFFB9CBFF);
  static const callBg = Color(0xFFF1F4FC);

  // Fichas estilo "Libreta".
  static const paper = Color(0xFFF9FBFE);
  static const rule = Color(0xFFDDE6F3);
  static const cardTop = Color(0xFFE88F8F);
  static const inkBlue = Color(0xFF2747B8);
  static const streak = Color(0xFFB4560A);

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, color: color ?? ink, height: 1.1);

  /// Letra a mano para las notas del coach en las fichas.
  static TextStyle hand(double size, {Color color = inkBlue}) => GoogleFonts.caveat(fontSize: size, fontWeight: FontWeight.w600, color: color, height: 1.2);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent, surface: card),
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      // Respaldo para lo que Atkinson no trae (símbolos fonéticos /ɪ/, /ʌ/…, emojis). En el teléfono el
      // sistema ya tiene su propio respaldo; estos nombres sirven sobre todo para las capturas de prueba.
      textTheme: GoogleFonts.atkinsonHyperlegibleTextTheme(base.textTheme)
          .apply(bodyColor: ink, displayColor: ink, fontFamilyFallback: const ['Roboto', 'NotoSans', 'NotoEmoji']),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          // Misma letra que el resto de la app (antes heredaba la del sistema).
          textStyle: GoogleFonts.atkinsonHyperlegible(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
      ),
    );
  }
}
