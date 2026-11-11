import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/reminder_service.dart';
import '../../../routes/app_routes.dart';
import '../../session/models/session_plan.dart';

/// Hoy: la meta de puntos y la sesión del día.
class TodayController extends GetxController {
  final api = Get.find<Api>();
  final data = Rxn<Map<String, dynamic>>();
  final path = Rxn<Map<String, dynamic>>();
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([api.get('/session/today'), api.get('/path').catchError((_) => null)]);
      data.value = Map<String, dynamic>.from(r[0] as Map);
      path.value = r[1] == null ? null : Map<String, dynamic>.from(r[1] as Map);
      error.value = '';
      _syncReminder();
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> start() async {
    await Get.toNamed(Routes.session, arguments: SessionPlan.fromToday(data.value!));
    load();
  }

  /// Reprograma el recordatorio: si hoy ya ganaste puntos, el aviso de hoy no sale.
  void _syncReminder() {
    final r = Get.find<AuthService>().reminder, xp = data.value?['xp'] as Map?;
    Get.find<ReminderService>().sync(enabled: r['enabled'] == true, time: r['time'] as String?, studiedToday: ((xp?['xp'] as num?) ?? 0) > 0);
  }
}
