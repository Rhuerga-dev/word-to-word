import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../audio.dart';
import '../theme.dart';

/// Dos palabras por sonido difícil (las mismas ideas que el Taller de la web).
const soundWords = <String, List<String>>{
  'θ': ['think', 'three'], 'ð': ['this', 'mother'], 'v': ['very', 'voice'], 'ɪ': ['ship', 'sit'], 'i': ['sheep', 'seat'],
  'æ': ['cat', 'apple'], 'ʌ': ['cup', 'money'], 'z': ['zoo', 'easy'], 'ʃ': ['she', 'shop'], 'ɹ': ['red', 'right'],
  'h': ['house', 'hello'], 'ɜ': ['work', 'bird'], 'oʊ': ['go', 'phone'], 'ʒ': ['usual', 'vision'], 'ŋ': ['thing', 'morning'],
};
String? soundKey(String p) {
  final k = p.replaceAll('ː', '');
  if (k == 'r') return 'ɹ';
  if (k == 'ɝ' || k == 'ɚ') return 'ɜ';
  return soundWords.containsKey(k) ? k : null;
}

sealed class SessionStep {}

class ReviewStep extends SessionStep {
  ReviewStep(this.card);
  final Map card;
}

class NewStep extends SessionStep {
  NewStep(this.card);
  final Map card;
}

class SoundStep extends SessionStep {
  SoundStep(this.phoneme, this.word);
  final String phoneme, word;
}

class NarrateStep extends SessionStep {}

class MistakeStep extends SessionStep {
  MistakeStep(this.mistake);
  final Map mistake;
}

/// Lo que toca hoy (de GET /session/today), en orden.
class SessionPlan {
  SessionPlan(this.steps, {this.title, this.daily = true});
  final List<SessionStep> steps;
  final String? title;
  final bool daily; // la sesión de Hoy (al final se registra y da bono)

  factory SessionPlan.fromToday(Map<String, dynamic> d) {
    final plan = d['plan'] as Map;
    final steps = <SessionStep>[
      for (final c in plan['reviews'] as List) ReviewStep(c as Map),
      for (final c in plan['new'] as List) NewStep(c as Map),
    ];
    final sounds = (plan['sounds'] as List).map((s) => soundKey(s['phoneme'] as String)).whereType<String>().toList();
    final ph = sounds.isNotEmpty ? sounds.first : const ['θ', 'v', 'ɪ', 'æ', 'z'][DateTime.now().day % 5];
    for (final w in soundWords[ph]!) {
      steps.add(SoundStep(ph, w));
    }
    steps.add(NarrateStep()); // por ahora la app hace la narración; foto y shadowing llegan después
    for (final m in plan['mistakes'] as List) {
      steps.add(MistakeStep(m as Map));
    }
    return SessionPlan(steps);
  }
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.plan});
  final SessionPlan plan;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _i = 0;
  int _xp = 0, _right = 0, _graded = 0;
  final _t0 = DateTime.now();
  Map<String, dynamic>? _end;
  bool _ending = false;

  void _next() {
    if (_i + 1 >= widget.plan.steps.length) {
      _finish();
    } else {
      setState(() => _i++);
    }
  }

  void _gain(num? xp) => setState(() => _xp += (xp ?? 0).toInt());

  Future<void> _finish() async {
    setState(() => _ending = true);
    Map<String, dynamic>? r;
    if (widget.plan.daily) {
      try {
        r = Map<String, dynamic>.from(await context.read<Api>().post('/session/complete') as Map);
      } catch (_) {}
    }
    if (mounted) setState(() => _end = r ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.plan.steps;
    final progress = _ending ? 1.0 : _i / steps.length;
    return Scaffold(
      backgroundColor: W.card,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
            child: Row(children: [
              IconButton(tooltip: 'Salir', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: progress, minHeight: 14, color: W.good, backgroundColor: W.bg),
                ),
              ),
              SizedBox(width: 52, child: Text(_xp > 0 ? '+$_xp' : '', textAlign: TextAlign.right, style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700))),
            ]),
          ),
          Expanded(
            child: _ending
                ? _EndView(data: _end, xp: _xp, right: _right, graded: _graded, minutes: DateTime.now().difference(_t0).inMinutes, title: widget.plan.title)
                : KeyedSubtree(key: ValueKey(_i), child: _stepView(steps[_i])),
          ),
        ]),
      ),
    );
  }

  Widget _stepView(SessionStep s) => switch (s) {
        ReviewStep(:final card) => _ReviewView(card: card, onGraded: (ok, xp) {
            _graded++;
            if (ok) _right++;
            _gain(xp);
          }, onNext: _next),
        NewStep(:final card) => _NewView(card: card, onXp: _gain, onNext: _next),
        SoundStep(:final phoneme, :final word) => _SoundView(phoneme: phoneme, word: word, onNext: _next),
        NarrateStep() => _NarrateView(onNext: _next),
        MistakeStep(:final mistake) => _MistakeView(mistake: mistake, onXp: _gain, onNext: _next),
      };
}

/// Franja de abajo con la respuesta y "Continuar".
class Feedback extends StatelessWidget {
  const Feedback({super.key, required this.ok, required this.title, this.detail, required this.onNext});
  final bool ok;
  final String title;
  final String? detail;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final c = ok ? W.good : W.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), border: Border(top: BorderSide(color: c.withValues(alpha: .5), width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: W.display(22, color: c)),
        if (detail != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail!)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onNext, child: const Text('Continuar')),
      ]),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children, this.bottom});
  final List<Widget> children;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 22), children: children)),
        if (bottom != null) bottom!,
      ]);
}

Widget _kind(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
    );

Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: child);

// ---------- Ficha de repaso ----------
class _ReviewView extends StatefulWidget {
  const _ReviewView({required this.card, required this.onGraded, required this.onNext});
  final Map card;
  final void Function(bool ok, num? xp) onGraded;
  final VoidCallback onNext;
  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  bool _shown = false, _busy = false;
  String? _grade;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.card['english_only'] != true) context.read<AppAudio>().say(widget.card['word'] as String);
  }

  Future<void> _rate(String g) async {
    setState(() => _busy = true);
    try {
      final r = await context.read<Api>().post('/words/${widget.card['id']}/review', {'grade': g});
      widget.onGraded(g != 'again', r['xp_gained'] as num?);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _grade = g);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card, en = c['english_only'] == true;
    final pv = (c['previews'] as Map?) ?? const {'again': 1, 'hard': 1, 'good': 3, 'easy': 7};
    final audio = context.read<AppAudio>();
    final bottom = _grade != null
        ? Feedback(
            ok: _grade != 'again' && _error == null,
            title: _error != null ? 'No se guardó' : (_grade == 'again' ? 'La repasarás pronto' : '¡Bien!'),
            detail: _error ?? '${c['word']} · ${c['translation']}',
            onNext: widget.onNext)
        : !_shown
            ? _pad(FilledButton(onPressed: () => setState(() => _shown = true), child: const Text('Ver la respuesta')))
            : _pad(Row(children: [
                for (final g in const [['again', 'Olvidé'], ['hard', 'Difícil'], ['good', 'Bien'], ['easy', 'Fácil']])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _rate(g[0]),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(g[1], style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(days(pv[g[0]] as num), style: const TextStyle(fontSize: 11, color: W.muted)),
                        ]),
                      ),
                    ),
                  ),
              ]));
    return _Page(bottom: bottom, children: [
      _kind(en && !_shown ? 'Solo inglés · ¿qué palabra falta?' : 'Repaso · ¿qué significa?'),
      if (en && !_shown) ...[
        if (c['definition'] != null) Text(c['definition'] as String, style: W.display(22, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(plainExample(c['example'] as String?, cloze: true), style: const TextStyle(fontSize: 20)),
      ] else ...[
        Row(children: [
          Flexible(child: Text(c['word'] as String, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => audio.say(c['word'] as String)),
        ]),
        if (_shown) ...[
          const SizedBox(height: 8),
          Text(en && c['definition'] != null ? c['definition'] as String : c['translation'] as String,
              style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(plainExample(c['example'] as String?), style: const TextStyle(fontSize: 19)),
          if (en) Text(c['translation'] as String, style: const TextStyle(color: W.muted)),
        ],
      ],
      const SizedBox(height: 12),
      if (!_shown) const Text('Dilo en voz alta antes de ver la respuesta.', style: TextStyle(color: W.muted)),
    ]);
  }
}

// ---------- Palabra nueva ----------
class _NewView extends StatefulWidget {
  const _NewView({required this.card, required this.onXp, required this.onNext});
  final Map card;
  final void Function(num?) onXp;
  final VoidCallback onNext;
  @override
  State<_NewView> createState() => _NewViewState();
}

class _NewViewState extends State<_NewView> {
  bool? _ok;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<AppAudio>().say(widget.card['word'] as String);
  }

  Future<void> _learn() async {
    setState(() => _busy = true);
    try {
      final r = await context.read<Api>().post('/words/${widget.card['id']}/learn');
      widget.onXp(r['xp_gained'] as num?);
      _ok = true;
    } catch (_) {
      _ok = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return _Page(
      bottom: _ok != null
          ? Feedback(ok: _ok!, title: _ok! ? '¡Nueva palabra!' : 'No se guardó', detail: _ok! ? 'Mañana la repasas.' : null, onNext: widget.onNext)
          : _pad(FilledButton(onPressed: _busy ? null : _learn, child: const Text('La tengo'))),
      children: [
        _kind('Palabra nueva'),
        Row(children: [
          Flexible(child: Text(c['word'] as String, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => context.read<AppAudio>().say(c['word'] as String)),
        ]),
        Text(c['translation'] as String? ?? '', style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(plainExample(c['example'] as String?), style: const TextStyle(fontSize: 19)),
        Text(c['example_es'] as String? ?? '', style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
        const Text('Dila en voz alta dos veces y úsala en una frase tuya.', style: TextStyle(color: W.muted)),
      ],
    );
  }
}

/// Botón grande de micrófono.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.recording, required this.onPressed});
  final bool recording;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          button: true,
          label: recording ? 'Grabando' : 'Hablar',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording ? W.bad : W.accent,
                boxShadow: [BoxShadow(color: (recording ? W.bad : W.accent).withValues(alpha: .18), spreadRadius: 10)],
              ),
              child: Icon(recording ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 40),
            ),
          ),
        ),
      );
}

// ---------- Sonido débil ----------
class _SoundView extends StatefulWidget {
  const _SoundView({required this.phoneme, required this.word, required this.onNext});
  final String phoneme, word;
  final VoidCallback onNext;
  @override
  State<_SoundView> createState() => _SoundViewState();
}

class _SoundViewState extends State<_SoundView> {
  bool _rec = false;
  int _tries = 0;
  int? _pct;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    context.read<AppAudio>().say(widget.word, slow: true);
  }

  Future<void> _say() async {
    final audio = context.read<AppAudio>(), api = context.read<Api>();
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final r = await audio.record(maxMs: 3500, silenceMs: 700);
      if (!r.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        final res = await api.upload('/pronunciation/assess', r.wav, fields: {'text': widget.word, 'phoneme': widget.phoneme});
        _pct = ((res['target_score'] ?? res['score']) as num).toInt();
        _tries++;
        if (_pct! < 80 && _tries < 3) {
          _msg = 'Sonido al $_pct%: escúchala otra vez y exagera el movimiento.';
          audio.say(widget.word, slow: true);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final done = _pct != null && (_pct! >= 80 || _tries >= 3);
    return _Page(
      bottom: done
          ? Feedback(ok: _pct! >= 80, title: _pct! >= 80 ? '¡Bien dicho!' : 'Sigue practicándolo', detail: '/${widget.phoneme}/ al $_pct%', onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                const Text('Toca y dila en voz alta', style: TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        _kind('Pronunciación · /${widget.phoneme}/'),
        Row(children: [
          Flexible(child: Text(widget.word, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => context.read<AppAudio>().say(widget.word, slow: true)),
        ]),
        const SizedBox(height: 10),
        if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: W.warn)),
      ],
    );
  }
}

// ---------- Narración del día ----------
class _NarrateView extends StatefulWidget {
  const _NarrateView({required this.onNext});
  final VoidCallback onNext;
  @override
  State<_NarrateView> createState() => _NarrateViewState();
}

class _NarrateViewState extends State<_NarrateView> {
  Map? _topic;
  int? _session;
  String _phase = 'loading'; // loading · ready · rec · wait · done · error
  String _error = '';
  Map? _fb;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final r = await context.read<Api>().post('/speaking/sessions', {'scenario': 'narrate'});
      _topic = r['topic'] as Map;
      _session = (r['id'] as num).toInt();
      _phase = 'ready';
    } catch (e) {
      _phase = 'error';
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _go() async {
    final audio = context.read<AppAudio>(), api = context.read<Api>();
    await audio.say(_topic!['en'] as String);
    await audio.say('Habla un minuto. Empieza ya.', lang: 'es');
    setState(() => _phase = 'rec');
    final t0 = DateTime.now();
    int? reaction;
    try {
      final r = await audio.record(maxMs: 58000, silenceMs: 4000, onVoice: () => reaction = DateTime.now().difference(t0).inMilliseconds);
      if (!r.heard) throw ApiException('No te oí. Acércate al micrófono y prueba otra vez.');
      if (mounted) setState(() => _phase = 'wait');
      final turn = await api.upload('/speaking/sessions/$_session/turns', r.wav, fields: {if (reaction != null) 'reaction_ms': '$reaction'});
      _text = (turn['text'] as String?) ?? '';
      if (_text.isEmpty) throw ApiException('No se entendió lo que dijiste. Prueba otra vez, un poco más alto.');
      _fb = await api.post('/speaking/sessions/$_session/narration', {'text': _text}) as Map;
      await api.post('/speaking/sessions/$_session/finish');
      _phase = 'done';
      if (mounted) setState(() {});
      if (_fb?['comment'] != null) await audio.say(_fb!['comment'] as String);
    } catch (e) {
      _phase = 'error';
      _error = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AppAudio>();
    final children = <Widget>[
      _kind('Narración del día · 1 minuto'),
      if (_topic != null) ...[
        Text(_topic!['en'] as String, style: W.display(24, weight: FontWeight.w600)),
        Text(_topic!['es'] as String, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
      ],
      if (_phase == 'loading') const Center(child: CircularProgressIndicator()),
      if (_phase == 'ready') const Text('Hablas un minuto sin parar, sin preparar nada. Si te quedas en blanco, describe lo que ves y sigue.'),
      if (_phase == 'rec') const Text('Te escucho… habla sin parar, aunque te equivoques.', style: TextStyle(color: W.bad, fontWeight: FontWeight.w700)),
      if (_phase == 'wait') const Text('Revisando lo que dijiste…'),
      if (_phase == 'error') Text(_error, style: const TextStyle(color: W.bad)),
      if (_phase == 'done' && _fb != null) ...[
        if (_fb!['comment'] != null) Text(_fb!['comment'] as String, style: const TextStyle(fontSize: 17)),
        if (_fb!['better'] != null) ...[
          const SizedBox(height: 14),
          Text('Así sonaría más natural', style: W.display(18)),
          const SizedBox(height: 6),
          Text(_fb!['better'] as String, style: const TextStyle(fontSize: 17, height: 1.5)),
          TextButton.icon(onPressed: () => audio.say(_fb!['better'] as String), icon: const Icon(Icons.volume_up), label: const Text('Escuchar')),
        ],
        for (final f in (_fb!['mistakes'] as List? ?? const []))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${f['said']}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: W.bad)),
              const TextSpan(text: '  →  '),
              TextSpan(text: '${f['correct']}', style: const TextStyle(color: W.good, fontWeight: FontWeight.w700)),
            ])),
          ),
      ],
    ];
    final bottom = switch (_phase) {
      'ready' => _pad(FilledButton.icon(onPressed: _go, icon: const Icon(Icons.mic), label: const Text('Empezar'))),
      'rec' => _pad(FilledButton(onPressed: audio.stopRecording, child: const Text('Terminé'))),
      'done' => _pad(FilledButton(onPressed: widget.onNext, child: const Text('Continuar'))),
      'error' => _pad(Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.onNext, child: const Text('Saltar'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: _session == null ? _create : _go, child: const Text('Otra vez'))),
        ])),
      _ => null,
    };
    return _Page(bottom: bottom, children: children);
  }
}

// ---------- Error para repasar ----------
class _MistakeView extends StatefulWidget {
  const _MistakeView({required this.mistake, required this.onXp, required this.onNext});
  final Map mistake;
  final void Function(num?) onXp;
  final VoidCallback onNext;
  @override
  State<_MistakeView> createState() => _MistakeViewState();
}

class _MistakeViewState extends State<_MistakeView> {
  bool _rec = false;
  Map? _r;
  String _msg = '';
  int _tries = 0;

  Future<void> _say() async {
    final audio = context.read<AppAudio>(), api = context.read<Api>();
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final rec = await audio.record(maxMs: 15000, silenceMs: 1400);
      if (!rec.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        final r = await api.upload('/speaking/mistakes/${widget.mistake['id']}/review', rec.wav) as Map;
        if (r['silent'] == true) {
          _msg = 'No se entendió. Prueba otra vez.';
        } else {
          _r = r;
          _tries++;
          widget.onXp(r['xp_gained'] as num?);
          await audio.say(widget.mistake['correct'] as String);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mistake, passed = _r?['passed'] == true;
    final done = _r != null && (passed || _tries >= 2);
    return _Page(
      bottom: done
          ? Feedback(ok: passed, title: passed ? '¡Bien dicho!' : 'Vuelve mañana', detail: m['correct'] as String, onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                Text(_r == null ? 'Dilo bien en voz alta' : 'Otra vez', style: const TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        _kind('Tus errores · dilo bien'),
        const Text('Dijiste:', style: TextStyle(color: W.muted)),
        Text(m['said'] as String, style: const TextStyle(fontSize: 22, decoration: TextDecoration.lineThrough, color: W.bad)),
        if (m['why'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${m['why']}', style: const TextStyle(color: W.muted))),
        if (_r != null && !passed) ...[
          const SizedBox(height: 12),
          Text('Entendí: “${_r!['heard']}”', style: const TextStyle(color: W.muted)),
          Text(m['correct'] as String, style: W.display(22, color: W.good, weight: FontWeight.w600)),
        ],
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg, style: const TextStyle(color: W.warn))),
      ],
    );
  }
}

// ---------- Fin ----------
class _EndView extends StatelessWidget {
  const _EndView({required this.data, required this.xp, required this.right, required this.graded, required this.minutes, this.title});
  final Map<String, dynamic>? data;
  final int xp, right, graded, minutes;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final x = d['xp'] as Map?;
    final ach = (d['achievements'] as List?) ?? const [];
    final today = (d['today'] as Map?) ?? const {};
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(color: W.yellow, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 56, color: W.yellowInk),
            ),
          ),
          const SizedBox(height: 18),
          Text(title == null ? '¡Sesión completa!' : '¡Listo!', textAlign: TextAlign.center, style: W.display(32)),
          if (x != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text((x['xp'] as num) >= (x['goal'] as num) ? 'Cumpliste tu meta de hoy' : 'Llevas ${x['xp']} de ${x['goal']} XP hoy',
                  textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
            ),
          const SizedBox(height: 20),
          Row(children: [
            _tile('PUNTOS', '+${xp + ((d['xp_gained'] as num?) ?? 0).toInt()}', W.accent),
            const SizedBox(width: 8),
            _tile('FICHAS BIEN', graded == 0 ? '—' : '${(right * 100 / graded).round()}%', W.good),
            const SizedBox(width: 8),
            _tile('TIEMPO', '${minutes < 1 ? 1 : minutes} min', const Color(0xFFC0640C)),
          ]),
          if (d['streak'] != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text('🔥 ${d['streak']} días seguidos', textAlign: TextAlign.center, style: W.display(20))),
          if ((today['learned'] ?? 0) > 0) Text('✓ ${today['learned']} palabras nuevas'),
          if ((today['mistakes_ok'] ?? 0) > 0) Text('✓ ${today['mistakes_ok']} errores dichos bien'),
          for (final a in ach) Padding(padding: const EdgeInsets.only(top: 10), child: Text('🏅 ¡Nuevo logro! ${a['title']} · ${a['desc']}', style: const TextStyle(color: W.good, fontWeight: FontWeight.w700))),
        ]),
      ),
      _pad(FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuar'))),
    ]);
  }

  Widget _tile(String label, String value, Color c) => Expanded(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(width: double.infinity, color: c, padding: const EdgeInsets.symmetric(vertical: 5), child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(value, style: W.display(22))),
          ]),
        ),
      );
}
