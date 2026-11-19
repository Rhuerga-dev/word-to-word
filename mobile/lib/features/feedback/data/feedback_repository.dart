import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';

/// Tipos de sugerencia (la misma lista fija que valida el servidor).
enum SuggestionType { idea, bug, other }

/// Envía las sugerencias del alumno al servidor (`POST /suggestions`).
/// La versión de la app, la plataforma y la pantalla se añaden solas: el alumno solo escribe.
/// Quién la envía lo sabe el servidor por la sesión; aquí nunca se manda el usuario.
class FeedbackRepository {
  FeedbackRepository(this._api, {String? platform}) : _platform = platform;
  final Api _api;
  final String? _platform;

  String get platform => _platform ?? (Platform.isIOS ? 'ios' : 'android');

  Future<void> send({required SuggestionType type, required String message, required String screen}) => _api.post('/suggestions', {
        'type': type.name,
        'message': message.trim(),
        'app_version': appVersion,
        'platform': platform,
        'screen': screen,
      });
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) => FeedbackRepository(ref.watch(apiProvider)));
