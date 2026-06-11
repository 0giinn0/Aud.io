# aud.io

A production-ready streaming music player with YouTube/SoundCloud search, local file scanning, audio reactive visualization, download/offline mode, playlist/favorites, dark/light mode, bento box UI design, instrument builder, podcast streaming, and optional Supabase-backed social features.

## Features

- **Multi-source search**: YouTube (via InnerTube), SoundCloud, Free Music Archive (16,800+ CC tracks)
- **Podcast streaming**: Podcast Index API (search, trending, episodes via RSS)
- **Local files**: Scan device for audio files, play offline
- **Bento box UI**: Mixed-size rounded cards with gradients, 16px radius, 12px gaps
- **Audio visualization**: Real-time frequency bars + particle effects
- **Offline downloads**: yt-dlp powered MP3 downloads
- **Playlists & favorites**: Local + Supabase sync
- **Dark/light theme**: Dynamic runtime theme switching
- **Instrument Builder**: Web Audio API oscillators (sine/square/sawtooth/triangle)
- **Social features** (optional): Profiles, follows, comments, listening history via Supabase

## Architecture

```
aud.io/
├── lib/                    # Flutter app (Dart)
│   ├── main.dart           # App entry, 6-tab navigation
│   ├── pages/              # Home, Podcasts, Create, Profile, Settings
│   ├── services/           # API, audio handler, download, auth, DB
│   ├── widgets/            # Reusable UI (mini player, visualizer, etc.)
│   └── core/               # Models, theme
├── server/                 # Node.js proxy server
│   ├── src/
│   │   ├── index.js        # Express + CORS + rate limiting
│   │   ├── routes/api.js   # /api/search, /api/stream, /api/download
│   │   ├── services/       # youtube.js, soundcloud.js, fma.js, podcast.js
│   │   └── config.js       # dotenv config
│   ├── Dockerfile          # Render.com deployment
│   └── render.yaml         # One-click deploy config
└── supabase/               # PostgreSQL schema + RLS
```

## Quick Start

### Prerequisites
- Flutter 3.19+ / Dart 3.3+
- Node.js 20+
- Supabase account (optional, for social features)

### Run Locally

**1. Start the proxy server:**
```bash
cd server
npm install
cp .env.example .env   # Add your Podcast Index API keys
npm run dev            # Runs on http://localhost:3001
```

**2. Run the Flutter app:**
```bash
flutter pub get
flutter run -d chrome --web-port=8082
```

### Android APK
```bash
flutter build apk --dart-define=BASE_URL=https://your-server.onrender.com
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port (default 3001) | No |
| `PODCAST_INDEX_API_KEY` | Podcast Index API key | Yes (for podcasts) |
| `PODCAST_INDEX_API_SECRET` | Podcast Index API secret | Yes (for trending/details) |
| `PODCAST_INDEX_USER_AGENT` | User agent string | No |
| `SOUNDCLOUD_CLIENT_ID` | SoundCloud API client ID | No |
| `SUPABASE_URL` | Supabase project URL | No (social features) |
| `SUPABASE_ANON_KEY` | Supabase anon key | No (social features) |

## Deploy Server to Render.com

1. Push this repo to GitHub
2. On Render: **New → Web Service** → connect repo
3. It auto-detects `server/Dockerfile`
4. Add env vars in Render dashboard (see above)
5. Deploy → get `https://your-app.onrender.com`

Update Flutter build:
```bash
flutter build apk --dart-define=BASE_URL=https://your-app.onrender.com
```

## Tech Stack

- **Flutter** (web + Android) with Provider state management
- **just_audio + audio_service** for background playback
- **Node.js/Express** proxy server (bypasses CORS, runs yt-dlp)
- **yt-dlp / youtube-dl-exec** for audio extraction
- **ytmusic-api** (InnerTube) for YouTube search
- **Podcast Index API** for podcasts
- **archive.org API** for Free Music Archive
- **Supabase** (PostgreSQL + Auth + Realtime) for social

## License

MIT License - see [LICENSE](LICENSE) for details.