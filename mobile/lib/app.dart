import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class WordToWordApp extends ConsumerWidget {
  const WordToWordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Word to Word',
      debugShowCheckedModeBanner: false,
      theme: W.theme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
