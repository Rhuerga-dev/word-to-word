import 'strings_en.dart';

/// Idioma de la interfaz. Desde el escalón 3 de la escalera de español va en inglés
/// (lo decide el servidor en `profile.spanish.ui`; app.dart lo actualiza).
class Lang {
  Lang._();
  static bool english = false;
}

/// Texto de la interfaz: el español tal cual, o su versión en inglés si la interfaz va en inglés.
/// Los huecos {0}, {1}… se rellenan con [args] en los dos idiomas.
String tr(String es, [List<Object?> args = const []]) {
  var s = Lang.english ? (stringsEn[es] ?? es) : es;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Plural sencillo: [one] si n == 1, si no [many] (los dos pasan por tr con n como {0}).
String trn(num n, String one, String many) => tr(n == 1 ? one : many, [n]);
