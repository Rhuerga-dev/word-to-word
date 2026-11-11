import 'strings_en.dart';

/// Idioma de la interfaz. Desde el escalón 3 de la escalera de español va en inglés
/// (lo decide el servidor en `profile.spanish.ui`; app.dart lo actualiza).
class Lang {
  Lang._();
  static bool english = false;

  /// Traducciones del servidor (lang/en.json, como en CuPay). Si no hay, se usan las que trae la app.
  static Map<String, String> remote = const {};

  /// Se llama con cada texto que no tiene traducción (el servidor lo traduce con la IA).
  static void Function(String key)? onMissing;
}

/// Texto de la interfaz: el español tal cual, o su versión en inglés si la interfaz va en inglés.
/// Los huecos {0}, {1}… se rellenan con [args] en los dos idiomas.
String tr(String es, [List<Object?> args = const []]) {
  var s = es;
  if (Lang.english) {
    final en = Lang.remote[es] ?? stringsEn[es];
    if (en != null) {
      s = en;
    } else {
      Lang.onMissing?.call(es);
    }
  }
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Plural sencillo: [one] si n == 1, si no [many] (los dos pasan por tr con n como {0}).
String trn(num n, String one, String many) => tr(n == 1 ? one : many, [n]);
