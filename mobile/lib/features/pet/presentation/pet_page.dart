import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../data/pet.dart';
import 'pet_brain.dart';
import 'pet_figure.dart';
import 'pet_providers.dart';
import 'pet_texts.dart';

/// La pantalla de Brainy: la mascota en grande, su etapa y qué enciende cada zona de su cerebro.
class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: W.callBg,
      appBar: AppBar(title: const Text('Brainy'), backgroundColor: W.callBg),
      body: AsyncView<PetState?>(
        value: ref.watch(petProvider),
        onRetry: () => ref.invalidate(petProvider),
        data: (pet) => pet == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('Brainy está descansando. Vuelve en un rato.'), textAlign: TextAlign.center)))
            : RefreshIndicator(onRefresh: () => ref.refresh(petProvider.future), child: PetView(pet: pet)),
      ),
    );
  }
}

class PetView extends StatelessWidget {
  const PetView({super.key, required this.pet});
  final PetState pet;

  @override
  Widget build(BuildContext context) {
    final brain = PetBrain.instance;
    final last = pet.nextAt == null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Center(child: PetFigure(pet: pet, size: 250)),
        Text(petStageName(pet), textAlign: TextAlign.center, style: W.display(28)),
        const SizedBox(height: 4),
        Text(tr('Etapa {0} de {1}', [pet.stage + 1, pet.stages]), textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: pet.stageProgress, color: W.accent, backgroundColor: W.line, minHeight: 10, borderRadius: BorderRadius.circular(9)),
        const SizedBox(height: 6),
        Text(
          last ? tr('Brainy ya llegó a su última etapa. Sigue encendiendo su cerebro.') : trn(pet.pointsToNext, 'Falta {0} punto para crecer', 'Faltan {0} puntos para crecer'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: W.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Su cerebro'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(tr('{0} de {1} neuronas encendidas', [brain.litCount(pet), brain.neurons.length]), style: const TextStyle(color: W.muted, fontSize: 13)),
            for (final r in const [PetRegion.words, PetRegion.memory, PetRegion.path, PetRegion.habit]) _SkillRow(region: r, skill: pet.skill(r)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
          tr('Brainy aprende lo que tú aprendes: cada palabra, cada unidad y cada día que estudias enciende sus neuronas.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: W.muted, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(tr('Brainy siempre te espera: lo que ya sabe no se le olvida.'), textAlign: TextAlign.center, style: const TextStyle(color: W.muted, height: 1.4)),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.region, required this.skill});
  final PetRegion region;
  final PetSkill skill;

  @override
  Widget build(BuildContext context) {
    final color = petColors[region]!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(petSkillName(region))),
          Text('${skill.count} / ${skill.target}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: skill.level, color: color, backgroundColor: W.line, minHeight: 6, borderRadius: BorderRadius.circular(9)),
      ]),
    );
  }
}
