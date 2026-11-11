/// Lectura segura del JSON del API: si un campo falta o viene con otro tipo, se usa un valor por defecto.
int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
String asString(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
String? asStringOrNull(Object? v) => v == null ? null : '$v';
bool asBool(Object? v) => v == true || v == 1 || v == '1';
Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> asMaps(Object? v) => v is List ? [for (final e in v) asMap(e)] : const [];
List<T> listOf<T>(Object? v, T Function(Map<String, dynamic>) f) => [for (final m in asMaps(v)) f(m)];
