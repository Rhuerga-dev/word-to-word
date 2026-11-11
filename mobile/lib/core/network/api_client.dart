import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../../core/l10n/tr.dart';

/// Error de la API con el mensaje que da el servidor (en español).
class ApiException implements Exception {
  ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;

  /// Sin respuesta del servidor (sin internet o tiempo agotado).
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

/// Cliente de la API de Word to Word (la misma que usa la web), con Dio.
class Api {
  Api({String baseUrl = apiBaseUrl, Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              headers: {'Accept': 'application/json'},
            )) {
    // El token va en cada petición desde un solo sitio.
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }

  final Dio dio;
  String? token;

  /// Se llama cuando el servidor dice que la sesión ya no vale (401).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path) => _call(() => dio.get(path));
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _call(() => dio.post(path, data: body));
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _call(() => dio.put(path, data: body));
  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) => _call(() => dio.delete(path, data: body));

  /// Sube audio (WAV 16 kHz mono) con campos extra; [onProgress] va de 0 a 1.
  Future<dynamic> upload(String path, Uint8List wav, {Map<String, String> fields = const {}, void Function(double)? onProgress}) =>
      _call(() => dio.post(path,
          data: FormData.fromMap({...fields, 'audio': MultipartFile.fromBytes(wav, filename: 'voz.wav')}),
          onSendProgress: onProgress == null ? null : (s, t) => t > 0 ? onProgress(s / t) : null));

  /// Audio de la voz natural (mp3).
  Future<Uint8List> tts(String text, {String lang = 'en', bool slow = false}) async {
    final r = await _call(() => dio.get<List<int>>('/tts',
        queryParameters: {'text': text, 'lang': lang, 'slow': slow ? '1' : '0'},
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': 'audio/mpeg'})));
    return Uint8List.fromList(r as List<int>);
  }

  Future<dynamic> _call(Future<Response> Function() send) async {
    try {
      return (await send()).data;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401) {
        onUnauthorized?.call();
        throw ApiException(tr('Tu sesión expiró. Entra otra vez.'), 401);
      }
      if (e.response != null) throw ApiException(errorMessage(e.response!.data, status), status);
      throw ApiException(switch (e.type) {
        DioExceptionType.connectionTimeout || DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout => tr('El servidor tardó demasiado. Prueba otra vez.'),
        _ => tr('Sin conexión. Revisa tu internet.'),
      });
    }
  }

  /// El primer error de validación, o el mensaje, o "Error 500".
  static String errorMessage(dynamic data, int status) {
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) return data['message'] as String;
    }
    return 'Error $status';
  }
}

/// El cliente del API, uno para toda la app.
final apiProvider = Provider<Api>((ref) => Api());
