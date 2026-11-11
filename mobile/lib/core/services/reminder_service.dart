import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio diario de estudio con notificaciones locales: el teléfono las programa a tu hora
/// (la misma que en la web) y se salta el día si ya estudiaste. Funciona sin internet.
///
/// Se programan avisos sueltos para los próximos [days] días y se reprograman cada vez que abres la app
/// o terminas una sesión; así, si hoy ya estudiaste, el aviso de hoy desaparece.
class ReminderService {
  static const days = 10;
  static const _channel = AndroidNotificationDetails(
    'study_reminder',
    'Recordatorio de estudio',
    channelDescription: 'El aviso diario para hacer tu sesión de inglés.',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_mic',
  );
  static const _messages = [
    ('Tu sesión de hoy te espera', 'Son unos 10 minutos: tus fichas, un sonido y un minuto hablando.'),
    ('¿Un minuto de inglés?', 'Abre la app y habla un minuto sin parar. Todo suma a tu racha.'),
    ('No pierdas la racha', 'Todavía no has practicado hoy. Una sesión corta basta.'),
    ('Hora de hablar inglés', 'Repasa tus fichas y di bien tus errores de ayer.'),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones(); // las horas se programan como instantes absolutos (UTC)
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_mic'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    _ready = true;
  }

  /// Pide permiso para mostrar notificaciones (Android 13+ e iPhone). Devuelve si lo dieron.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return true;
  }

  /// Nombre IANA de la zona horaria del teléfono (lo pide el servidor), p. ej. "America/New_York".
  Future<String> timezoneName() async {
    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      return info is String ? info : (info.identifier as String);
    } catch (_) {
      return 'UTC';
    }
  }

  /// Reprograma los avisos según el ajuste del perfil y si hoy ya estudiaste.
  Future<void> sync({required bool enabled, required String? time, required bool studiedToday}) async {
    try {
      await _init();
      await _plugin.cancelAll();
      if (!enabled) return;
      for (final (i, at) in nextTimes(DateTime.now(), time ?? '19:00', studiedToday).indexed) {
        final (title, body) = _messages[at.day % _messages.length];
        await _plugin.zonedSchedule(
          100 + i,
          title,
          body,
          tz.TZDateTime.from(at, tz.UTC),
          const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Sin recordatorio no se rompe la app.
    }
  }

  Future<void> cancelAll() async {
    try {
      await _init();
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Las próximas horas de aviso (hora local). Hoy solo si aún no estudiaste y la hora no ha pasado.
  static List<DateTime> nextTimes(DateTime now, String time, bool studiedToday) {
    final parts = time.split(':');
    final h = int.tryParse(parts.first) ?? 19, m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final out = <DateTime>[];
    for (var d = 0; out.length < days; d++) {
      final at = DateTime(now.year, now.month, now.day + d, h, m);
      if (d == 0 && (studiedToday || !at.isAfter(now))) continue;
      out.add(at);
    }
    return out;
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService());
