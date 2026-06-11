import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/services/music_library.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/pages/now_playing_page.dart';

class SocialPage extends StatefulWidget {
  final bool supabaseAvailable;
  const SocialPage({super.key, this.supabaseAvailable = false});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  bool _isSearching = false;
  List<dynamic> _trendingResults = [];

  Future<void> _searchGenre(String genre) async {
    setState(() => _isSearching = true);
    final lib = context.read<MusicLibrary>();
    final results = await lib.searchAll(genre);
    if (mounted) {
      setState(() {
        _trendingResults = results;
        _isSearching = false;
      });
    }
  }

  void _playAll(List tracks, {int? startIndex}) {
    final handler = context.read<AppAudioHandler>();
    handler.setQueue(tracks.cast(), startIndex: startIndex ?? 0);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Provider.value(value: handler, child: const NowPlayingPage()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Explore', style: TextStyle(
            fontSize: 22, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Row 1: Featured (wide) + Trending (small)
          Row(
            children: [
              Expanded(flex: 3, child: _buildFeaturedCard()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildTrendingCard()),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Quick actions
          Row(
            children: [
              Expanded(child: _buildActionCard('New Releases', Icons.new_releases_rounded, const Color(0xFF6366F1), () => _searchGenre('new music 2024'))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard('Charts', Icons.leaderboard_rounded, const Color(0xFFFFD166), () => _searchGenre('top charts hits'))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionCard('Radio', Icons.radio_rounded, const Color(0xFF06D6A0), () => _searchGenre('radio hits'))),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Genres grid
          _buildGenreSection(),
          const SizedBox(height: 12),

          // Row 4: Community
          _buildCommunityCard(),
          const SizedBox(height: 12),

          // Search results
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AudIoTheme.primary)),
              ),
            )
          else if (_trendingResults.isNotEmpty) ...[
            Row(
              children: [
                Text('Results', style: TextStyle(
                  fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _playAll(_trendingResults),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AudIoTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('PLAY ALL', style: TextStyle(
                      fontSize: 9, color: AudIoTheme.onBg, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_trendingResults.length, (i) {
              final track = _trendingResults[i];
              return GestureDetector(
                onTap: () => _playAll(_trendingResults, startIndex: i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AudIoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(width: 44, height: 44, color: AudIoTheme.surfaceVariant,
                          child: track.thumbnailUrl != null
                              ? Image.network(track.thumbnailUrl!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: 20, color: AudIoTheme.subtle))
                              : Icon(Icons.music_note_rounded, size: 20, color: AudIoTheme.subtle)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track.title, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface,
                              fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(track.artistDisplay, style: TextStyle(fontSize: 10, color: AudIoTheme.subtle), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.play_circle_outline_rounded, size: 22, color: AudIoTheme.muted),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Row 5: Stats
          if (_trendingResults.isEmpty && !_isSearching) ...[
            Row(
              children: [
                Expanded(child: _buildMiniStat('Listeners', '0', Icons.people_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _buildMiniStat('Playlists', '0', Icons.queue_music_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _buildMiniStat('Shares', '0', Icons.share_rounded)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturedCard() {
    return GestureDetector(
      onTap: () => _searchGenre('featured playlist best music'),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('FEATURED', style: TextStyle(
                fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ),
            const Spacer(),
            Text('Discover', style: TextStyle(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
            Text('Weekly Mix', style: TextStyle(
              fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingCard() {
    return GestureDetector(
      onTap: () => _searchGenre('trending songs right now'),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.primary.withValues(alpha: 0.3),
              AudIoTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.trending_up_rounded, size: 24, color: AudIoTheme.primary),
            const Spacer(),
            Text('Trending', style: TextStyle(
              fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            Text('Right now', style: TextStyle(
              fontSize: 11, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const Spacer(),
            Text(label, style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection() {
    final genres = [
      {'name': 'Lo-Fi', 'color': const Color(0xFF6366F1)},
      {'name': 'Hip Hop', 'color': const Color(0xFFE94560)},
      {'name': 'Electronic', 'color': const Color(0xFF06D6A0)},
      {'name': 'Rock', 'color': const Color(0xFFFFD166)},
      {'name': 'Jazz', 'color': const Color(0xFF118AB2)},
      {'name': 'Pop', 'color': const Color(0xFFF72585)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse by Genre', style: TextStyle(
          fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final g = genres[index];
            return GestureDetector(
              onTap: () => _searchGenre('${g['name']} music best songs'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (g['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(g['name'] as String, style: TextStyle(
                    fontSize: 11, color: g['color'] as Color, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommunityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AudIoTheme.primary.withValues(alpha: 0.12),
            AudIoTheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community', style: TextStyle(
                  fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('See what others are playing', style: TextStyle(
                  fontSize: 11, color: AudIoTheme.muted)),
              ],
            ),
          ),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AudIoTheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.arrow_forward_rounded, size: 22, color: AudIoTheme.onBg),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AudIoTheme.subtle),
          const Spacer(),
          Text(value, style: TextStyle(
            fontSize: 18, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(
            fontSize: 9, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }
}
