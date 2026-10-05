import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Personal, provider-neutral pairing for an AI Remote backend.
///
/// The pairing code is sent only once over HTTPS. The resulting short-lived
/// bearer token is kept in platform secure storage; neither the pairing code
/// nor an OpenAI secret is stored in the app.
class PairingIdentityService {
  PairingIdentityService({
    required this.backendUri,
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client();

  final Uri backendUri;
  final FlutterSecureStorage _storage;
  final http.Client _client;

  static const _tokenKey = 'ai_remote_pairing_access_token';
  static const _expiresAtKey = 'ai_remote_pairing_expires_at';

  String? _accessToken;
  DateTime? _expiresAt;

  bool get isSignedIn {
    final expiry = _expiresAt;
    return _accessToken != null &&
        _accessToken!.isNotEmpty &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)));
  }

  Future<String?> get currentAccessToken async {
    if (isSignedIn) return _accessToken;
    final token = await _storage.read(key: _tokenKey);
    final expiresAtRaw = await _storage.read(key: _expiresAtKey);
    final expiresAt = expiresAtRaw == null
        ? null
        : DateTime.tryParse(expiresAtRaw);
    if (token == null ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      await signOut();
      return null;
    }
    _accessToken = token;
    _expiresAt = expiresAt;
    return token;
  }

  Future<void> pair(String pairingCode) async {
    final code = pairingCode.trim();
    if (code.isEmpty) {
      throw const FormatException('Inserisci il codice di abbinamento.');
    }
    final response = await _client.post(
      backendUri.resolve('/v1/auth/pair'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(<String, String>{'pairingCode': code}),
    );
    Map<String, dynamic> body = <String, dynamic>{};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      // The caller gets a stable error below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body['error'] is String
            ? body['error'] as String
            : 'Codice di abbinamento rifiutato dal backend.',
      );
    }
    final token = body['accessToken'];
    final expiresAtRaw = body['expiresAt'];
    if (token is! String || token.isEmpty) {
      throw StateError('Risposta di abbinamento non valida.');
    }
    final expiresAt = _parseExpiry(expiresAtRaw);
    if (expiresAt == null) {
      throw StateError('Scadenza token non valida.');
    }
    _accessToken = token;
    _expiresAt = expiresAt;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _expiresAtKey,
      value: expiresAt.toIso8601String(),
    );
  }

  Future<void> signOut() async {
    _accessToken = null;
    _expiresAt = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }

  void dispose() => _client.close();

  static DateTime? _parseExpiry(Object? value) {
    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
