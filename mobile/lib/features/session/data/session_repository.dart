import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
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
      return EarResult(xp: asInt(r['xp_gained']), fast: asBool(r['fast']), automatic: asBool(r['automatic']));
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _cache.enqueue('/words/$wordId/ear', body);
      return EarResult(fast: ok && ms <= 3000);
    }
  }

  /// Puntuación (0–100) del sonido [phoneme] al decir [word].
  Future<int> assess(String word, String phoneme, Uint8List wav) async {
    final r = asMap(await _api.upload('/pronunciation/assess', wav, fields: {'text': word, 'phoneme': phoneme}));
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
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) => SessionRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
