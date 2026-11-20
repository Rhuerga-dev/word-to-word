import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../core/l10n/tr.dart';
import 'brainy_alerts.dart';

/// Recordatorio diario de estudio con notificaciones locales: el teléfono las programa a tu hora
/// (la misma que en la web) y se salta el día si ya estudiaste. Funciona sin internet.
///
/// Se programan avisos sueltos para los próximos [days] días y se reprograman cada vez que abres la app
/// o terminas una sesión; así, si hoy ya estudiaste, el aviso de hoy desaparece.
class ReminderService {
  static const days = 10;
  static AndroidNotificationDetails get _channel => AndroidNotificationDetails(
    'study_reminder',
    tr('Recordatorio de estudio'),
    channelDescription: tr('El aviso diario para hacer tu sesión de inglés.'),
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_mic',
  );
  /// Los avisos (título, texto). Con mascota, habla ella con su nombre y sin culpar: nunca «te vas a perder…».
  /// Sin mascota (servidor viejo o aún no cargó), los de siempre.
  static List<(String, String)> messages([String? petName]) {
    final pet = (petName ?? '').trim();
    if (pet.isEmpty) {
      return [
        (tr('Tu sesión de hoy te espera'), tr('Son unos 10 minutos: tus fichas, un sonido y un minuto hablando.')),
        (tr('¿Un minuto de inglés?'), tr('Abre la app y habla un minuto sin parar. Todo suma a tu racha.')),
        (tr('No pierdas la racha'), tr('Todavía no has practicado hoy. Una sesión corta basta.')),
        (tr('Hora de hablar inglés'), tr('Repasa tus fichas y di bien tus errores de ayer.')),
      ];
    }
    return [
      (tr('{0} tiene hambre de palabras', [pet]), tr('¿Le das 10 minutos? Tus fichas, un sonido y un minuto hablando.')),
      (tr('{0} quiere oírte hablar', [pet]), tr('Abre la app y habla un minuto sin parar. Todo suma a tu racha.')),
      (tr('{0} te está esperando', [pet]), tr('Todavía no has practicado hoy. Una sesión corta basta.')),
      (tr('{0} quiere repasar contigo', [pet]), tr('Repasa tus fichas y di bien tus errores de ayer.')),
    ];
  }

  String? _petName;
  ({bool enabled, String? time, bool studiedToday})? _last;

  /// El nombre de la mascota del alumno. Si cambia y ya había avisos programados, se reprograman con su voz.
  void setPetName(String? name) {
    final clean = (name ?? '').trim();
    if (clean == (_petName ?? '')) return;
    _petName = clean.isEmpty ? null : clean;
    final last = _last;
    if (last != null) sync(enabled: last.enabled, time: last.time, studiedToday: last.studiedToday);
  }

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
    _last = (enabled: enabled, time: time, studiedToday: studiedToday);
    try {
      await _init();
      // Solo los suyos: los avisos de Brainy (syncBrainy) van aparte.
      for (var i = 0; i < days; i++) {
        await _plugin.cancel(_firstId + i);
      }
      if (!enabled) return;
      final texts = messages(_petName);
      for (final (i, at) in nextTimes(DateTime.now(), time ?? '19:00', studiedToday).indexed) {
        final (title, body) = texts[at.day % texts.length];
        await _plugin.zonedSchedule(
          _firstId + i,
          title,
          body,
          tz.TZDateTime.from(at, tz.UTC),
          NotificationDetails(android: _channel, iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Sin recordatorio no se rompe la app.
    }
  }

  static const _firstId = 100, _brainyFirstId = 200;
  static AndroidNotificationDetails get _brainyChannel => AndroidNotificationDetails(
    'brainy_alerts',
    tr('Avisos de Brainy'),
    channelDescription: tr('Tu mascota te avisa cuando tiene hambre o quiere jugar.'),
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_mic',
  );

  /// Programa los avisos de la mascota (y quita los anteriores). Lista vacía = quitarlos todos.
  Future<void> syncBrainy(List<BrainyAlert> alerts) async {
    try {
      await _init();
      for (var i = 0; i < BrainyAlerts.max; i++) {
        await _plugin.cancel(_brainyFirstId + i);
      }
      for (final (i, a) in alerts.take(BrainyAlerts.max).indexed) {
        await _plugin.zonedSchedule(
          _brainyFirstId + i,
          a.title,
          a.body,
          tz.TZDateTime.from(a.at, tz.UTC),
          NotificationDetails(android: _brainyChannel, iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Sin avisos no se rompe la app.
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
