import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/path_models.dart';
import '../data/path_repository.dart';

final pathProvider = FutureProvider<PathData>((ref) => ref.watch(pathRepositoryProvider).fetch());
