/// Rutas de la app.
abstract class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const today = '/today';
  static const path = '/path';
  static const practice = '/practice';
  static const progress = '/progress';
  static const settings = '/settings';

  /// Tus palabras: el plan del día de fichas con repaso espaciado.
  static const words = '/words';

  /// La sesión recibe su SessionPlan en `extra`.
  static const session = '/session';
}
