import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/practice_repository.dart';

final practiceProvider = FutureProvider<PracticeData>((ref) => ref.watch(practiceRepositoryProvider).fetch());
