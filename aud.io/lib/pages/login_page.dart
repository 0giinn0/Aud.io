import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final auth = context.read<AuthService>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in all fields');
      return;
    }

    String? err;
    if (_isSignUp) {
      err = await auth.signUp(email, pass, username: _userCtrl.text.trim());
    } else {
      err = await auth.signIn(email, pass);
    }
    if (mounted && err != null) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('aud.io', style: TextStyle(fontSize: 28, color: AudIoTheme.primary, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('sign in or shut up', style: TextStyle(fontSize: 10, color: AudIoTheme.muted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
                decoration: InputDecoration(labelText: 'email', labelStyle: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
                decoration: InputDecoration(labelText: 'password', labelStyle: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
                onSubmitted: (_) => _submit(),
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _userCtrl,
                  style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
                  decoration: InputDecoration(labelText: 'username', labelStyle: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(fontSize: 10, color: AudIoTheme.error)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AudIoTheme.primary,
                    foregroundColor: AudIoTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: auth.isLoading ? null : _submit,
                  child: Text(auth.isLoading ? '...' : (_isSignUp ? 'sign up' : 'sign in'),
                    style: TextStyle(fontSize: 11, letterSpacing: 2)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AudIoTheme.onSurface,
                    side: BorderSide(color: AudIoTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
                  child: Text('continue with google',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                child: Text(_isSignUp ? 'already have an account?' : 'no account? make one',
                  style: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
