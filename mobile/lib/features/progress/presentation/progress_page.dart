import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../spanish/data/spanish_repository.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';
import 'progress_providers.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/services/airpods_service.dart';

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
              Expanded(child: Text(tr('Progreso'), style: W.display(26))),
              TextButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(tr('Salir'))),
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
                _stat('${p.wordsLearned}', tr('palabras aprendidas')),
                _stat('${p.speakingMinutes}', tr('minutos hablando')),
                _stat('${p.streak}', tr('días seguidos')),
                _stat('${p.mistakesMastered}', tr('errores superados')),
              ],
            ),
            for (final t in p.todo) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t)),
            _h('Tu español'),
            const _SpanishCard(),
            if (AirPodsService.supported) ...[
              _h(tr('AirPods')),
              const _AirPodsCard(),
              const SizedBox(height: 8),
              const _EarsCard(),
            ],
            _h(tr('Recordatorio diario')),
            _ReminderCard(studiedToday: p.speakingToday > 0),
            _h(tr('Liga de la semana')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l.myRank == null ? tr('Aún sin puntos esta semana') : tr('Vas en el puesto {0} de {1} · quedan {2} días', [l.myRank, l.players, l.daysLeft]),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final r in l.top)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('${r.rank}', style: const TextStyle(color: W.muted))),
                        Expanded(child: Text('${r.name}${r.me ? tr(' (tú)') : ''}', style: TextStyle(fontWeight: r.me ? FontWeight.w700 : FontWeight.w400))),
                        Text('${r.xp} XP'),
                      ]),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Aparecer en la liga')),
                    value: l.visible,
                    onChanged: (v) async {
                      await ref.read(progressRepositoryProvider).setLeagueVisible(v);
                      ref.invalidate(progressProvider);
                    },
                  ),
                ]),
              ),
            ),
            _h(tr('Logros · {0} de {1}', [a.unlocked, a.total])),
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
              _h(tr('Tus errores por tipo')),
              for (final (label, count) in p.mistakesByCategory) Text('$label: $count'),
            ],
            const SizedBox(height: 28),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: W.bad),
                onPressed: () => showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog()),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(tr('Borrar mi cuenta')),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(tr(t), style: W.display(19)));

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
      setState(() => _msg = tr('Activa las notificaciones de W2W en los ajustes del teléfono.'));
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).saveReminder(enabled: on, time: time, timezone: await rem.timezoneName());
      await rem.sync(enabled: on, time: time, studiedToday: widget.studiedToday);
      _msg = on ? tr('Te avisaremos a las {0} si no has estudiado.', [time]) : '';
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
      helpText: tr('Hora del recordatorio'),
    );
    if (t != null) await _save(true, '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(authControllerProvider).valueOrNull?.reminder ?? const Reminder(enabled: false, time: '19:00');
    return Card(
      child: Column(children: [
        SwitchListTile(
          title: Text(tr('Avisarme si no he estudiado')),
          subtitle: Text(r.enabled ? tr('A las {0}', [r.time]) : tr('Desactivado')),
          value: r.enabled,
          onChanged: (v) => _save(v, r.time),
        ),
        if (r.enabled)
          ListTile(leading: const Icon(Icons.schedule), title: Text(tr('Cambiar la hora')), trailing: const Icon(Icons.chevron_right), onTap: () => _pickTime(r)),
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(_msg, style: const TextStyle(color: W.muted))),
      ]),
    );
  }
}

/// La escalera de español: en qué escalón estás, cuánto español pediste y la opción de elegir el escalón.
class _SpanishCard extends ConsumerStatefulWidget {
  const _SpanishCard();

  @override
  ConsumerState<_SpanishCard> createState() => _SpanishCardState();
}

class _SpanishCardState extends ConsumerState<_SpanishCard> {
  static const _names = ['Con español', 'Primero inglés', 'Interfaz en inglés', 'Solo inglés'];
  static const _info = [
    'Traducción a la vista y explicaciones en español.',
    'Definición en inglés; el español solo si lo pides.',
    'La app en inglés y español con límite diario.',
    'Sin español: todo se explica en inglés.',
  ];
  bool _busy = false;
  String _msg = '';

  Future<void> _set(int? step) async {
    setState(() => _busy = true);
    try {
      // Al cambiar de idioma la app se vuelve a dibujar y esta tarjeta se cierra: todo se toma antes.
      final repo = ref.read(spanishRepositoryProvider), auth = ref.read(authControllerProvider.notifier);
      final sp = await repo.setStep(step);
      if (mounted) ref.invalidate(progressProvider);
      auth.setSpanish(sp);
      _msg = '';
    } catch (e) {
      _msg = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final sp = ref.watch(spanishProvider);
    final auto = sp.autoStep ?? sp.step;
    Widget stat(String n, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: W.display(22, color: W.accent)),
            Text(tr(label), style: const TextStyle(color: W.muted, fontSize: 13)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            for (var i = 1; i <= 4; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 8,
                  decoration: BoxDecoration(color: i <= sp.step ? W.accent : W.line, borderRadius: BorderRadius.circular(9)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text('${tr('Escalón')} ${sp.step} · ${tr(_names[sp.step - 1])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(tr(_info[sp.step - 1]), style: const TextStyle(color: W.muted)),
          const SizedBox(height: 4),
          Text(tr('Pensar en inglés es dejar de pasar por el español: cada escalón te quita un poco.'), style: const TextStyle(color: W.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            stat(sp.limit != null ? '${sp.today} / ${sp.limit}' : '${sp.today}', 'veces hoy'),
            stat('${sp.week}', 'esta semana'),
            stat('${sp.streak}', sp.streak == 1 ? 'día sin español' : 'días sin español'),
          ]),
          if (sp.reaction != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                sp.translating
                    ? tr('Tardas {0} s en empezar a hablar: señal de que traduces mentalmente. Prueba «Respuesta rápida» en Hablar.', [sp.reaction])
                    : tr('Empiezas a hablar en {0} s de media. Menos de {1} s es buena señal.', [sp.reaction, 2.5]),
                style: TextStyle(color: sp.translating ? W.warn : W.muted),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey(sp.auto ? 0 : sp.step),
            isExpanded: true,
            initialValue: sp.auto ? 0 : sp.step,
            decoration: InputDecoration(labelText: tr('Escalón')),
            items: [
              DropdownMenuItem(
                value: 0,
                child: Text(auto > sp.base
                    ? tr('Automático (ahora: escalón {0}, subiste por usar poco español)', [auto])
                    : tr('Automático (ahora: escalón {0}, según tu nivel)', [auto]), overflow: TextOverflow.ellipsis),
              ),
              for (var i = 1; i <= 4; i++) DropdownMenuItem(value: i, child: Text('$i · ${tr(_names[i - 1])}')),
            ],
            onChanged: _busy ? null : (v) => _set(v == 0 ? null : v),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(color: W.bad))),
        ]),
      ),
    );
  }
}

/// AirPods en Android: apagar la detección de conversación durante la práctica (opcional, experimental).
class _AirPodsCard extends ConsumerStatefulWidget {
  const _AirPodsCard();

  @override
  ConsumerState<_AirPodsCard> createState() => _AirPodsCardState();
}

class _AirPodsCardState extends ConsumerState<_AirPodsCard> {
  String _msg = '';
  bool _askSettings = false;

  Future<void> _toggle(bool on) async {
    final svc = ref.read(airPodsProvider.notifier);
    final r = await svc.setEnabled(on);
    var msg = '';
    var settings = false;
    if (on) {
      switch (r) {
        case AirPodsEnable.denied:
          msg = tr('Falta el permiso «Dispositivos cercanos». Si no te salió la pregunta, dalo en los ajustes de la app: Permisos → Dispositivos cercanos → Permitir.');
          settings = true;
        case AirPodsEnable.reinstall:
          msg = tr('Esta función es nueva y necesita reinstalar la app: detén la app y vuelve a ejecutar flutter run (el hot reload no la carga).');
        case AirPodsEnable.unsupported:
          msg = tr('Solo está disponible en Android.');
        case AirPodsEnable.ok:
          if (!await svc.connected()) msg = tr('Activado. Funcionará cuando practiques con los AirPods conectados.');
      }
    }
    if (mounted) {
      setState(() {
        _msg = msg;
        _askSettings = settings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(airPodsProvider);
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          title: Text(tr('Mantener la cancelación de ruido al hablar')),
          subtitle: Text(tr('Apaga la detección de conversación de los AirPods mientras practicas y la vuelve a dejar como estaba al terminar.')),
          value: on,
          onChanged: _toggle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _msg.isNotEmpty ? _msg : tr('Experimental: funciona en Android 16 QPR3 o más nuevo (Pixel, OnePlus, Oppo, realme). En otros teléfonos no hace nada.'),
            style: const TextStyle(color: W.muted, fontSize: 13),
          ),
        ),
        if (_askSettings)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ref.read(airPodsProvider.notifier).openSettings(),
                icon: const Icon(Icons.settings),
                label: Text(tr('Abrir ajustes de la app')),
              ),
            ),
          ),
      ]),
    );
  }
}

/// "Pausar el manos libres al quitarte los AirPods", con el estado en directo para comprobarlo.
class _EarsCard extends ConsumerStatefulWidget {
  const _EarsCard();

  @override
  ConsumerState<_EarsCard> createState() => _EarsCardState();
}

class _EarsCardState extends ConsumerState<_EarsCard> {
  String _msg = '';
  bool _askSettings = false;

  Future<void> _toggle(bool on) async {
    final r = await ref.read(airPodsEarsSettingProvider.notifier).setEnabled(on);
    var msg = '';
    var settings = false;
    if (on) {
      switch (r) {
        case AirPodsEnable.denied:
          msg = tr('Falta el permiso «Dispositivos cercanos». Si no te salió la pregunta, dalo en los ajustes de la app: Permisos → Dispositivos cercanos → Permitir.');
          settings = true;
        case AirPodsEnable.reinstall:
          msg = tr('Esta función es nueva y necesita reinstalar la app: detén la app y vuelve a ejecutar flutter run (el hot reload no la carga).');
        case AirPodsEnable.unsupported:
          msg = tr('Solo está disponible en Android.');
        case AirPodsEnable.ok:
          break;
      }
    }
    if (mounted) {
      setState(() {
        _msg = msg;
        _askSettings = settings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(airPodsEarsSettingProvider);
    final live = on ? ref.watch(airPodsEarsProvider) : null;
    String yes(bool b) => b ? tr('puesto') : tr('fuera');
    final status = live?.when(
            data: (e) => '${tr('Ahora')}: ${tr('izquierdo')} ${yes(e.left)} · ${tr('derecho')} ${yes(e.right)}  (0x${e.status.toRadixString(16).padLeft(2, '0')}, ${e.rssi} dBm)',
            loading: () => tr('Buscando tus AirPods… (abre el estuche o póntelos)'),
            error: (e, _) => tr('No se pudo leer el estado de los AirPods (¿Bluetooth apagado o falta el permiso?).'),
          );
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          title: Text(tr('Pausar el manos libres al quitarte los AirPods')),
          subtitle: Text(tr('Si te quitas los dos, el manos libres se pausa; al volver a ponértelos, sigue solo.')),
          value: on,
          onChanged: _toggle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _msg.isNotEmpty ? _msg : (status ?? tr('Experimental: solo AirPods y Beats, en Android. Lee lo que los AirPods emiten por Bluetooth.')),
            style: const TextStyle(color: W.muted, fontSize: 13),
          ),
        ),
        if (_askSettings)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ref.read(airPodsProvider.notifier).openSettings(),
                icon: const Icon(Icons.settings),
                label: Text(tr('Abrir ajustes de la app')),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Borrar la cuenta y todo lo que tiene (se pide la contraseña otra vez).
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _pass = TextEditingController();
  bool _busy = false;
  String _msg = '';

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final auth = ref.read(authControllerProvider.notifier), nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      await auth.deleteAccount(_pass.text);
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Borrar mi cuenta')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Se borran tu cuenta y todo lo que tiene: tu progreso, tus palabras, tus errores y tus recordatorios. No se puede deshacer.')),
        const SizedBox(height: 12),
        TextField(controller: _pass, obscureText: true, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: tr('Contraseña'))),
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(color: W.bad))),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(tr('Cancelar'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: W.bad),
          onPressed: _busy ? null : _go,
          child: Text(_busy ? tr('Borrando…') : tr('Borrar para siempre')),
        ),
      ],
    );
  }
}
