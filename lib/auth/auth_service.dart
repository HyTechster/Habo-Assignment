import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _sessionKey = 'supabase_session';

  User? get currentUser => _isSupabaseAvailable
      ? Supabase.instance.client.auth.currentUser
      : null;

  bool get isSignedIn => currentUser != null;

  bool get _isSupabaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  AuthService() {
    if (_isSupabaseAvailable) {
      Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        notifyListeners();
      });
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (!_isSupabaseAvailable) throw Exception('Cloud sync not configured.');
    final response = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);
    if (response.session != null) {
      await _storage.write(
          key: _sessionKey, value: response.session!.accessToken);
    }
    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (!_isSupabaseAvailable) throw Exception('Cloud sync not configured.');
    await Supabase.instance.client.auth
        .signUp(email: email, password: password);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (!_isSupabaseAvailable) throw Exception('Cloud sync not configured.');
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'habo://login-callback',
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!_isSupabaseAvailable) return;
    await Supabase.instance.client.auth.signOut();
    await _storage.delete(key: _sessionKey);
    notifyListeners();
  }
}
