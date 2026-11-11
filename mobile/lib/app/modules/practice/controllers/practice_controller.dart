import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';
import '../../../routes/app_routes.dart';
import '../../session/models/session_plan.dart';

/// Practicar: errores pendientes y fichas del día.
class PracticeController extends GetxController {
  final api = Get.find<Api>();
  final mistakes = Rxn<List<Map>>();
  final cards = Rxn<List<Map>>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([api.get('/speaking/mistakes'), api.get('/today')]);
      mistakes.value = ((r[0] as Map)['mistakes'] as List).cast<Map>();
      cards.value = ((r[1] as Map)['cards'] as List).cast<Map>();
    } catch (_) {
      mistakes.value ??= const [];
    }
  }

  Future<void> run(List<SessionStep> steps, String title) async {
    if (steps.isEmpty) return;
    await Get.toNamed(Routes.session, arguments: SessionPlan(steps, title: title, daily: false));
    load();
  }
}
