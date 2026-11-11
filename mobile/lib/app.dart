import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/tr.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';

class WordToWordApp extends ConsumerWidget {
  const WordToWordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escalera de español: desde el escalón 3 la interfaz va en inglés. Al cambiar de idioma
    // se vuelve a dibujar todo (la clave cambia), así ningún texto se queda en el idioma anterior.
    final english = ref.watch(spanishProvider.select((s) => s.uiEnglish));
    Lang.english = english;
    return MaterialApp.router(
      title: 'Word to Word',
      debugShowCheckedModeBanner: false,
      theme: W.theme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => KeyedSubtree(key: ValueKey(english), child: child ?? const SizedBox.shrink()),
    );
  }
}
