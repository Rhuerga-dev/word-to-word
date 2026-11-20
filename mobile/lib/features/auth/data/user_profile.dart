import '../../../core/utils/json.dart';

/// El recordatorio diario (la misma hora que en la web).
class Reminder {
  const Reminder({required this.enabled, required this.time, this.timezone, this.auto = false, this.usualTime});
  final bool enabled;
  final String time;
  final String? timezone;

  /// Automático: avisa a la hora en que sueles practicar (la calcula el servidor).
  final bool auto;

  /// Tu hora habitual ("HH:MM") o null si aún no hay datos (entonces se usa [time]).
  final String? usualTime;

  /// Margen tras la hora habitual, igual que el servidor (ReminderService::GRACE_MINUTES).
  static const graceMinutes = 30;

  /// La hora a la que el teléfono programa el aviso: hora habitual + 30 min si es automático y se conoce; si no, [time].
  String get deviceTime {
    final u = usualTime;
    if (!auto || u == null) return time;
    final p = u.split(':');
    final h = int.tryParse(p.first), m = p.length > 1 ? int.tryParse(p[1]) : 0;
    if (h == null || m == null) return time;
    final at = (h * 60 + m + graceMinutes) % 1440;
    return '${(at ~/ 60).toString().padLeft(2, '0')}:${(at % 60).toString().padLeft(2, '0')}';
  }

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        enabled: asBool(j['enabled']),
        time: asStringOrNull(j['time']) ?? '19:00',
        timezone: asStringOrNull(j['timezone']),
        auto: asBool(j['auto']),
        usualTime: asStringOrNull(j['usual_time']),
      );
}

/// La escalera de español (GET /spanish o profile.spanish): cuánto español te da la app.
/// 1 = con español · 2 = primero inglés · 3 = interfaz en inglés (español con límite) · 4 = solo inglés.
class SpanishInfo {
  const SpanishInfo({
    this.step = 1,
    this.auto = true,
    this.autoStep,
    this.base = 1,
    this.coach = 'es',
    this.limit,
    this.today = 0,
    this.left,
    this.week = 0,
    this.streak = 0,
    this.reaction,
    this.translating = false,
    this.ui,
  });
  final int step, base, today, week, streak;
  final bool auto, translating;
  final int? autoStep, limit, left;
  final String coach;
  final double? reaction;

  /// Idioma de la pantalla que dice el servidor («en» o «es»). En el curso de español va en inglés, sea cual sea
  /// el escalón. null = servidor viejo: se decide por el escalón, como siempre.
  final String? ui;

  bool get uiEnglish => ui != null ? ui == 'en' : step >= 3;
  /// La traducción de las palabras se oculta (definición primero) desde el escalón 2.
  bool get hideTranslation => step >= 2;
  bool get noSpanish => step >= 4;
  /// Idioma de la voz del coach para sus comentarios.
  String get coachVoice => coach == 'es' ? 'es' : 'en';

  factory SpanishInfo.fromJson(Map<String, dynamic> j) => SpanishInfo(
        step: asInt(j['step'], 1),
        auto: j['auto'] != false,
        autoStep: j['auto_step'] == null ? null : asInt(j['auto_step']),
        base: asInt(j['base'], 1),
        coach: asString(j['coach'], 'es'),
        ui: j['ui'] == 'en' || j['ui'] == 'es' ? j['ui'] as String : null,
        limit: j['limit'] == null ? null : asInt(j['limit']),
        today: asInt(j['today']),
        left: j['left'] == null ? null : asInt(j['left']),
        week: asInt(j['week']),
        streak: asInt(j['streak']),
        reaction: j['reaction'] == null ? null : asDouble(j['reaction']),
        translating: asBool(j['translating']),
      );
}

/// El alumno con sesión iniciada (GET /me).
class UserProfile {
  const UserProfile({required this.name, required this.cefrLevel, required this.xpGoal, required this.reminder, this.spanish = const SpanishInfo(), this.profession, this.goal, this.brainyDefault});
  final String name;
  /// A qué se dedica ("tech", "health"…) y para qué quiere el inglés. null = no lo eligió (todo como siempre).
  final String? profession;
  final String? goal;
  final String cefrLevel;
  final int xpGoal;
  final Reminder reminder;
  final SpanishInfo spanish;

  /// Experimento A/B: true = Modo Brainy encendido por defecto para este alumno; false = apagado.
  /// null = no hay experimento (o el servidor es viejo): la app se comporta como siempre.
  final bool? brainyDefault;

  UserProfile withSpanish(SpanishInfo s) =>
      UserProfile(name: name, cefrLevel: cefrLevel, xpGoal: xpGoal, reminder: reminder, spanish: s, profession: profession, goal: goal, brainyDefault: brainyDefault);

  /// Nombre de pila para saludar ("" en la demo).
  String get firstName {
    final n = name.trim().split(RegExp(r'\s+')).first;
    return const ['Estudiante', 'Invitado'].contains(n) ? '' : n;
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: asString(j['name']),
        cefrLevel: asString(j['cefr_level'], 'A1'),
        xpGoal: asInt(j['xp_goal'], 100),
        reminder: Reminder.fromJson(asMap(j['reminder'])),
        spanish: SpanishInfo.fromJson(asMap(j['spanish'])),
        profession: asStringOrNull(j['profession']),
        goal: asStringOrNull(j['goal']),
        brainyDefault: j['brainy_default'] is bool ? j['brainy_default'] as bool : null,
      );
}

/// Una opción para elegir (profesión u objetivo), de GET /professions.
class ProfileOption {
  const ProfileOption(this.id, this.label, [this.emoji = '']);
  final String id;
  final String label;
  final String emoji;
}
