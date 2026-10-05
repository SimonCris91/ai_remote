import 'dart:convert';
import 'dart:io';

abstract interface class RealtimeSessionGateway {
  Future<String> createVoiceClientSecret({required String channelId});
  Future<String> createTranslationClientSecret({
    required String targetLanguage,
  });
}

typedef AccessTokenProvider = Future<String> Function();

/// Fetches short-lived Realtime client secrets from the trusted backend.
/// A standard OpenAI API key is never accepted or stored by this class.
class BackendRealtimeSessionGateway implements RealtimeSessionGateway {
  BackendRealtimeSessionGateway({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final AccessTokenProvider accessTokenProvider;
  final HttpClient _httpClient;

  @override
  Future<String> createVoiceClientSecret({required String channelId}) {
    return _postForSecret('/v1/realtime/client-secret', {
      'channelId': channelId,
    });
  }

  @override
  Future<String> createTranslationClientSecret({
    required String targetLanguage,
  }) {
    return _postForSecret('/v1/realtime/translation-client-secret', {
      'targetLanguage': targetLanguage,
    });
  }

  Future<String> _postForSecret(
    String path,
    Map<String, Object> payload,
  ) async {
    final request = await _httpClient.postUrl(baseUri.resolve(path));
    request.headers
      ..contentType = ContentType.json
      ..set(
        HttpHeaders.authorizationHeader,
        'Bearer ${await accessTokenProvider()}',
      );
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Backend Realtime non disponibile (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['value'] is! String) {
      throw const FormatException('Risposta backend Realtime non valida.');
    }
    return decoded['value'] as String;
  }
}
