import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pet.dart';
import 'pet_figure.dart';
import 'pet_providers.dart';
import 'pet_texts.dart';

/// La tarjeta de Brainy en Hoy. Si la mascota no está disponible (servidor viejo, sin datos), no ocupa sitio.
class PetCard extends ConsumerWidget {
  const PetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider).valueOrNull;
    if (pet == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PetCardView(pet: pet, onTap: () => context.push(Routes.pet)),
    );
  }
}

class PetCardView extends StatelessWidget {
  const PetCardView({super.key, required this.pet, this.onTap});
  final PetState pet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final words = pet.skill(PetRegion.words).count;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(children: [
            PetFigure(pet: pet, size: 72, fit: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${pet.name} · ${petStageName(pet)}', style: const TextStyle(color: W.muted, fontSize: 13)),
                Text(
                  words == 0 ? tr('Enséñale tu primera palabra') : trn(words, 'Ya sabe {0} palabra gracias a ti', 'Ya sabe {0} palabras gracias a ti'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: pet.stageProgress, color: W.accent, backgroundColor: W.line, minHeight: 6, borderRadius: BorderRadius.circular(9)),
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: W.muted),
          ]),
        ),
      ),
    );
  }
}
