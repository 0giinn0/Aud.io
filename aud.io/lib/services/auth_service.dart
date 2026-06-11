import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client;
  User? _user;
  bool _isLoading = false;

  AuthService(this._client) {
    _user = _client.auth.currentUser;
    _client.auth.onAuthStateChange.listen((event) {
      _user = event.session?.user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String get userId => _user?.id ?? '';

  Future<String?> signUp(String email, String password, {String? username}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _client.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'preferred_username': username} : null,
      );
      _isLoading = false;
      notifyListeners();
      return resp.session != null ? null : 'Check your email for confirmation';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return _errorMessage(e);
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return _errorMessage(e);
    }
  }

  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? 'http://localhost:8082' : null,
      );
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return _errorMessage(e);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  String _errorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) return 'Wrong email or password';
    if (msg.contains('Email not confirmed')) return 'Please confirm your email first';
    if (msg.contains('already registered')) return 'This email is already registered';
    if (msg.contains('weak_password')) return 'Password must be at least 6 characters';
    return 'Something went wrong. Try again.';
  }
}
