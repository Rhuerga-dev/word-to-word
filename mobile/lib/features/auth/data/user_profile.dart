import '../../../core/utils/json.dart';

/// El recordatorio diario (la misma hora que en la web).
class Reminder {
  const Reminder({required this.enabled, required this.time, this.timezone});
  final bool enabled;
  final String time;
  final String? timezone;

  factory Reminder.fromJson(Map<String, dynamic> j) =>
      Reminder(enabled: asBool(j['enabled']), time: asStringOrNull(j['time']) ?? '19:00', timezone: asStringOrNull(j['timezone']));
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
  });
  final int step, base, today, week, streak;
  final bool auto, translating;
  final int? autoStep, limit, left;
  final String coach;
  final double? reaction;

  bool get uiEnglish => step >= 3;
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
  const UserProfile({required this.name, required this.cefrLevel, required this.xpGoal, required this.reminder, this.spanish = const SpanishInfo(), this.profession, this.goal});
  final String name;
  /// A qué se dedica ("tech", "health"…) y para qué quiere el inglés. null = no lo eligió (todo como siempre).
  final String? profession;
  final String? goal;
  final String cefrLevel;
  final int xpGoal;
  final Reminder reminder;
  final SpanishInfo spanish;

  UserProfile withSpanish(SpanishInfo s) =>
      UserProfile(name: name, cefrLevel: cefrLevel, xpGoal: xpGoal, reminder: reminder, spanish: s, profession: profession, goal: goal);

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
      );
}

/// Una opción para elegir (profesión u objetivo), de GET /professions.
class ProfileOption {
  const ProfileOption(this.id, this.label, [this.emoji = '']);
  final String id;
  final String label;
  final String emoji;
}
