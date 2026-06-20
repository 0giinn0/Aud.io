import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Account', style: TextStyle(
            fontSize: 22, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Sign in to sync your library across devices', style: TextStyle(
            fontSize: 11, color: AudIoTheme.subtle)),
          const SizedBox(height: 24),
          const _AccountCard(),
          const SizedBox(height: 24),
          _SectionHeader('SYNC'),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.sync_rounded,
            title: 'Auto-sync',
            subtitle: 'Playlists, likes, and history stay in sync across all your devices.',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.history_rounded,
            title: 'Listening history',
            subtitle: 'Your play history is saved privately — no ads, no tracking.',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.lock_rounded,
            title: 'Private by default',
            subtitle: 'Account data is stored locally. Cloud sync is opt-in.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(
      fontSize: 12, color: AudIoTheme.muted,
      fontWeight: FontWeight.w600, letterSpacing: 1.5));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AudIoTheme.subtle),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 12, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(
                  fontSize: 10, color: AudIoTheme.subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AudIoTheme.primary.withValues(alpha: 0.15), AudIoTheme.surface],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AudIoTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 22, color: AudIoTheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: TextStyle(
                        fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                      Text(_userEmail, style: TextStyle(
                        fontSize: 11, color: AudIoTheme.subtle)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() {
                _isLoggedIn = false;
                _userName = '';
                _userEmail = '';
              }),
              child: Container(
                width: double.infinity,
                height: 36,
                decoration: BoxDecoration(
                  color: AudIoTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('Sign Out', style: TextStyle(
                    fontSize: 12, color: AudIoTheme.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 20, color: AudIoTheme.primary),
              const SizedBox(width: 10),
              Text('Sign in to sync', style: TextStyle(
                fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Save playlists, likes, and history across devices', style: TextStyle(
            fontSize: 10, color: AudIoTheme.subtle)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() {
              _isLoggedIn = true;
              _userName = _nameController.text.isNotEmpty ? _nameController.text : 'User';
              _userEmail = _emailController.text.isNotEmpty ? _emailController.text : 'user@email.com';
            }),
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: AudIoTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('Sign In', style: TextStyle(
                  fontSize: 13, color: AudIoTheme.onBg, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 1, color: AudIoTheme.surfaceVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: TextStyle(fontSize: 10, color: AudIoTheme.subtle)),
            ),
            Expanded(child: Container(height: 1, color: AudIoTheme.surfaceVariant)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLoggedIn = true;
                  _userName = 'Google User';
                  _userEmail = 'user@gmail.com';
                }),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AudIoTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.g_mobiledata_rounded, size: 18, color: AudIoTheme.onSurface),
                      const SizedBox(width: 6),
                      Text('Google', style: TextStyle(
                        fontSize: 12, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLoggedIn = true;
                  _userName = 'Apple User';
                  _userEmail = 'user@icloud.com';
                }),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AudIoTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.apple_rounded, size: 16, color: AudIoTheme.onSurface),
                      const SizedBox(width: 6),
                      Text('Apple', style: TextStyle(
                        fontSize: 12, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
