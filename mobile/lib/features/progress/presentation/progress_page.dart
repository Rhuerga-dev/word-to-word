import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';
import 'progress_providers.dart';

/// Progreso: números claros, recordatorio, liga de la semana y logros.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<ProgressBundle>(
      value: ref.watch(progressProvider),
      onRetry: () => ref.invalidate(progressProvider),
      data: (b) {
        final p = b.progress, l = b.league, a = b.achievements;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(progressProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Row(children: [
              Expanded(child: Text('Progreso', style: W.display(26))),
              TextButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: const Text('Salir')),
            ]),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _stat('${p.wordsLearned}', 'palabras aprendidas'),
                _stat('${p.speakingMinutes}', 'minutos hablando'),
                _stat('${p.streak}', 'días seguidos'),
                _stat('${p.mistakesMastered}', 'errores superados'),
              ],
            ),
            for (final t in p.todo) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t)),
            _h('Recordatorio diario'),
            _ReminderCard(studiedToday: p.speakingToday > 0),
            _h('Liga de la semana'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l.myRank == null ? 'Aún sin puntos esta semana' : 'Vas en el puesto ${l.myRank} de ${l.players} · quedan ${l.daysLeft} días',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final r in l.top)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('${r.rank}', style: const TextStyle(color: W.muted))),
                        Expanded(child: Text('${r.name}${r.me ? ' (tú)' : ''}', style: TextStyle(fontWeight: r.me ? FontWeight.w700 : FontWeight.w400))),
                        Text('${r.xp} XP'),
                      ]),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aparecer en la liga'),
                    value: l.visible,
                    onChanged: (v) async {
                      await ref.read(progressRepositoryProvider).setLeagueVisible(v);
                      ref.invalidate(progressProvider);
                    },
                  ),
                ]),
              ),
            ),
            _h('Logros · ${a.unlocked} de ${a.total}'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in a.list)
                Tooltip(
                  message: x.desc,
                  child: Chip(
                    avatar: Icon(x.unlocked ? Icons.emoji_events : Icons.lock_outline, size: 18, color: x.unlocked ? const Color(0xFFC0640C) : W.muted),
                    label: Text(x.title),
                    backgroundColor: x.unlocked ? const Color(0xFFFFF6C7) : W.card,
                  ),
                ),
            ]),
            if (p.sounds.isNotEmpty) ...[
              _h('Sonidos'),
              for (final s in p.sounds)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('/${s.phoneme}/'),
                  subtitle: Text(s.label),
                  trailing: Text('${s.errors} fallos', style: const TextStyle(color: W.muted)),
                ),
            ],
            if (p.mistakesByCategory.isNotEmpty) ...[
              _h('Tus errores por tipo'),
              for (final (label, count) in p.mistakesByCategory) Text('$label: $count'),
            ],
          ]),
        );
      },
    );
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(t, style: W.display(19)));

  Widget _stat(String n, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: W.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(n, style: W.display(26, color: W.accent)),
          Text(label, style: const TextStyle(color: W.muted, fontSize: 13)),
        ]),
      );
}

/// Activar el recordatorio y elegir la hora (se guarda en el servidor y se programa en el teléfono).
class _ReminderCard extends ConsumerStatefulWidget {
  const _ReminderCard({required this.studiedToday});
  final bool studiedToday;

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  String _msg = '';

  Future<void> _save(bool on, String time) async {
    final rem = ref.read(reminderServiceProvider);
    setState(() => _msg = '');
    if (on && !await rem.requestPermission()) {
      setState(() => _msg = 'Activa las notificaciones de W2W en los ajustes del teléfono.');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).saveReminder(enabled: on, time: time, timezone: await rem.timezoneName());
      await rem.sync(enabled: on, time: time, studiedToday: widget.studiedToday);
      _msg = on ? 'Te avisaremos a las $time si no has estudiado.' : '';
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(Reminder r) async {
    final cur = r.time.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(cur[0]) ?? 19, minute: int.tryParse(cur.length > 1 ? cur[1] : '0') ?? 0),
      helpText: 'Hora del recordatorio',
    );
    if (t != null) await _save(true, '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(authControllerProvider).valueOrNull?.reminder ?? const Reminder(enabled: false, time: '19:00');
    return Card(
      child: Column(children: [
        SwitchListTile(
          title: const Text('Avisarme si no he estudiado'),
          subtitle: Text(r.enabled ? 'A las ${r.time}' : 'Desactivado'),
          value: r.enabled,
          onChanged: (v) => _save(v, r.time),
        ),
        if (r.enabled)
          ListTile(leading: const Icon(Icons.schedule), title: const Text('Cambiar la hora'), trailing: const Icon(Icons.chevron_right), onTap: () => _pickTime(r)),
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(_msg, style: const TextStyle(color: W.muted))),
      ]),
    );
  }
}
