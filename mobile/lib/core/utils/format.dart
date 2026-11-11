/// "dentro de N días" como en la web.
String days(num n) => n == 1 ? 'mañana' : 'en $n días';

/// Quita los *asteriscos* del ejemplo; [cloze] cambia la palabra marcada por un hueco.
String plainExample(String? ex, {bool cloze = false}) =>
    (ex ?? '').replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => cloze ? '_____' : m[1]!);
