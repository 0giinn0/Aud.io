import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/theme/witty_strings.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/music_library.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/pages/now_playing_page.dart';
import 'package:aud_io/widgets/track_context_sheet.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToLibrary;
  final VoidCallback? onNavigateToExplore;
  final VoidCallback? onNavigateToPodcasts;

  const HomePage({super.key, this.onNavigateToLibrary, this.onNavigateToExplore, this.onNavigateToPodcasts});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Track> _searchResults = [];
  bool _hasSearched = false;
  final _focusNode = FocusNode();

  static const List<Map<String, dynamic>> _genres = [
    {'name': 'Lo-Fi', 'icon': Icons.piano_rounded, 'color': Color(0xFF6366F1)},
    {'name': 'Hip Hop', 'icon': Icons.mic_rounded, 'color': Color(0xFFE94560)},
    {'name': 'Electronic', 'icon': Icons.headphones_rounded, 'color': Color(0xFF06D6A0)},
    {'name': 'Rock', 'icon': Icons.music_note_rounded, 'color': Color(0xFFFFD166)},
    {'name': 'Jazz', 'icon': Icons.music_note_rounded, 'color': Color(0xFF118AB2)},
    {'name': 'Pop', 'icon': Icons.star_rounded, 'color': Color(0xFFF72585)},
    {'name': 'Classical', 'icon': Icons.library_music_rounded, 'color': Color(0xFF8B5CF6)},
    {'name': 'Ambient', 'icon': Icons.cloud_rounded, 'color': Color(0xFF06B6D4)},
  ];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    _focusNode.unfocus();

    final lib = context.read<MusicLibrary>();
    final results = await lib.searchAll(query.trim());

    setState(() {
      _searchResults = results;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  void _playAll(List<Track> tracks, {int? startIndex}) {
    final handler = context.read<AppAudioHandler>();
    handler.setQueue(tracks, startIndex: startIndex ?? 0);
  }

  void _openNowPlaying() {
    final handler = context.read<AppAudioHandler>();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Provider.value(value: handler, child: const NowPlayingPage()),
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildSearchBar()),
        if (_isSearching)
          SliverToBoxAdapter(child: _buildLoading())
        else if (_hasSearched && _searchResults.isNotEmpty)
          SliverToBoxAdapter(child: _buildSearchResults())
        else if (_hasSearched && _searchResults.isEmpty)
          SliverToBoxAdapter(child: _buildEmpty())
        else
          SliverToBoxAdapter(child: _buildBentoGrid()),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('aud.io', style: TextStyle(
                fontSize: 28, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('your music, your way', style: TextStyle(
                fontSize: 11, color: AudIoTheme.subtle)),
            ],
          ),
          const Spacer(),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AudIoTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_none_rounded, size: 20, color: AudIoTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: 13, color: AudIoTheme.onSurface),
        decoration: InputDecoration(
          hintText: 'What do you want to listen to?',
          hintStyle: TextStyle(fontSize: 12, color: AudIoTheme.subtle),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AudIoTheme.subtle),
          prefixIconConstraints: BoxConstraints(minWidth: 44),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() { _hasSearched = false; _searchResults = []; });
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: AudIoTheme.subtle),
                )
              : null,
          filled: true,
          fillColor: AudIoTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          SizedBox(width: 32, height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: AudIoTheme.primary)),
          const SizedBox(height: 16),
          Text('searching...', style: TextStyle(
            fontSize: 11, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AudIoTheme.subtle),
          const SizedBox(height: 16),
          Text('no results found', style: TextStyle(
            fontSize: 12, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_searchResults.length} results', style: TextStyle(
                fontSize: 11, color: AudIoTheme.muted)),
              const Spacer(),
              GestureDetector(
                onTap: () => _playAll(_searchResults),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AudIoTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 16, color: AudIoTheme.onBg),
                      const SizedBox(width: 4),
                      Text('PLAY ALL', style: TextStyle(
                        fontSize: 10, color: AudIoTheme.onBg, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() { _hasSearched = false; _searchResults = []; }),
                child: Icon(Icons.close_rounded, size: 20, color: AudIoTheme.subtle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_searchResults.length, (i) => _buildResultTile(_searchResults[i], i)),
        ],
      ),
    );
  }

  Widget _buildResultTile(Track track, int index) {
    return GestureDetector(
      onTap: () => _playAll(_searchResults, startIndex: index),
      onLongPress: () => showTrackContextMenu(context, track),
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
              child: Container(
                width: 48, height: 48,
                color: AudIoTheme.surfaceVariant,
                child: track.thumbnailUrl != null
                    ? Image.network(track.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.music_note_rounded, size: 22, color: AudIoTheme.subtle))
                    : Icon(Icons.music_note_rounded, size: 22, color: AudIoTheme.subtle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getSourceColor(track.source).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(track.sourceShort, style: TextStyle(
                          fontSize: 7, color: _getSourceColor(track.source),
                          fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(track.title, style: TextStyle(
                          fontSize: 12, color: AudIoTheme.onSurface, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(track.artistDisplay, style: TextStyle(
                    fontSize: 10, color: AudIoTheme.subtle),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline_rounded, size: 24, color: AudIoTheme.muted),
          ],
        ),
      ),
    );
  }

  Color _getSourceColor(TrackSource source) {
    switch (source) {
      case TrackSource.youtube:
        return const Color(0xFFFF0000);
      case TrackSource.soundcloud:
        return const Color(0xFFFF5500);
      case TrackSource.fma:
        return const Color(0xFF00A651);
      case TrackSource.local:
        return const Color(0xFF6366F1);
      case TrackSource.fake:
        return AudIoTheme.subtle;
      case TrackSource.podcast:
        return const Color(0xFF9C27B0);
    }
  }

  // â”€â”€â”€ BENTO GRID â”€â”€â”€

  Widget _buildBentoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Now Playing (large) + Quick Play (small)
          Row(
            children: [
              Expanded(flex: 3, child: _buildNowPlayingCard()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildQuickPlayCard()),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Genre chips
          _buildGenreGrid(),
          const SizedBox(height: 12),

          // Row 3: Recently Played (wide) + Favorites (small)
          Row(
            children: [
              Expanded(flex: 3, child: _buildRecentlyPlayedCard()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildFavoritesCard()),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Podcasts + Stats
          Row(
            children: [
              Expanded(flex: 2, child: _buildPodcastsCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Playlists', '0', Icons.queue_music_rounded, onTap: widget.onNavigateToLibrary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Downloads', '0', Icons.download_rounded, onTap: widget.onNavigateToLibrary)),
            ],
          ),
          const SizedBox(height: 12),

          // Row 5: Explore CTA
          _buildExploreCard(),
        ],
      ),
    );
  }

  Widget _buildNowPlayingCard() {
    return Consumer<AppAudioHandler>(
      builder: (context, handler, _) {
        final track = handler.currentTrack;
        return GestureDetector(
          onTap: track != null ? _openNowPlaying : null,
          child: Container(
            height: 180,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AudIoTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('NOW PLAYING', style: TextStyle(
                    fontSize: 8, color: AudIoTheme.primary, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
                const Spacer(),
                if (track != null) ...[
                  if (track.thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(track.thumbnailUrl!, width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56, height: 56, color: AudIoTheme.surfaceVariant,
                          child: Icon(Icons.music_note_rounded, size: 24, color: AudIoTheme.subtle))),
                    )
                  else
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.music_note_rounded, size: 24, color: AudIoTheme.subtle),
                    ),
                  const SizedBox(height: 12),
                  Text(track.title, style: TextStyle(
                    fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(track.artistDisplay, style: TextStyle(
                    fontSize: 11, color: AudIoTheme.muted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ] else ...[
                  Icon(Icons.music_note_rounded, size: 40, color: AudIoTheme.subtle),
                  const SizedBox(height: 12),
                  Text('Nothing playing', style: TextStyle(
                    fontSize: 12, color: AudIoTheme.muted)),
                  const SizedBox(height: 4),
                  Text('Search to start', style: TextStyle(
                    fontSize: 10, color: AudIoTheme.subtle)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickPlayCard() {
    return GestureDetector(
      onTap: widget.onNavigateToLibrary,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.queue_music_rounded, size: 24, color: AudIoTheme.primary),
            const Spacer(),
            Text('Quick', style: TextStyle(
              fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            Text('Play', style: TextStyle(
              fontSize: 16, color: AudIoTheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Your library', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    // Golden ratio bento grid: pairs of big (61.8%) + small (38.2%) tiles
    return Column(
      children: List.generate((_genres.length / 2).ceil(), (rowIndex) {
        final firstIdx = rowIndex * 2;
        final secondIdx = firstIdx + 1;
        final firstGenre = _genres[firstIdx];
        final secondGenre = secondIdx < _genres.length ? _genres[secondIdx] : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Big tile (61.8% of space)
              Expanded(
                flex: 618,
                child: _buildGenreTile(firstGenre, isBig: true),
              ),
              const SizedBox(width: 12),
              // Small tile (38.2% of space) - or spacer if no second genre
              Expanded(
                flex: 382,
                child: secondGenre != null
                    ? _buildGenreTile(secondGenre, isBig: false)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildGenreTile(Map<String, dynamic> genre, {required bool isBig}) {
    final color = genre['color'] as Color;
    final icon = genre['icon'] as IconData;
    final name = genre['name'] as String;

    return GestureDetector(
      onTap: () {
        _searchController.text = name;
        _search(name);
      },
      child: Container(
        height: isBig ? 120 : 96,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withAlpha(60),
              color.withAlpha(20),
              AudIoTheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isBig ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toUpperCase(), style: TextStyle(
                  fontSize: isBig ? 13 : 11,
                  color: AudIoTheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
                const SizedBox(height: 2),
                Text('Browse ${name.toLowerCase()}', style: TextStyle(
                  fontSize: 9,
                  color: AudIoTheme.subtle,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedCard() {
    return GestureDetector(
      onTap: () {
        // Search for popular/trending music
        _searchController.text = 'trending music';
        _search('trending music');
      },
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: AudIoTheme.muted),
                const SizedBox(width: 6),
                Text('Trending Now', style: TextStyle(
                  fontSize: 11, color: AudIoTheme.muted, fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Text(WittyStrings.randomFrom(WittyStrings.emptyLibrary), style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesCard() {
    return GestureDetector(
      onTap: widget.onNavigateToLibrary,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.error.withValues(alpha: 0.15),
              AudIoTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite_rounded, size: 20, color: AudIoTheme.error),
            const Spacer(),
            Text('Favorites', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('View all', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastsCard() {
    return GestureDetector(
      onTap: widget.onNavigateToPodcasts,
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.primary.withValues(alpha: 0.15),
              AudIoTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.podcasts_rounded, size: 16, color: AudIoTheme.primary),
            const Spacer(),
            Text('Podcasts', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
              fontSize: 14, height: 1.1, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Discover & listen', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
              fontSize: 9, height: 1.1, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(
                fontSize: 20, height: 1.0, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
              fontSize: 9, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreCard() {
    return GestureDetector(
      onTap: widget.onNavigateToExplore,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.primary.withValues(alpha: 0.2),
              AudIoTheme.primary.withValues(alpha: 0.05),
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
                  Text('Explore More', style: TextStyle(
                    fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Discover new music and artists', style: TextStyle(
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
      ),
    );
  }
}
