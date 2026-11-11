import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/reminder_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/today.dart';
import '../data/today_repository.dart';

/// Lo que toca hoy. Al cargarlo se reprograma el recordatorio: si ya estudiaste, el de hoy no sale.
final todayProvider = FutureProvider<TodayData>((ref) async {
  final today = await ref.watch(todayRepositoryProvider).fetch();
  final reminder = ref.read(authControllerProvider).valueOrNull?.reminder;
  if (reminder != null) {
    ref.read(reminderServiceProvider).sync(enabled: reminder.enabled, time: reminder.time, studiedToday: today.studied);
  }
  return today;
});
