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

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, color: color ?? ink, height: 1.1);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent, surface: card),
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      textTheme: GoogleFonts.atkinsonHyperlegibleTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

/// "dentro de N días" como en la web.
String days(num n) => n == 1 ? 'mañana' : 'en $n días';

/// Quita los *asteriscos* del ejemplo; [cloze] cambia la palabra marcada por un hueco.
String plainExample(String? ex, {bool cloze = false}) =>
    (ex ?? '').replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => cloze ? '_____' : m[1]!);
