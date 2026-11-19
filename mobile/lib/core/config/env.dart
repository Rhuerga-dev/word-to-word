/// Dirección del API. En desarrollo se cambia sin tocar código:
/// flutter run --dart-define=API_URL=http://192.168.1.20:8000/api
const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://w2w.huergalabs.dev/api');

/// Versión de la app (la misma de pubspec.yaml; un test avisa si se desajustan).
/// Se envía con las sugerencias para saber en qué versión pasó algo.
const appVersion = '1.0.14+16';
