import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/podcast.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/download_service.dart';
import 'package:aud_io/services/settings_service.dart';
import 'package:aud_io/widgets/proxied_image.dart';

class PodcastPage extends StatefulWidget {
  const PodcastPage({super.key});

  @override
  State<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends State<PodcastPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<Podcast> _searchResults = [];
  List<Podcast> _trendingPodcasts = [];
  bool _isSearching = false;
  bool _isLoadingTrending = true;
  Podcast? _selectedPodcast;
  String? _activeGenre;

  static const List<Map<String, dynamic>> _genres = [
    {'name': 'True Crime',  'icon': Icons.policy_rounded,                    'color': Color(0xFFE94560)},
    {'name': 'Comedy',      'icon': Icons.sentiment_very_satisfied_rounded,  'color': Color(0xFFFFD166)},
    {'name': 'Technology',  'icon': Icons.memory_rounded,                    'color': Color(0xFF06D6A0)},
    {'name': 'News',        'icon': Icons.newspaper_rounded,                 'color': Color(0xFF6366F1)},
    {'name': 'Business',    'icon': Icons.trending_up_rounded,               'color': Color(0xFFFF9F1C)},
    {'name': 'Science',     'icon': Icons.biotech_rounded,                   'color': Color(0xFF118AB2)},
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoadingTrending = true);
    final podcasts = await ApiService.getTrendingPodcasts();
    if (mounted) {
      setState(() {
        _trendingPodcasts = podcasts;
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _searchGenre(String genre) async {
    setState(() {
      _activeGenre = genre;
      _isSearching = true;
      _selectedPodcast = null;
      _searchController.text = genre;
    });
    _searchFocus.unfocus();
    final results = await ApiService.searchPodcasts(genre, maxResults: 20);
    if (mounted) setState(() { _searchResults = results; _isSearching = false; });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _isSearching = true; _activeGenre = null; });
    _searchFocus.unfocus();

    final results = await ApiService.searchPodcasts(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _selectedPodcast = null;
      });
    }
  }

  Future<void> _openPodcast(Podcast podcast) async {
    setState(() => _selectedPodcast = null);
    // Use feed URL to get episodes (free endpoint, no auth needed)
    if (podcast.feedUrl != null && podcast.feedUrl!.isNotEmpty) {
      final episodes = await ApiService.getEpisodesFromFeed(podcast.feedUrl!, max: 20);
      if (mounted) {
        setState(() {
          _selectedPodcast = podcast.copyWithEpisodes(episodes);
        });
      }
    } else {
      // Fallback to API details
      final details = await ApiService.getPodcastDetails(podcast.id);
      if (mounted && details != null) {
        setState(() => _selectedPodcast = details);
      }
    }
  }

  void _playEpisode(PodcastEpisode episode) {
    final audioHandler = context.read<AppAudioHandler>();
    if (episode.audioUrl != null && episode.audioUrl!.isNotEmpty) {
      // Represent the episode as a queue Track so the mini-player and
      // now-playing screen show its title/artist like any other track.
      final track = Track(
        id: 'podcast_${episode.audioUrl.hashCode}',
        title: episode.title,
        artist: episode.artistDisplay,
        album: 'Podcast',
        thumbnailUrl: episode.thumbnailUrl,
        audioUrl: episode.audioUrl,
        duration: episode.duration > 0 ? episode.duration : 0,
        source: TrackSource.podcast,
      );
      audioHandler.setQueue([track]);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsService>();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AudIoTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildGenreChips(),
          if (_selectedPodcast != null) _buildPodcastDetail(),
          if (_selectedPodcast == null) Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PODCASTS', style: TextStyle(
                fontSize: 11, color: AudIoTheme.primary, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('discover & listen', style: TextStyle(
                fontSize: 10, color: AudIoTheme.subtle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.search_rounded, size: 20, color: Color(0xFF535353)),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: TextStyle(color: AudIoTheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search podcasts...',
                  hintStyle: TextStyle(color: AudIoTheme.subtle, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: AudIoTheme.subtle),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _selectedPodcast = null;
                    _activeGenre = null;
                  });
                  _loadTrending();
                },
              ),
            IconButton(
              icon: Icon(Icons.search, size: 18, color: AudIoTheme.primary),
              onPressed: _search,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate((_genres.length / 2).ceil(), (rowIndex) {
          final firstIdx = rowIndex * 2;
          final secondIdx = firstIdx + 1;
          final firstGenre = _genres[firstIdx];
          final secondGenre = secondIdx < _genres.length ? _genres[secondIdx] : null;
          final firstActive = _activeGenre == firstGenre['name'];
          final secondActive = secondGenre != null && _activeGenre == secondGenre['name'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 618,
                  child: _buildGenreTile(firstGenre, isActive: firstActive, isBig: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 382,
                  child: secondGenre != null
                      ? _buildGenreTile(secondGenre, isActive: secondActive, isBig: false)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGenreTile(Map<String, dynamic> genre, {required bool isActive, required bool isBig}) {
    final color = genre['color'] as Color;
    final icon = genre['icon'] as IconData;
    final name = genre['name'] as String;

    return GestureDetector(
      onTap: () => _searchGenre(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: isBig ? 90 : 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withAlpha(80), color.withAlpha(30), AudIoTheme.surface],
                  stops: const [0.0, 0.4, 1.0],
                )
              : null,
          color: isActive ? null : AudIoTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : color.withAlpha(30),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? color.withAlpha(40) : color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: isActive ? color : color.withAlpha(180)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: TextStyle(
                    fontSize: 11,
                    color: isActive ? color : AudIoTheme.onSurface,
                    fontWeight: FontWeight.w600,
                  )),
                  if (isActive)
                    Text('Showing results', style: TextStyle(
                      fontSize: 8,
                      color: color.withAlpha(180),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: AudIoTheme.primary));
    }

    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildTrendingPodcasts();
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text('${_searchResults.length} results', style: TextStyle(
                fontSize: 11, color: AudIoTheme.muted)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final podcast = _searchResults[index];
              return _buildPodcastCard(podcast);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingPodcasts() {
    if (_isLoadingTrending) {
      return Center(child: CircularProgressIndicator(color: AudIoTheme.primary));
    }

    if (_trendingPodcasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.podcasts_rounded, size: 48, color: AudIoTheme.subtle),
            const SizedBox(height: 12),
            Text('Search for podcasts', style: TextStyle(
              color: AudIoTheme.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Powered by Podcast Index', style: TextStyle(
              color: AudIoTheme.subtle, fontSize: 9)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _trendingPodcasts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('TRENDING NOW', style: TextStyle(
              fontSize: 10, color: AudIoTheme.primary, fontWeight: FontWeight.w600, letterSpacing: 2)),
          );
        }

        final podcast = _trendingPodcasts[index - 1];
        return _buildPodcastCard(podcast);
      },
    );
  }

  Widget _buildPodcastCard(Podcast podcast) {
    return GestureDetector(
      onTap: () => _openPodcast(podcast),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: podcast.thumbnailUrl != null && podcast.thumbnailUrl!.isNotEmpty
                    ? ProxiedImage(url: podcast.thumbnailUrl!, width: 64, height: 64,
                        errorBuilder: (_, __, ___) => Container(color: AudIoTheme.surfaceVariant,
                          child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 28)))
                    : Container(color: AudIoTheme.surfaceVariant,
                        child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(podcast.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AudIoTheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(podcast.authorDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AudIoTheme.muted, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('${podcast.episodeCount} episodes', style: TextStyle(
                    color: AudIoTheme.subtle, fontSize: 9)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AudIoTheme.subtle),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastDetail() {
    final podcast = _selectedPodcast!;
    return Expanded(
      child: Column(
        children: [
          // Podcast header
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AudIoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: podcast.thumbnailUrl != null && podcast.thumbnailUrl!.isNotEmpty
                    ? ProxiedImage(url: podcast.thumbnailUrl!, width: 80, height: 80,
                        errorBuilder: (_, __, ___) => Container(color: AudIoTheme.surfaceVariant,
                          child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 32)))
                        : Container(color: AudIoTheme.surfaceVariant,
                            child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 32)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(podcast.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AudIoTheme.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(podcast.authorDisplay,
                        style: TextStyle(color: AudIoTheme.muted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('${podcast.episodeCount} episodes', style: TextStyle(
                        color: AudIoTheme.subtle, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: AudIoTheme.muted),
                  onPressed: () => setState(() => _selectedPodcast = null),
                ),
              ],
            ),
          ),
          // Episodes list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: podcast.episodes.length,
              itemBuilder: (context, index) {
                final episode = podcast.episodes[index];
                return _buildEpisodeCard(episode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(PodcastEpisode episode) {
    final episodeId = 'podcast_${episode.audioUrl.hashCode}';
    return Consumer<DownloadService>(
      builder: (context, dl, _) {
        final isDownloaded = dl.isDownloaded(episodeId);
        final task = dl.tasks[episodeId];
        final isDownloading = task != null && task.status == DownloadStatus.downloading;

        return GestureDetector(
          onTap: () => _playEpisode(episode),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AudIoTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: episode.thumbnailUrl != null && (episode.thumbnailUrl ?? '').isNotEmpty
                    ? ProxiedImage(url: episode.thumbnailUrl!, width: 56, height: 56,
                        errorBuilder: (_, __, ___) => Container(color: AudIoTheme.surfaceVariant,
                          child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 24)))
                        : Container(color: AudIoTheme.surfaceVariant,
                            child: Icon(Icons.podcasts_rounded, color: AudIoTheme.subtle, size: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AudIoTheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (episode.description != null && (episode.description ?? '').isNotEmpty)
                        Text(episode.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AudIoTheme.muted, fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (episode.duration > 0) ...[
                            Icon(Icons.access_time_rounded, size: 12, color: AudIoTheme.subtle),
                            const SizedBox(width: 4),
                            Text(episode.displayDuration,
                              style: TextStyle(color: AudIoTheme.subtle, fontSize: 9)),
                            const SizedBox(width: 12),
                          ],
                          if (episode.publishDate > 0)
                            Text(episode.publishDateDisplay,
                              style: TextStyle(color: AudIoTheme.subtle, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Download button
                GestureDetector(
                  onTap: () {
                    if (!isDownloading && !isDownloaded && episode.audioUrl != null) {
                      dl.downloadPodcastEpisode(
                        episodeId,
                        episode.audioUrl!,
                        title: episode.title,
                        thumbnailUrl: episode.thumbnailUrl,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDownloaded
                          ? AudIoTheme.primary.withAlpha(30)
                          : isDownloading
                              ? Colors.orange.withAlpha(30)
                              : AudIoTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isDownloading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: task?.progress,
                              color: Colors.orange,
                            ),
                          )
                        : Icon(
                            isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                            size: 20,
                            color: isDownloaded ? AudIoTheme.primary : AudIoTheme.muted,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Play button
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AudIoTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.play_arrow_rounded, size: 20, color: AudIoTheme.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
