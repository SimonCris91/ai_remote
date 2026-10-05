import 'package:google_sign_in/google_sign_in.dart';
import 'package:ai_remote/services/ai_identity_service.dart';

/// Signs in the user and exposes only Google's short-lived ID token to the
/// trusted AI Remote backend. No Google password or OpenAI key is persisted.
class GoogleIdentityService implements AiIdentityService {
  GoogleIdentityService({required this.serverClientId})
    : _googleSignIn = GoogleSignIn.instance {
    _initialization = _googleSignIn.initialize(serverClientId: serverClientId);
  }

  final String serverClientId;
  final GoogleSignIn _googleSignIn;
  late final Future<void> _initialization;
  GoogleSignInAccount? _account;

  @override
  bool get isSignedIn => _account != null;
  @override
  String? get displayName => _account?.displayName;

  @override
  Future<String> signIn() async {
    await _initialization;
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Accesso Google interattivo non supportato su questo dispositivo.',
      );
    }
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google non ha restituito il token per il server. Verifica la configurazione OAuth.',
      );
    }
    _account = account;
    return idToken;
  }

  @override
  Future<String?> get currentIdToken async {
    await _initialization;
    final account = _account;
    if (account == null) return null;
    final token = account.authentication.idToken;
    return token == null || token.isEmpty ? null : token;
  }

  @override
  Future<void> signOut() async {
    await _initialization;
    await _googleSignIn.signOut();
    _account = null;
  }
}
