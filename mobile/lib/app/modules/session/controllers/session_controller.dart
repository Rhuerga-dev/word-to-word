import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';
import '../models/session_plan.dart';

/// Avance de una sesión: paso actual, puntos, aciertos y el resumen final.
class SessionController extends GetxController {
  SessionController(this.plan);

  final SessionPlan plan;
  final index = 0.obs;
  final xp = 0.obs;
  final ending = false.obs;
  final end = Rxn<Map<String, dynamic>>();
  int right = 0, graded = 0;
  final started = DateTime.now();

  SessionStep get step => plan.steps[index.value];
  double get progress => ending.value ? 1 : index.value / plan.steps.length;
  int get minutes => DateTime.now().difference(started).inMinutes;

  void gain(num? points) => xp.value += (points ?? 0).toInt();

  void graded1(bool ok, num? points) {
    graded++;
    if (ok) right++;
    gain(points);
  }

  void next() {
    if (index.value + 1 >= plan.steps.length) {
      finish();
    } else {
      index.value++;
    }
  }

  Future<void> finish() async {
    ending.value = true;
    Map<String, dynamic>? r;
    if (plan.daily) {
      try {
        r = Map<String, dynamic>.from(await Get.find<Api>().post('/session/complete') as Map);
      } catch (_) {}
    }
    end.value = r ?? {};
  }
}
