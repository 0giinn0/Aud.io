import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/artist.dart';
import 'package:aud_io/services/api_service.dart';
import 'package:aud_io/services/settings_service.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<Artist> _searchResults = [];
  List<Artist> _trendingArtists = [];
  bool _isSearching = false;
  bool _isLoadingTrending = true;
  Artist? _selectedArtist;

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
    final artists = await ApiService.getTrendingArtists(maxResults: 12);
    if (mounted) {
      setState(() {
        _trendingArtists = artists;
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _isSearching = true; _selectedArtist = null; });
    _searchFocus.unfocus();

    final results = await ApiService.searchArtists(query, maxResults: 20);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _openArtistDetail(Artist artist) async {
    final info = await ApiService.getArtistInfo(artist.name);
    if (mounted) {
      setState(() => _selectedArtist = info ?? artist);
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
          if (_selectedArtist != null) _buildArtistDetail(),
          if (_selectedArtist == null) Expanded(child: _buildContent()),
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
              Text('ARTISTS', style: TextStyle(
                fontSize: 11, color: AudIoTheme.primary, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('explore & discover', style: TextStyle(
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
                  hintText: 'Search artists...',
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
                    _selectedArtist = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedArtist != null) {
      return const SizedBox.shrink();
    }

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline_rounded, size: 64, color: AudIoTheme.subtle),
            const SizedBox(height: 16),
            Text('No artists found', style: TextStyle(color: AudIoTheme.subtle, fontSize: 14)),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isNotEmpty && _searchResults.isNotEmpty) {
      return _buildSearchResultsList();
    }

    // Trending artists
    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildTrendingArtists();
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) => _buildArtistCard(_searchResults[i]),
    );
  }

  Widget _buildTrendingArtists() {
    if (_trendingArtists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 64, color: AudIoTheme.subtle),
            const SizedBox(height: 16),
            Text('No trending artists available', style: TextStyle(color: AudIoTheme.subtle)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending Now', style: TextStyle(
            fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(_trendingArtists.length, (i) => _buildArtistCard(_trendingArtists[i])),
        ],
      ),
    );
  }

  Widget _buildArtistCard(Artist artist) {
    return GestureDetector(
      onTap: () => _openArtistDetail(artist),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artist image
            if (artist.image != null && artist.image!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  artist.image!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildArtistPlaceholder(),
                ),
              )
            else
              _buildArtistPlaceholder(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artist.name, style: TextStyle(
                    fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (artist.genre != null && artist.genre!.isNotEmpty)
                    Text(artist.genre!, style: TextStyle(
                      fontSize: 11, color: AudIoTheme.subtle),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (artist.listeners > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${artist.listenersDisplay} listeners', style: TextStyle(
                        fontSize: 10, color: AudIoTheme.subtle)),
                    ),
                ],
              ),
            ),
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: artist.source == ArtistSource.itunes
                    ? const Color(0xFFFF2D55).withOpacity(0.2)
                    : const Color(0xFFD51007).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                artist.sourceLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: artist.source == ArtistSource.itunes
                      ? const Color(0xFFFF2D55)
                      : const Color(0xFFD51007),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AudIoTheme.subtle.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.person_rounded, color: AudIoTheme.subtle, size: 30),
    );
  }

  Widget _buildArtistDetail() {
    if (_selectedArtist == null) return const SizedBox.shrink();

    final artist = _selectedArtist!;
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => setState(() => _selectedArtist = null),
              child: Icon(Icons.close_rounded, color: AudIoTheme.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          // Artist image
          if (artist.image != null && artist.image!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                artist.image!,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AudIoTheme.subtle.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(Icons.person_rounded, color: AudIoTheme.subtle, size: 80),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Artist name
          Text(artist.name, style: TextStyle(
            fontSize: 22, color: AudIoTheme.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: artist.source == ArtistSource.itunes
                  ? const Color(0xFFFF2D55).withOpacity(0.2)
                  : const Color(0xFFD51007).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              artist.sourceLabel,
              style: TextStyle(
                fontSize: 11,
                color: artist.source == ArtistSource.itunes
                    ? const Color(0xFFFF2D55)
                    : const Color(0xFFD51007),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Genre
          if (artist.genre != null && artist.genre!.isNotEmpty) ...[
            Text('Genre', style: TextStyle(
              fontSize: 12, color: AudIoTheme.subtle, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(artist.genre!, style: TextStyle(
              fontSize: 13, color: AudIoTheme.onSurface)),
            const SizedBox(height: 16),
          ],
          // Bio
          if (artist.bio != null && artist.bio!.isNotEmpty) ...[
            Text('About', style: TextStyle(
              fontSize: 12, color: AudIoTheme.subtle, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(artist.bio!, style: TextStyle(
              fontSize: 13, color: AudIoTheme.onSurface, height: 1.5)),
            const SizedBox(height: 16),
          ],
          // Stats
          if (artist.listeners > 0 || artist.playcount > 0)
            Row(
              children: [
                if (artist.listeners > 0)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Listeners', style: TextStyle(
                          fontSize: 11, color: AudIoTheme.subtle, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(artist.listenersDisplay, style: TextStyle(
                          fontSize: 15, color: AudIoTheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (artist.playcount > 0)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plays', style: TextStyle(
                          fontSize: 11, color: AudIoTheme.subtle, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(artist.playcountDisplay, style: TextStyle(
                          fontSize: 15, color: AudIoTheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          // Visit link
          if (artist.link != null && artist.link!.isNotEmpty)
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AudIoTheme.primary, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('Visit on ${artist.sourceLabel}', style: TextStyle(
                    fontSize: 13, color: AudIoTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
