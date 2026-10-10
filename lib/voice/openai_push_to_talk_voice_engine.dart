import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/voice/voice_engine.dart';

typedef AccessTokenProvider = Future<String?> Function();

/// Push-to-talk transport for the authenticated AI Remote backend.
///
/// The OpenAI key stays on the backend. The phone sends a short-lived user
/// access token and a bounded WAV recording; it never calls OpenAI directly.
class OpenAiPushToTalkVoiceEngine implements VoiceEngine {
  OpenAiPushToTalkVoiceEngine({
    required this.backendUri,
    required this.accessTokenProvider,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri backendUri;
  final AccessTokenProvider accessTokenProvider;
  final HttpClient _httpClient;
  HttpClientRequest? _activeRequest;

  @override
  bool get supportsContinuousMode => false;

  @override
  Future<VoiceTurnResult> processPushToTalkTurn(
    VoiceTurnRequest request,
  ) async {
    if (request.audio.pcm16.isEmpty) {
      throw const SocketException('La registrazione non contiene audio.');
    }
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const HttpException('Accesso al backend non configurato.');
    }

    final wav = _wrapPcm16AsWav(request.audio.pcm16);
    final endpoint = backendUri.resolve('/v1/voice/turn');
    final httpRequest = await _httpClient.postUrl(endpoint);
    _activeRequest = httpRequest;
    httpRequest.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..contentType = ContentType.json;
    httpRequest.write(
      jsonEncode(<String, Object?>{
        'channelId': request.channel.id,
        'channelInstructions': request.channel.instructions,
        'backend': request.backendTarget.name,
        if (request.codexThreadId != null)
          'codexThreadId': request.codexThreadId,
        'audioWavBase64': base64Encode(wav),
        'history': request.history
            .take(40)
            .map(
              (message) => <String, String>{
                'role': message.role == ConversationRole.user
                    ? 'user'
                    : 'assistant',
                'content': message.content,
              },
            )
            .toList(growable: false),
      }),
    );

    final response = await httpRequest.close();
    _activeRequest = null;
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Il servizio vocale non è disponibile.';
      try {
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        if (decoded['error'] is String) message = decoded['error'] as String;
      } on FormatException {
        // Return a generic error rather than exposing backend internals.
      }
      throw HttpException(message, uri: endpoint);
    }

    final result = jsonDecode(text) as Map<String, dynamic>;
    return VoiceTurnResult(
      transcript: result['transcript'] as String,
      responseText: result['responseText'] as String,
      codexThreadId: result['codexThreadId'] as String?,
    );
  }

  @override
  Future<VoiceTurnResult> processTextTurn(TextTurnRequest request) async {
    final text = request.text.trim();
    if (text.isEmpty) {
      throw const HttpException('Scrivi un messaggio prima di inviarlo.');
    }
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const HttpException('Accesso al backend non configurato.');
    }

    final endpoint = backendUri.resolve('/v1/chat/turn');
    final httpRequest = await _httpClient.postUrl(endpoint);
    _activeRequest = httpRequest;
    httpRequest.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..contentType = ContentType.json;
    httpRequest.write(
      jsonEncode(<String, Object?>{
        'channelId': request.channel.id,
        'channelInstructions': request.channel.instructions,
        'backend': request.backendTarget.name,
        'text': text,
        if (request.codexThreadId != null)
          'codexThreadId': request.codexThreadId,
        if (request.translationDirection case final direction?)
          'translationDirection': <String, String>{
            'sourceCode': direction.sourceCode,
            'targetCode': direction.targetCode,
          },
        'history': request.history
            .take(40)
            .map(
              (message) => <String, String>{
                'role': message.role == ConversationRole.user
                    ? 'user'
                    : 'assistant',
                'content': message.content,
              },
            )
            .toList(growable: false),
      }),
    );

    final response = await httpRequest.close();
    _activeRequest = null;
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(responseBody, endpoint);
    }
    final result = jsonDecode(responseBody) as Map<String, dynamic>;
    return VoiceTurnResult(
      transcript: text,
      responseText: result['responseText'] as String,
      codexThreadId: result['codexThreadId'] as String?,
    );
  }

  HttpException _httpError(String responseBody, Uri endpoint) {
    var message = 'Il servizio vocale non è disponibile.';
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      if (decoded['error'] is String) message = decoded['error'] as String;
    } on FormatException {
      // Keep the message generic rather than exposing backend internals.
    }
    return HttpException(message, uri: endpoint);
  }

  static Uint8List _wrapPcm16AsWav(Uint8List pcm) {
    const sampleRate = 24000;
    const channels = 1;
    const bitsPerSample = 16;
    final bytesPerSecond = sampleRate * channels * bitsPerSample ~/ 8;
    final data = ByteData(44 + pcm.length);
    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        data.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + pcm.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, bytesPerSecond, Endian.little);
    data.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, pcm.length, Endian.little);
    for (var index = 0; index < pcm.length; index++) {
      data.setUint8(44 + index, pcm[index]);
    }
    return data.buffer.asUint8List();
  }

  @override
  Future<void> cancel() async {
    _activeRequest?.abort();
    _activeRequest = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _httpClient.close(force: true);
  }
}
