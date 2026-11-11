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

/// El alumno con sesión iniciada (GET /me).
class UserProfile {
  const UserProfile({required this.name, required this.cefrLevel, required this.xpGoal, required this.reminder});
  final String name;
  final String cefrLevel;
  final int xpGoal;
  final Reminder reminder;

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
      );
}
