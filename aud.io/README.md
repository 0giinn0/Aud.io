# aud.io

A streaming music player built with Flutter — YouTube Music, SoundCloud, podcasts, local files, Spotify import, and 7 theme presets. Bento box UI with golden spiral navigation.

## Live

- **Web**: https://aud-io-web.pages.dev
- **Server**: https://aud-io.onrender.com

## Features

- **Multi-source search** — YouTube Music (via InnerTube proxy), SoundCloud
- **Podcast streaming** — Podcast Index API (search, trending, episodes via RSS)
- **Local file scanning** — VLC-style auto-scan of device music directories, folder picker, file picker
- **Spotify import** — OAuth login, fetch playlists, one-tap import to local library
- **7 theme presets** — Ink & Red, Black & Grey, Black & Gold, Midnight Blue, Cream & Red, Pure White, Warm Sand
- **Golden spiral navigation** — 4-tab mathematical layout inspired by the golden ratio
- **Bento box UI** — Mixed-size rounded cards with gradients, Fibonacci spacing scale
- **Offline downloads** — yt-dlp powered MP3 downloads via server proxy
- **Playlists & favorites** — Local persistence with Hive
- **Transfer files** — Import from URL, export playlists (M3U/JSON), device-to-device transfer
- **Account login** — Email/password + Google/Apple social login UI

## Architecture

```
├── lib/                        # Flutter app (Dart)
│   ├── main.dart               # App entry, providers, navigation shell
│   ├── pages/                  # Home, Podcasts, Library, Settings, Now Playing
│   ├── services/               # API, audio handler, download, auth, scanner
│   ├── widgets/                # Golden spiral nav, mini player, proxied image
│   └── core/
│       ├── models/             # Track, Playlist, Podcast
│       └── theme/              # Theme presets, AppTheme, AudIoTheme
├── server/                     # Node.js API server
│   ├── src/
│   │   ├── index.js            # Express + CORS + rate limiting
│   │   ├── routes/api.js       # /api/search, /api/stream, /api/ytmusic/*, /api/spotify/*
│   │   ├── services/           # soundcloud.js, podcast.js
│   │   └── config.js           # Environment config
│   └── Dockerfile              # Render deployment
├── render.yaml                 # Render deploy config
└── .github/workflows/          # Cloudflare Pages CI/CD
```

## Quick Start

### Prerequisites
- Flutter 3.44+
- Node.js 20+

### Run Locally

**1. Start the server:**
```bash
cd server
npm install
cp .env.example .env
npm run dev
```

**2. Run Flutter:**
```bash
cd aud.io
flutter pub get
flutter run -d chrome
```

### Deploy

**Server (Render):**
- Push to GitHub → Render auto-deploys from `render.yaml`
- Set env vars: `PODCAST_INDEX_API_KEY`, `PODCAST_INDEX_API_SECRET`, `SOUNDCLOUD_CLIENT_ID`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`

**Web (Cloudflare Pages):**
- Push to `main` → GitHub Actions builds Flutter web and deploys to Cloudflare Pages
- Set repo secret: `CLOUDFLARE_API_TOKEN`

## Environment Variables

| Variable | Description |
|----------|-------------|
| `PODCAST_INDEX_API_KEY` | Podcast Index API key |
| `PODCAST_INDEX_API_SECRET` | Podcast Index API secret |
| `SOUNDCLOUD_CLIENT_ID` | SoundCloud API client ID |
| `SPOTIFY_CLIENT_ID` | Spotify app client ID |
| `SPOTIFY_CLIENT_SECRET` | Spotify app client secret |
| `SPOTIFY_REDIRECT_URI` | OAuth redirect URL |

## Tech Stack

- **Flutter** (web + Android) — Provider state management
- **just_audio + audio_service** — Background playback
- **Node.js/Express** — API proxy (CORS bypass, yt-dlp, YTMusic InnerTube)
- **yt-dlp** — Audio extraction from YouTube
- **dart_ytmusic_api** — YouTube Music search (proxied through server on web)
- **Podcast Index API** — Podcast search and streaming
- **Hive** — Local persistence (favorites, playlists, history)
- **Cloudflare Pages** — Web hosting
- **Render** — Server hosting

## License

MIT License — see [LICENSE](LICENSE) for details.
