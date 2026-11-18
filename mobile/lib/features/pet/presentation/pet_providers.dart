import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../today/presentation/today_providers.dart';
import '../data/pet.dart';
import '../data/pet_repository.dart';

/// La mascota del alumno (null = no disponible: la tarjeta no sale).
/// Se vuelve a pedir cuando cambia «Hoy» (al terminar una sesión o al tirar para refrescar): así crece a la vista.
final petProvider = FutureProvider<PetState?>((ref) {
  ref.listen(todayProvider, (_, __) => ref.invalidateSelf());
  return ref.watch(petRepositoryProvider).fetch();
});
