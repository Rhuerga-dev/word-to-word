import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/session/data/session_repository.dart';
import '../l10n/tr.dart';
import '../services/audio_service.dart';
import '../services/hands_free.dart';
import '../theme/app_theme.dart';
import '../utils/pron_tips.dart';
import '../utils/word_drill.dart';
import 'how_to_say.dart';
import 'mic_button.dart';
import 'step_page.dart';
import 'w2w_loader.dart';

/// Pasos del mini-taller: la palabra sola → su trozo de frase → volver a la frase completa.
enum DrillStage { word, chunk, done }

/// Mini-taller de UNA palabra que salió mal en una frase (20–30 s):
/// escucharla despacio con la técnica, decirla sola, decirla en su trozo y volver a la frase.
/// Nunca se atasca: tras [drillTries] intentos por paso, sigue igual.
class WordDrillView extends ConsumerStatefulWidget {
  const WordDrillView({super.key, required this.plan, required this.onDone});
  final DrillPlan plan;
  final VoidCallback onDone;

  @override
  ConsumerState<WordDrillView> createState() => WordDrillViewState();
}

class WordDrillViewState extends ConsumerState<WordDrillView> {
  DrillStage stage = DrillStage.word;
  bool recording = false, checking = false;
  int tries = 0;
  int? score;
  String msg = '';

  DrillPlan get p => widget.plan;
  String get text => stage == DrillStage.chunk ? p.chunk : p.word;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  Future<void> _listen() async {
    if (!mounted || stage == DrillStage.done) return;
    try {
      await ref.read(audioProvider).say(text, slow: true);
    } catch (_) {}
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> attempt() async {
    if (recording || checking || stage == DrillStage.done) return;
    final audio = ref.read(audioProvider);
    _set(() {
      recording = true;
      msg = '';
    });
    try {
      final rec = await audio.record(maxMs: 6000, silenceMs: 1000);
      _set(() => recording = false);
      if (!rec.heard && !rec.maybeVoice) {
        _set(() => msg = tr('No te oí. Habla un poco más cerca.'));
        return;
      }
      _set(() => checking = true);
      final s = await ref.read(sessionRepositoryProvider).assess(text, stage == DrillStage.word ? p.phoneme : null, rec.wav);
      _set(() {
        checking = false;
        score = s;
        tries++;
      });
      if (s >= drillPassScore || tries >= drillTries) await _next();
    } catch (_) {
      // Sin evaluación (sin conexión, sin Azure): no se atasca, vuelve a la frase.
      _set(() {
        recording = false;
        checking = false;
      });
      widget.onDone();
    }
  }

  void finish() => ref.read(audioProvider).stopRecording();

  Future<void> _next() async {
    final ok = (score ?? 0) >= drillPassScore;
    _set(() {
      msg = ok ? tr('¡Bien!') : tr('Sigue, la repasamos otro día.');
      stage = stage == DrillStage.word && p.chunk != p.word ? DrillStage.chunk : DrillStage.done;
      tries = 0;
      if (stage != DrillStage.done) score = null;
    });
    await _listen();
  }

  @override
  Widget build(BuildContext context) {
    final tips = buildTips([(p.word, p.phonemes)]);
    final done = stage == DrillStage.done;
    final page = StepPage(
      bottom: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (done)
            bottomPad(SizedBox(
              width: double.infinity,
              child: FilledButton(key: const ValueKey('drill-continue'), onPressed: widget.onDone, child: Text(tr('Decir la frase completa'))),
            ))
          else ...[
            MicButton(recording: recording, onPressed: checking ? null : (recording ? finish : attempt)),
            const SizedBox(height: 10),
            Text(recording ? tr('Te escucho… toca al terminar') : tr('Dilo tú'), style: const TextStyle(color: W.muted)),
            TextButton(onPressed: widget.onDone, child: Text(tr('Saltar'))),
          ],
        ]),
      ),
      children: [
        stepKind(tr('Practiquemos una palabra'), color: W.warn),
        if (!done) ...[
          Text(stage == DrillStage.word ? tr('1. La palabra sola') : tr('2. En su trozo de frase'), style: const TextStyle(color: W.muted)),
          Row(children: [
            Expanded(child: Text(text, key: const ValueKey('drill-text'), style: W.display(30, color: W.good, weight: FontWeight.w700))),
            IconButton(tooltip: tr('Escuchar'), icon: const Icon(Icons.volume_up), onPressed: _listen),
          ]),
          if (score != null)
            Text(score! >= drillPassScore ? '✓ $score/100' : tr('{0}/100 — escucha y otra vez', [score!]),
                style: TextStyle(fontWeight: FontWeight.w700, color: score! >= drillPassScore ? W.good : W.warn)),
          if (stage == DrillStage.word && tips.isNotEmpty) HowToSay(tips: tips, loading: false, target: p.word),
        ] else ...[
          Text(tr('3. Ahora la frase completa'), style: const TextStyle(color: W.muted)),
          Text(p.sentence, key: const ValueKey('drill-sentence'), style: W.display(24, color: W.good, weight: FontWeight.w600)),
        ],
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(msg, style: const TextStyle(color: W.muted))),
      ],
    );
    return Stack(children: [
      page,
      if (checking)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
            child: Center(child: W2WLoader(label: tr('Evaluando tu pronunciación…'))),
          ),
        ),
    ]);
  }
}

/// Manos libres: el mismo mini-taller por voz (sin tocar la pantalla).
Future<void> wordDrillHandsFree(HandsFreeController hf, SessionRepository repo, DrillPlan p, {required bool spanish}) async {
  if (spanish) {
    await hf.say('Vamos a practicar una palabra.', lang: 'es');
  } else {
    await hf.say("Let's practice one word.");
  }
  await hf.say(p.word, slow: true);
  await sayTip(hf, buildTips([(p.word, p.phonemes)]), spanish: spanish);
  final steps = [(p.word, p.phoneme), if (p.chunk != p.word) (p.chunk, null)];
  for (final (text, phoneme) in steps) {
    for (var i = 0; i < drillTries; i++) {
      await hf.say(i == 0 ? 'Say: $text.' : 'Again: $text.');
      final h = await hf.listen(maxMs: 6000, silenceMs: 1000, transcribe: false);
      if (h.silent || h.wav == null) continue;
      int score;
      try {
        score = await repo.assess(text, phoneme, h.wav!);
      } catch (_) {
        return; // sin evaluación: se vuelve a la frase
      }
      if (score >= drillPassScore) {
        await hf.say('Good!');
        break;
      }
      if (i + 1 < drillTries) {
        await hf.say('Listen.');
        await hf.say(text, slow: true);
      }
    }
  }
  await hf.say('Now the whole sentence.');
}
