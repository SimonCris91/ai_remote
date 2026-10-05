/// Provider-neutral identity contract used by the phone app.
///
/// The identity token is short-lived and is sent only to the trusted AI Remote
/// backend. Implementations must never expose provider secrets or passwords to
/// Flutter UI code.
abstract interface class AiIdentityService {
  bool get isSignedIn;
  String? get displayName;
  Future<String> signIn();
  Future<String?> get currentIdToken;
  Future<void> signOut();
}
