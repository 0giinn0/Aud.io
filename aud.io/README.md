# aud.io

You know that thing where you want to listen to music but every app is either bloated, ugly, or wants your firstborn? Yeah, we fixed that.

**aud.io** is a music player that actually respects your eyeballs. Built with Flutter, backed by a Node.js server, and deployed across Cloudflare Pages and Render. It searches YouTube Music, SoundCloud, and podcasts — all without selling your soul.

## Live

- **Web**: https://aud-io-web.pages.dev — go click stuff
- **Server**: https://aud-io.onrender.com — the brain behind the operation

## What It Does (aka Why You're Here)

- **Search everything** — YouTube Music via InnerTube, SoundCloud. Type a thing, get results. Revolutionary concept.
- **Podcasts too** — Podcast Index API powering search, trending, and episode playback. Because you deserve better than your current podcast app.
- **Local files** — Scans your device for audio files. VLC-style. It finds your music so you don't have to dig through folders like a digital archaeologist.
- **Spotify import** — OAuth login, fetch your playlists, one tap to import. Yes, we know you have 200 playlists on Spotify. We can handle it.
- **7 themes** — Ink & Red, Black & Grey, Black & Gold, Midnight Blue, Cream & Red, Pure White, Warm Sand. Because "dark mode" isn't a personality — pick a real one.
- **Golden spiral navigation** — 4 tabs arranged using the golden ratio. Math is beautiful, and so is this nav bar.
- **Bento box UI** — Mixed-size cards with gradients, rounded corners, Fibonacci spacing. Your eyes will thank you.
- **Downloads** — yt-dlp powered MP3 downloads. Your music, your files, your rules.
- **Playlists & favorites** — Stored locally with Hive. No cloud required, no tracking involved.
- **Transfer files** — Import from URL, export playlists as M3U/JSON, send music to other devices over WiFi.
- **Account login** — Email/password, Google, Apple. Sync across devices when you're ready.

## The Architecture (for the nerds)

```
├── lib/                        # The Flutter app
│   ├── main.dart               # Entry point, providers, navigation
│   ├── pages/                  # Home, Podcasts, Library, Settings, Now Playing
│   ├── services/               # API calls, audio handler, downloads, auth
│   ├── widgets/                # Golden spiral nav, mini player, proxied images
│   └── core/
│       ├── models/             # Track, Playlist, Podcast data models
│       └── theme/              # 7 theme presets, AppTheme engine
├── server/                     # Node.js API server (the muscle)
│   ├── src/
│   │   ├── index.js            # Express, CORS, rate limiting
│   │   ├── routes/api.js       # /api/search, /api/stream, /api/ytmusic/*, /api/spotify/*
│   │   ├── services/           # SoundCloud, Podcast Index
│   │   └── config.js           # Environment variables
│   └── Dockerfile              # Container for Render
├── render.yaml                 # One-click Render deploy
└── .github/workflows/          # Cloudflare Pages CI/CD
```

## Getting It Running (locally, like a civilized developer)

### What You Need
- Flutter 3.44+ (don't @ me about older versions)
- Node.js 20+

### Step 1: Start the server
```bash
cd server
npm install
cp .env.example .env
npm run dev
```
Congrats, you now have a server running on `http://localhost:3000`.

### Step 2: Run Flutter
```bash
cd aud.io
flutter pub get
flutter run -d chrome
```
Chrome opens. You see a beautiful app. You feel accomplished. Good.

## Deployment (aka "Ship It")

### Server → Render
1. Push to GitHub
2. Render picks up `render.yaml` and does its thing
3. Add your env vars in the Render dashboard
4. Done. Go get coffee.

### Web → Cloudflare Pages
1. Push to `main`
2. GitHub Actions builds Flutter web
3. Deploys to Cloudflare Pages automatically
4. Add `CLOUDFLARE_API_TOKEN` as a repo secret if it complains

## Environment Variables

| Variable | What It Does |
|----------|-------------|
| `PODCAST_INDEX_API_KEY` | Podcast Index API key |
| `PODCAST_INDEX_API_SECRET` | Podcast Index API secret |
| `SOUNDCLOUD_CLIENT_ID` | SoundCloud API client ID |
| `SPOTIFY_CLIENT_ID` | Spotify app client ID |
| `SPOTIFY_CLIENT_SECRET` | Spotify app client secret |
| `SPOTIFY_REDIRECT_URI` | OAuth redirect URL |

## Tech Stack

| Layer | Tech | Why |
|-------|------|-----|
| Frontend | Flutter + Provider | Cross-platform, fast, beautiful |
| Audio | just_audio + audio_service | Background playback, notifications |
| Server | Node.js/Express | CORS bypass, API proxy, yt-dlp |
| YouTube | yt-dlp + InnerTube | Audio extraction that actually works |
| Podcasts | Podcast Index API | Free, open, no BS |
| Persistence | Hive | Fast local storage, no internet needed |
| Hosting | Cloudflare Pages + Render | Free tier is generous |

## License

MIT — do whatever you want with it. Just don't make another subscription music app.
