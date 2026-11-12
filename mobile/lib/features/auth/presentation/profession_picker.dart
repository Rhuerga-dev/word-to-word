import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../path/presentation/path_providers.dart';
import '../../today/presentation/today_providers.dart';
import '../data/auth_repository.dart';
import '../data/user_profile.dart';
import 'auth_controller.dart';

final _optionsProvider = FutureProvider.autoDispose((ref) => ref.watch(authRepositoryProvider).professions());

/// Abre el selector de profesión y objetivo. Al guardar, el camino y la sesión de hoy se recargan
/// (las conversaciones y algunas unidades cambian según la profesión).
Future<void> showProfessionPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _Picker(),
    );

class _Picker extends ConsumerStatefulWidget {
  const _Picker();

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String? _profession;
  String? _goal;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = ref.read(authControllerProvider).valueOrNull;
    _profession = p?.profession;
    _goal = p?.goal;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).saveProfile(profession: _profession, goal: _goal);
      ref.invalidate(pathProvider);
      ref.invalidate(todayProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(List<ProfileOption> options, String? value, void Function(String) onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text('${o.emoji.isEmpty ? '' : '${o.emoji} '}${tr(o.label)}'),
              selected: value == o.id,
              onSelected: (_) => setState(() => onPick(o.id)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(_optionsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: options.when(
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(height: 200, child: Center(child: Text('$e'))),
        data: (o) => SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('¿A qué te dedicas?'), style: W.display(24)),
            const SizedBox(height: 4),
            Text(tr('Las conversaciones y los temas se adaptan a tu trabajo.'), style: const TextStyle(color: W.muted)),
            const SizedBox(height: 14),
            _chips(o.$1, _profession, (id) => _profession = id),
            const SizedBox(height: 22),
            Text(tr('¿Para qué quieres el inglés?'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            _chips(o.$2, _goal, (id) => _goal = id),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy || _profession == null ? null : _save,
              child: Text(_busy ? tr('Guardando…') : tr('Guardar')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta para Hoy (si aún no eligió) y para Progreso (para cambiarla).
class ProfessionCard extends ConsumerWidget {
  const ProfessionCard({super.key, this.onlyIfMissing = false});
  final bool onlyIfMissing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(authControllerProvider).valueOrNull;
    if (p == null || (onlyIfMissing && p.profession != null)) return const SizedBox.shrink();
    final options = p.profession == null ? null : ref.watch(_optionsProvider).valueOrNull;
    final current = options?.$1.where((o) => o.id == p.profession).firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F0FF),
          child: Text(current?.emoji ?? '💼'),
        ),
        title: Text(p.profession == null ? tr('¿A qué te dedicas?') : tr('Tu trabajo'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(p.profession == null
            ? tr('Elige tu profesión y la app practicará situaciones de tu trabajo.')
            : (current != null ? tr(current.label) : tr('Cambiar'))),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showProfessionPicker(context),
      ),
    );
  }
}
