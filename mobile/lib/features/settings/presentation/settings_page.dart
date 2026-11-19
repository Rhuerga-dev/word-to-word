import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/services/airpods_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/reminder_service.dart';
import '../../../core/services/brainy_mode_setting.dart';
import '../../../core/services/word_drill_setting.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profession_picker.dart';
import '../../feedback/presentation/suggestion_dialog.dart';
import '../../pet/presentation/pet_birth.dart';
import '../../pet/presentation/pet_cloud.dart';
import '../../pet/presentation/pet_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../spanish/data/spanish_repository.dart';

/// Ajustes: tu trabajo, tu español, AirPods, recordatorio diario y la cuenta (salir, borrar).
/// Antes estaban al final de Progreso y costaba encontrarlos.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Para no avisar hoy si ya hablaste; si el progreso aún no cargó, se supone que no.
    final studiedToday = (ref.watch(progressProvider).valueOrNull?.progress.speakingToday ?? 0) > 0;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Row(children: [
        Expanded(child: Text(tr('Ajustes'), style: W.display(26))),
        TextButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(tr('Salir'))),
      ]),
      _h(tr('Recordatorio diario')),
      _ReminderCard(studiedToday: studiedToday),
      _h(tr('Tu trabajo')),
      const ProfessionCard(),
      _h(tr('Tu español')),
      const _SpanishCard(),
      _h(tr('Pronunciación')),
      const _WordDrillCard(),
      _h('Brainy'),
      const _BrainyModeCard(),
      const _PetNameCard(),
      const _PetColorCard(),
      if (Platform.isAndroid) ...[
        _h(tr('Audífonos')),
        const HeadsetMicCard(),
      ],
      if (AirPodsService.supported) ...[
        _h(tr('AirPods')),
        const _AirPodsCard(),
      ],
      if (Platform.isIOS) ...[
        _h(tr('AirPods')),
        const AirPodsMicCard(),
      ],
      _h(tr('Tu opinión')),
      Card(
        child: ListTile(
          key: const ValueKey('suggestion-tile'),
          // Emoji (es texto) en vez de un icono nuevo: así cabe en un parche de Shorebird.
          leading: const Text('💡', style: TextStyle(fontSize: 22)),
          title: Text(tr('Enviar sugerencia')),
          subtitle: Text(tr('Una idea, algo que no funciona o lo que quieras contarme.')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(context: context, builder: (_) => const SuggestionDialog(screen: 'settings')),
        ),
      ),
      const SizedBox(height: 28),
      Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: W.bad),
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog()),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(tr('Borrar mi cuenta')),
        ),
      ),
      const SizedBox(height: 12),
      // Acerca de: solo la versión y quién hace la app.
      Center(child: Text('W2W ${appVersion.split('+').first} · huergalabs.dev', style: const TextStyle(color: W.muted, fontSize: 13))),
    ]);
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(t, style: W.display(19)));
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

  /// [auto]: avisar a la hora habitual (null = dejar el que había).
  Future<void> _save(bool on, String time, {bool? auto}) async {
    final rem = ref.read(reminderServiceProvider), auth = ref.read(authControllerProvider.notifier);
    setState(() => _msg = '');
    if (on && !await rem.requestPermission()) {
      setState(() => _msg = tr('Activa las notificaciones de W2W en los ajustes del teléfono.'));
      return;
    }
    try {
      await auth.saveReminder(enabled: on, time: time, timezone: await rem.timezoneName(), auto: auto);
      // El servidor responde con el perfil: si es automático trae la hora habitual, y el teléfono avisa a esa hora + 30 min.
      final saved = ref.read(authControllerProvider).valueOrNull?.reminder ?? Reminder(enabled: on, time: time);
      await rem.sync(enabled: on, time: saved.deviceTime, studiedToday: widget.studiedToday);
      _msg = on && !saved.auto ? tr('Te avisaremos a las {0} si no has estudiado.', [time]) : '';
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
          subtitle: Text(!r.enabled ? tr('Desactivado') : (r.auto ? tr('Automático') : tr('A las {0}', [r.time]))),
          value: r.enabled,
          onChanged: (v) => _save(v, r.time),
        ),
        if (r.enabled)
          SwitchListTile(
            title: Text(tr('Automático: a la hora en que sueles practicar')),
            subtitle: r.auto
                ? Text(r.usualTime != null ? tr('Te avisaremos hacia las {0}', [r.usualTime]) : tr('Usaremos las {0} hasta conocer tu hora habitual', [r.time]))
                : null,
            value: r.auto,
            onChanged: (v) => _save(true, r.time, auto: v),
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

/// iPhone: grabar con el micrófono de los AirPods (para practicar con el iPhone en el bolsillo).
///
/// El interruptor guarda una PREFERENCIA (por defecto, sí). Sin audífonos conectados esa preferencia no se
/// está usando: el iPhone graba con su propio micrófono. Entonces el interruptor sale apagado y en gris,
/// y el texto dice qué pasa de verdad. La preferencia no se toca: vuelve a verse al conectar los audífonos.
class AirPodsMicCard extends ConsumerWidget {
  const AirPodsMicCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(airPodsMicProvider).valueOrNull ?? true;
    final phones = ref.watch(headphonesProvider);
    // Solo se da por «sin audífonos» cuando ya se sabe; mientras se averigua (o si falla), se enseña la preferencia.
    final none = phones.hasValue && phones.value == null;
    return Card(
      child: SwitchListTile(
        key: const ValueKey('airpods-mic-switch'),
        title: Text(tr('Micrófono de los AirPods')),
        subtitle: Text(none
            ? (on
                ? tr('No hay audífonos conectados: ahora te oye el micrófono del iPhone. Al conectar tus AirPods se usará su micrófono.')
                : tr('No hay audífonos conectados: te oye el micrófono del iPhone.'))
            : on
                ? tr('Te oye por los AirPods aunque el iPhone esté en el bolsillo. La voz de la app suena como una llamada.')
                : tr('Te oye por el micrófono del iPhone. La voz de la app suena en alta calidad.')),
        value: none ? false : on,
        onChanged: none ? null : (v) => ref.read(airPodsMicProvider.notifier).set(v),
      ),
    );
  }
}

/// Android: grabar con el micrófono de los audífonos Bluetooth (para practicar con el teléfono guardado).
/// Apagado por defecto: lo normal es grabar con el teléfono y oír la voz en alta calidad.
/// Sin audífonos conectados sale apagado y en gris (la preferencia guardada no se toca), igual que en el iPhone.
class HeadsetMicCard extends ConsumerWidget {
  const HeadsetMicCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(headsetMicProvider).valueOrNull ?? false;
    final phones = ref.watch(headphonesProvider);
    final none = phones.hasValue && phones.value == null;
    return Card(
      child: SwitchListTile(
        key: const ValueKey('headset-mic-switch'),
        title: Text(tr('Micrófono de los audífonos')),
        subtitle: Text(none
            ? (on
                ? tr('No hay audífonos conectados: ahora te oye el micrófono del teléfono. Al conectarlos se usará su micrófono.')
                : tr('No hay audífonos conectados: te oye el micrófono del teléfono.'))
            : on
                ? tr('Te oye por los audífonos aunque el teléfono esté guardado. Mientras grabas, la voz de la app suena como una llamada (menos calidad) y algunos audífonos quitan la cancelación de ruido.')
                : tr('Te oye por el micrófono del teléfono. La voz de la app suena en alta calidad. Enciéndelo para practicar con el teléfono guardado (solo audífonos Bluetooth).')),
        value: none ? false : on,
        onChanged: none ? null : (v) => ref.read(headsetMicProvider.notifier).set(v),
      ),
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

/// «Practicar la palabra que fallo»: al fallar una frase, un mini-taller de esa palabra antes de repetirla.
class _WordDrillCard extends ConsumerWidget {
  const _WordDrillCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(wordDrillSettingProvider).valueOrNull ?? true;
    return Card(
      child: SwitchListTile(
        key: const ValueKey('word-drill-switch'),
        title: Text(tr('Practicar la palabra que fallo')),
        subtitle: Text(tr('Si una palabra de la frase no se entiende, la practicas sola, luego en su trozo y vuelves a la frase.')),
        value: on,
        onChanged: (v) => ref.read(wordDrillSettingProvider.notifier).set(v),
      ),
    );
  }
}

/// El nombre de la mascota (lo elige el alumno). No sale si la mascota no está disponible.
class _PetNameCard extends ConsumerWidget {
  const _PetNameCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider).valueOrNull;
    if (pet == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        key: const ValueKey('pet-name-tile'),
        title: Text(tr('Nombre de tu mascota')),
        subtitle: Text(pet.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(context: context, builder: (_) => PetNameDialog(pet: pet)),
      ),
    );
  }
}

/// El color de la mascota (lo elige el alumno; nace de color neutro).
class _PetColorCard extends ConsumerWidget {
  const _PetColorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider).valueOrNull;
    if (pet == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        key: const ValueKey('pet-color-tile'),
        title: Text(tr('Color de tu mascota')),
        subtitle: Text(BrainyColors.nameOf(pet.color)),
        leading: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: BrainyColors.of(pet.color))),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(context: context, builder: (_) => PetColorDialog(pet: pet)),
      ),
    );
  }
}

/// «Modo Brainy»: la pantalla principal pasa a ser la mascota. Apagado por defecto; no quita nada.
class _BrainyModeCard extends ConsumerWidget {
  const _BrainyModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(brainyModeProvider).valueOrNull ?? false;
    return Card(
      child: SwitchListTile(
        key: const ValueKey('brainy-mode-switch'),
        title: Text(tr('Modo Brainy')),
        subtitle: Text(tr('La pantalla principal es Brainy, tu mascota: cuidarla es estudiar. Tu sesión y todo lo demás siguen a un toque.')),
        value: on,
        onChanged: (v) => ref.read(brainyModeProvider.notifier).set(v),
      ),
    );
  }
}
