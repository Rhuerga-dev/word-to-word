import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/reminder_service.dart';

/// Progreso: números, liga de la semana y logros.
class ProgressController extends GetxController {
  final api = Get.find<Api>();
  final progress = Rxn<Map>();
  final league = Rxn<Map>();
  final achievements = Rxn<Map>();
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([api.get('/progress'), api.get('/league'), api.get('/achievements')]);
      league.value = r[1] as Map;
      achievements.value = r[2] as Map;
      progress.value = r[0] as Map;
      error.value = '';
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> setVisible(bool v) async {
    try {
      league.value = await api.put('/league/visibility', {'visible': v}) as Map;
    } catch (_) {}
  }

  // ---------- Recordatorio diario ----------
  final reminderMsg = ''.obs;

  Future<void> setReminder(bool on) => _saveReminder(on, (Get.find<AuthService>().reminder['time'] as String?) ?? '19:00');

  Future<void> pickReminderTime(BuildContext context) async {
    final cur = ((Get.find<AuthService>().reminder['time'] as String?) ?? '19:00').split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])), helpText: 'Hora del recordatorio');
    if (t == null) return;
    await _saveReminder(true, '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _saveReminder(bool on, String time) async {
    final rem = Get.find<ReminderService>(), auth = Get.find<AuthService>();
    reminderMsg.value = '';
    if (on && !await rem.requestPermission()) {
      reminderMsg.value = 'Activa las notificaciones de W2W en los ajustes del teléfono.';
      return;
    }
    try {
      await auth.saveReminder(enabled: on, time: time, timezone: await rem.timezoneName());
      final xp = (progress.value?['speaking'] as Map?)?['today'];
      await rem.sync(enabled: on, time: time, studiedToday: xp is num && xp > 0);
      reminderMsg.value = on ? 'Te avisaremos a las $time si no has estudiado.' : '';
    } catch (e) {
      reminderMsg.value = e.toString();
    }
  }
}
