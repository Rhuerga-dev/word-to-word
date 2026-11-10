import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Error de la API con el mensaje que da el servidor (en español).
class ApiException implements Exception {
  ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// Cliente de la API de Word to Word (la misma que usa la web).
class Api {
  Api({this.baseUrl = 'https://w2w.huergalabs.dev/api', http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? token;

  /// Se llama cuando el servidor dice que la sesión ya no vale (401).
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _send('PUT', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(_headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return _decode(await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 60))));
  }

  /// Sube audio (WAV 16 kHz mono) con campos extra.
  Future<dynamic> upload(String path, Uint8List wav, {Map<String, String> fields = const {}}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers)
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('audio', wav, filename: 'voz.wav'));
    return _decode(await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 60))));
  }

  /// Audio de la voz natural (mp3).
  Future<Uint8List> tts(String text, {String lang = 'en', bool slow = false}) async {
    final uri = Uri.parse('$baseUrl/tts').replace(queryParameters: {'text': text, 'lang': lang, 'slow': slow ? '1' : '0'});
    final res = await _client.get(uri, headers: {..._headers, 'Accept': 'audio/mpeg'});
    if (res.statusCode != 200) throw ApiException('tts ${res.statusCode}', res.statusCode);
    return res.bodyBytes;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Tu sesión expiró. Entra otra vez.', 401);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 400) throw ApiException(errorMessage(data, res.statusCode), res.statusCode);
    return data;
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
