import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../today/presentation/today_providers.dart';
import '../data/pet.dart';
import 'pet_care_panel.dart';
import 'pet_texts.dart';

/// «Modo Brainy»: la pantalla principal es la mascota, con sus barras y sus botones.
/// No quita nada: la sesión de siempre y el resto de la app siguen a un toque.
class PetHome extends ConsumerWidget {
  const PetHome({super.key, required this.pet, this.onAction});
  final PetState pet;
  final Future<void> Function(PetAction action)? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayProvider); // la mascota se vuelve a pedir cuando cambia «Hoy»
        await ref.read(todayProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text('${pet.name} · ${petStageName(pet)}', textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
          Center(child: PetWithBubble(pet: pet, size: 240)),
          const SizedBox(height: 6),
          PetCarePanel(care: pet.care!, onAction: onAction),
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('pet-home-session'),
            style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk, shape: const StadiumBorder(), minimumSize: const Size.fromHeight(54)),
            onPressed: () => context.push(Routes.classicToday),
            child: Text(tr('Mi sesión de hoy')),
          ),
          const SizedBox(height: 4),
          TextButton(key: const ValueKey('pet-home-brain'), onPressed: () => context.push(Routes.pet), child: Text(tr('Ver su cerebro y su historia'))),
        ],
      ),
    );
  }
}
