import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';
import '../../../routes/app_routes.dart';
import '../../session/models/session_plan.dart';

/// Camino: unidades del nivel, una abierta a la vez.
class PathController extends GetxController {
  final api = Get.find<Api>();
  final data = Rxn<Map<String, dynamic>>();
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      data.value = Map<String, dynamic>.from(await api.get('/path') as Map);
      error.value = '';
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> continueUnit(Map u) async {
    final steps = u['steps'] as Map;
    SessionPlan? plan;
    if (steps['words'] != true) {
      try {
        final r = await api.get('/path/units/${u['id']}/words');
        final cards = (r['cards'] as List).cast<Map>();
        if (cards.isNotEmpty) plan = SessionPlan([for (final c in cards) NewStep(c)], title: u['title'] as String, daily: false);
      } catch (e) {
        Get.snackbar('Camino', e.toString(), snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }
    if (plan == null && steps['sound'] != true) {
      final k = soundKey(u['sound'] as String? ?? '');
      if (k != null) plan = SessionPlan([for (final w in soundWords[k]!) SoundStep(k, w)], title: u['title'] as String, daily: false);
    }
    if (plan == null) {
      Get.snackbar('Camino', 'El shadowing y la prueba de la unidad se hacen por ahora en la web (w2w.huergalabs.dev).', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Get.toNamed(Routes.session, arguments: plan);
    load();
  }
}
