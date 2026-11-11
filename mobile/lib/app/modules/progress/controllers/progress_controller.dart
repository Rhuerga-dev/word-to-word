import 'package:get/get.dart';

import '../../../data/providers/api_client.dart';

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
}
