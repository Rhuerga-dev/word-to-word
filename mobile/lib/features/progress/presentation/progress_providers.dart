import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_models.dart';
import '../data/progress_repository.dart';

final progressProvider = FutureProvider<ProgressBundle>((ref) => ref.watch(progressRepositoryProvider).fetch());
