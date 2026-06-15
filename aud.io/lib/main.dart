import 'dart:developer' as dev;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/theme/app_theme.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/music_library.dart';
import 'package:aud_io/services/download_service.dart';
import 'package:aud_io/services/settings_service.dart';
import 'package:aud_io/services/local_file_scanner.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/services/youtube_music_service.dart';
import 'package:aud_io/services/spotify_auth_service.dart';
import 'package:aud_io/pages/home_page.dart';
import 'package:aud_io/pages/profile_page.dart';
import 'package:aud_io/pages/now_playing_page.dart';
import 'package:aud_io/pages/settings_page.dart';
import 'package:aud_io/pages/podcast_page.dart';
import 'package:aud_io/widgets/mini_player.dart';
import 'package:aud_io/widgets/golden_spiral_nav.dart';
import 'package:aud_io/widgets/loading_bar.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.js_interop) 'dart:js_interop';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive for local persistence
  await Hive.initFlutter();

  // Init YouTube Music API
  await YouTubeMusicService.initialize();

  // Pipe logging from youtube_explode_dart etc. to debug console.
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((r) {
    dev.log(r.message, time: r.time, level: r.level.value, name: r.loggerName);
  });

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}');
  };

  AppAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => AppAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.aud.aud_io.channel.audio',
        androidNotificationChannelName: 'aud.io playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('aud.io: AudioService.init failed, falling back to in-app playback: $e');
    audioHandler = AppAudioHandler();
  }

  runApp(AudIoApp(audioHandler: audioHandler));
}

class AudIoApp extends StatefulWidget {
  final AppAudioHandler audioHandler;
  const AudIoApp({super.key, required this.audioHandler});

  @override
  State<AudIoApp> createState() => _AudIoAppState();
}

class _AudIoAppState extends State<AudIoApp> {
  @override
  Widget build(BuildContext context) {
    return _ProviderScope(
      audioHandler: widget.audioHandler,
      child: const _AppView(),
    );
  }
}

class _ProviderScope extends StatefulWidget {
  final AppAudioHandler audioHandler;
  final Widget child;
  const _ProviderScope({required this.audioHandler, required this.child});

  @override
  State<_ProviderScope> createState() => _ProviderScopeState();
}

class _ProviderScopeState extends State<_ProviderScope> {
  late final MusicLibrary _musicLibrary;
  late final DownloadService _downloadService;
  late final SettingsService _settingsService;
  late final LocalFileScanner _localFileScanner;
  late final LocalPlaylistService _playlistService;
  late final SpotifyAuthService _spotifyAuthService;

  @override
  void initState() {
    super.initState();
    _musicLibrary = MusicLibrary();
    _downloadService = DownloadService();
    _downloadService.init();
    _settingsService = SettingsService();
    _settingsService.initSync();
    _localFileScanner = LocalFileScanner();
    _playlistService = LocalPlaylistService();
    _playlistService.load();
    _spotifyAuthService = SpotifyAuthService.instance;
    _spotifyAuthService.init();
  }

  @override
  void dispose() {
    _musicLibrary.dispose();
    _settingsService.dispose();
    _localFileScanner.dispose();
    _playlistService.dispose();
    _spotifyAuthService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.audioHandler),
        ChangeNotifierProvider.value(value: _musicLibrary),
        ChangeNotifierProvider.value(value: _downloadService),
        ChangeNotifierProvider.value(value: _settingsService),
        ChangeNotifierProvider.value(value: _localFileScanner),
        ChangeNotifierProvider.value(value: _playlistService),
        ChangeNotifierProvider.value(value: _spotifyAuthService),
      ],
      child: widget.child,
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final isDark = !settings.lightMode;
        AudIoTheme.setDarkMode(isDark);
        return MaterialApp(
          title: 'aud.io',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.lightMode ? ThemeMode.light : ThemeMode.dark,
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppAudioHandler _audioHandler;
  late final DownloadService _downloadService;
  int _currentTab = 0;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _audioHandler = context.read<AppAudioHandler>();
    _downloadService = context.read<DownloadService>();
    _downloadService.setNotificationCallback(_handleDownloadNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MusicLibrary>().init();
        _handleSpotifyCallback();
      }
    });
  }

  void _handleSpotifyCallback() {
    if (!mounted) return;
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      context.read<SpotifyAuthService>().exchangeCode(code);
      // Clear the URL parameters
      if (uri.queryParameters.containsKey('code')) {
        final cleanUri = uri.replace(queryParameters: {});
        html.window.history.replaceState(null, '', cleanUri.toString());
      }
    }
  }

  void _handleDownloadNotification(DownloadNotification notification) {
    if (!mounted) return;
    if (notification.type == DownloadNotificationType.completed || 
        notification.type == DownloadNotificationType.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.title),
          duration: const Duration(seconds: 3),
          backgroundColor: notification.type == DownloadNotificationType.completed
              ? Colors.green
              : Colors.red,
        ),
      );
    }
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: _audioHandler, child: const NowPlayingPage()),
      ),
    );
  }

  void _onTabTap(int index) {
    setState(() => _currentTab = index);
  }

  void _handleBack() {
    if (_currentTab != 0) {
      setState(() => _currentTab = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider.value(
      value: _audioHandler,
      child: Consumer<MusicLibrary>(
        builder: (context, musicLib, _) {
          if (!musicLib.isLoaded) {
            return Stack(
              children: [
                Scaffold(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  body: const SizedBox.expand(),
                ),
                LoadingOverlay(
                  progress: musicLib.loadProgress,
                  status: musicLib.loadStatus,
                ),
              ],
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _handleBack();
            },
            child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GoldenSpiralNav(
                      activeIndex: _currentTab,
                      onChanged: _onTabTap,
                      sections: [
                         GoldenSection(
                            label: 'DISCOVER',
                            icon: Icons.home_rounded,
                            panelColor: AudIoTheme.red,
                            panelForeground: AudIoTheme.ink,
                            page: HomePage(
                              onNavigateToLibrary: () => _onTabTap(2),
                              onNavigateToPodcasts: () => _onTabTap(1),
                            ),
                          ),
                         const GoldenSection(
                            label: 'PODCASTS',
                            icon: Icons.podcasts_rounded,
                            panelColor: AudIoTheme.cream,
                            panelForeground: AudIoTheme.ink,
                            page: PodcastPage(),
                          ),
                         GoldenSection(
                           label: 'LIBRARY',
                           icon: Icons.library_music_rounded,
                           panelColor: AudIoTheme.red,
                           panelForeground: AudIoTheme.cream,
                           page: const ProfilePage(),
                         ),
                        const GoldenSection(
                          label: 'SETTINGS',
                          icon: Icons.settings_rounded,
                          panelColor: AudIoTheme.cream,
                          panelForeground: AudIoTheme.red,
                          page: SettingsPage(),
                        ),
                      ],
                    ),
                  ),
                  Consumer<AppAudioHandler>(
                    builder: (context, handler, _) {
                      final track = handler.currentTrack;
                      if (track == null) return const SizedBox.shrink();
                      return MiniPlayer(track: track, audioHandler: handler, onTap: _openNowPlaying);
                    },
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}
