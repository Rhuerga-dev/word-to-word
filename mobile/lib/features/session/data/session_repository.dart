import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/word_drill.dart';
import '../../today/data/today.dart';
import 'word_card.dart';
import 'ear_item.dart';

/// Tema de la narración del día.
class NarrationTopic {
  const NarrationTopic({required this.sessionId, required this.en, required this.es});
  final int sessionId;
  final String en, es;
}

class NarrationFeedback {
  const NarrationFeedback({this.comment, this.better, this.fixes = const []});
  final String? comment;
  final String? better;
  final List<(String said, String correct)> fixes;
}

class MistakeReview {
  const MistakeReview({required this.silent, required this.passed, required this.heard, required this.xpGained});
  final bool silent, passed;
  final String heard;
  final int xpGained;
}

/// Un turno de la conversación: lo que responde la IA, y la corrección del último mensaje del alumno.
class ConversationTurn {
  const ConversationTurn({required this.reply, this.feedback, this.fixes = const []});
  final String reply;
  final String? feedback;
  final List<(String said, String correct)> fixes;
}

/// Resultado de la prueba de la unidad (una conversación con nota).
class UnitTestResult {
  const UnitTestResult({required this.passed, this.score, required this.feedback});
  final bool passed;
  final int? score;
  final String feedback;
}

/// Texto para el shadowing: un título y sus frases para repetir.
class ShadowingText {
  const ShadowingText({required this.title, required this.sentences});
  final String title;
  final List<String> sentences;
}

/// Nota de una frase de shadowing (Azure): pronunciación, fluidez, precisión y palabra por palabra.
class ShadowingScore {
  const ShadowingScore({required this.ok, required this.score, required this.fluency, required this.accuracy, required this.words});

  /// Se reconoció la voz (si no, hay que repetir).
  final bool ok;
  final int score, fluency, accuracy;

  /// Cada palabra y si sonó bien (verde) o no (rojo).
  final List<(String word, bool good)> words;
}

/// Lo que devuelve terminar la sesión de Hoy.
class SessionResult {
  const SessionResult({this.xp, this.streak, this.xpGained = 0, this.learned = 0, this.mistakesOk = 0, this.achievements = const []});
  final XpToday? xp;
  final int? streak;
  final int xpGained, learned, mistakesOk;
  final List<Achievement> achievements;

  factory SessionResult.fromJson(Map<String, dynamic> j) {
    final today = asMap(j['today']);
    return SessionResult(
      xp: j['xp'] == null ? null : XpToday.fromJson(asMap(j['xp'])),
      streak: j['streak'] == null ? null : asInt(j['streak']),
      xpGained: asInt(j['xp_gained']),
      learned: asInt(today['learned']),
      mistakesOk: asInt(today['mistakes_ok']),
      achievements: listOf(j['achievements'], Achievement.fromJson),
    );
  }
}

/// Todo lo que hacen los ejercicios contra el servidor.
class SessionRepository {
  SessionRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  /// Sin conexión, las fichas no se pierden: se guardan y se suben al volver (sin puntos al momento).
  Future<int> _postOrQueue(String path, [Map<String, dynamic>? body]) async {
    try {
      return asInt(asMap(await _api.post(path, body))['xp_gained']);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _cache.enqueue(path, body);
      return 0;
    }
  }

  /// Nota a una ficha (again · hard · good · easy). Devuelve los puntos ganados.
  Future<int> review(int cardId, String grade) => _postOrQueue('/words/$cardId/review', {'grade': grade});

  Future<int> learn(int cardId) => _postOrQueue('/words/$cardId/learn');

  /// Oído: si la reconociste y cuánto tardaste desde que terminó de sonar (sin conexión se guarda).
  Future<EarResult> ear(int wordId, {required bool ok, required int ms}) async {
    final body = {'ok': ok, 'ms': ms};
    try {
      final r = asMap(await _api.post('/words/$wordId/ear', body));
      return EarResult(xp: asInt(r['xp_gained']), fast: asBool(r['fast']), automatic: asBool(r['automatic']), mode: asStringOrNull(r['mode']));
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _cache.enqueue('/words/$wordId/ear', body);
      return EarResult(fast: ok && ms <= 3000);
    }
  }

  /// Una palabra que no entiendes dentro de una definición: su significado más simple.
  Future<WordLookup> lookup(String word) async => WordLookup.fromJson(asMap(await _api.get('/words/lookup?w=${Uri.encodeQueryComponent(word)}')));

  /// Lo que dijiste, en texto (inglés).
  Future<String> transcribe(Uint8List wav) async => asString(asMap(await _api.upload('/speech/transcribe', wav))['text']);

  /// Cuando no se te entendió: las palabras que fallaron y sus sonidos flojos (vacío si no hay detalle).
  /// Las palabras que salieron flojas al decir [text] (Azure): nota, tipo de error y sonidos flojos.
  Future<List<WeakWord>> pronTips(String text, Uint8List wav) async {
    final r = asMap(await _api.upload('/pronunciation/tips', wav, fields: {'text': text}));
    final words = r['words'] is List ? r['words'] as List : const [];
    return [
      for (final w in words)
        WeakWord(
          asString(asMap(w)['word']),
          accuracy: asInt(asMap(w)['accuracy']),
          error: asString(asMap(w)['error']),
          phonemes: [for (final p in (asMap(w)['phonemes'] is List ? asMap(w)['phonemes'] as List : const [])) '$p'],
        ),
    ];
  }

  /// Puntuación (0–100) del sonido [phoneme] al decir [word].
  /// Sin [phoneme], la nota de toda la pronunciación de [word] (una palabra o un trozo de frase).
  Future<int> assess(String word, String? phoneme, Uint8List wav) async {
    final r = asMap(await _api.upload('/pronunciation/assess', wav, fields: {'text': word, if (phoneme != null) 'phoneme': phoneme}));
    return asInt(r['target_score'] ?? r['score']);
  }

  Future<NarrationTopic> startNarration() async {
    final r = asMap(await _api.post('/speaking/sessions', {'scenario': 'narrate'}));
    final topic = asMap(r['topic']);
    return NarrationTopic(sessionId: asInt(r['id']), en: asString(topic['en']), es: asString(topic['es']));
  }

  /// Sube lo que dijiste y devuelve el texto que entendió el servidor.
  Future<String> sendTurn(int sessionId, Uint8List wav, {int? reactionMs}) async {
    final r = asMap(await _api.upload('/speaking/sessions/$sessionId/turns', wav, fields: {if (reactionMs != null) 'reaction_ms': '$reactionMs'}));
    return asString(r['text']);
  }

  Future<NarrationFeedback> narration(int sessionId, String text) async {
    final r = asMap(await _api.post('/speaking/sessions/$sessionId/narration', {'text': text}));
    return NarrationFeedback(
      comment: asStringOrNull(r['comment']),
      better: asStringOrNull(r['better']),
      fixes: [for (final m in asMaps(r['mistakes'])) (asString(m['said']), asString(m['correct']))],
    );
  }

  Future<void> finishSpeaking(int sessionId) => _api.post('/speaking/sessions/$sessionId/finish');

  Future<MistakeReview> reviewMistake(int mistakeId, Uint8List wav) async {
    final r = asMap(await _api.upload('/speaking/mistakes/$mistakeId/review', wav));
    return MistakeReview(silent: asBool(r['silent']), passed: asBool(r['passed']), heard: asString(r['heard']), xpGained: asInt(r['xp_gained']));
  }

  Future<SessionResult> complete() async => SessionResult.fromJson(asMap(await _api.post('/session/complete')));

  /// Texto de shadowing. Con [unit], el de esa unidad del Camino; [skip] trae otro texto del mismo tema.
  Future<ShadowingText> shadowing({int skip = 0, String? unit}) async {
    final q = <String>[
      if (skip > 0) 'skip=$skip',
      if (unit != null) 'unit=${Uri.encodeQueryComponent(unit)}',
    ];
    final r = asMap(await _api.get('/speaking/shadowing${q.isEmpty ? '' : '?${q.join('&')}'}'));
    return ShadowingText(
      title: asString(r['title']),
      sentences: [for (final s in (r['sentences'] is List ? r['sentences'] as List : const [])) '$s'],
    );
  }

  /// Nota completa de una frase de shadowing (nota, fluidez, precisión y palabra por palabra).
  Future<ShadowingScore> assessShadow(String text, Uint8List wav) async {
    final r = asMap(await _api.upload('/pronunciation/assess', wav, fields: {'text': text}));
    final a = asMap(r['assessment']);
    final scores = asMap(a['scores']);
    final words = a['words'] is List ? a['words'] as List : const [];
    return ShadowingScore(
      ok: asString(a['status']) == 'Success',
      score: asInt(r['score']),
      fluency: asInt(scores['fluency']),
      accuracy: asInt(scores['accuracy']),
      // La "Insertion" (una palabra de más) no se pinta; el resto, verde si acertó y ≥60.
      words: [
        for (final w in words)
          if (asString(asMap(w)['error']) != 'Insertion')
            (asString(asMap(w)['word']), asString(asMap(w)['error']) == 'None' && asInt(asMap(w)['accuracy']) >= 60),
      ],
    );
  }

  /// Marca hecho el shadowing de una unidad con el promedio (el servidor exige ≥60).
  Future<void> unitShadowDone(String unitId, int score) => _api.post('/path/units/$unitId/shadow', {'score': score});

  /// Abre una conversación (prueba de la unidad) con su situación. Devuelve el id de la sesión.
  Future<int> startConversation(String scenario) async =>
      asInt(asMap(await _api.post('/speaking/sessions', {'scenario': scenario}))['id']);

  /// Un turno: la IA responde y corrige el último mensaje del alumno.
  Future<ConversationTurn> converse({required int sessionId, required String scenario, required List<Map<String, String>> messages}) async {
    final r = asMap(await _api.post('/conversation', {'messages': messages, 'scenario': scenario, 'voice': true, 'session_id': sessionId}));
    return ConversationTurn(
      reply: asString(r['reply']),
      feedback: asStringOrNull(r['feedback']),
      fixes: [for (final m in asMaps(r['mistakes'])) (asString(m['said']), asString(m['correct']))],
    );
  }

  /// Califica la conversación de la unidad (necesita ≥5 respuestas del alumno; aprueba con ≥6/10).
  Future<UnitTestResult> unitTest(String unitId, int sessionId, List<Map<String, String>> messages) async {
    final r = asMap(await _api.post('/path/units/$unitId/test', {'session_id': sessionId, 'messages': messages}));
    return UnitTestResult(passed: asBool(r['passed']), score: r['score'] == null ? null : asInt(r['score']), feedback: asString(r['feedback']));
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) => SessionRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
