# aud.io

You know that thing where you want to listen to music but every app is either bloated, ugly, or wants your firstborn? Yeah, we fixed that.

**aud.io** is a Flutter music player that searches YouTube Music, SoundCloud, and podcasts — streams everything, downloads what you want, looks the way music software should look. Built with a bento-box grid UI, golden-ratio navigation, and 7 hand-crafted themes.

## Live

- **Web app**: https://aud-io-web.pages.dev
- **API server**: https://aud-io.onrender.com

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart)](https://dart.dev)
[![Node](https://img.shields.io/badge/Node.js-20+-339933?logo=nodedotjs)](https://nodejs.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Build](https://github.com/0giinn0/Aud.io/actions/workflows/cloudflare-pages.yml/badge.svg)](https://github.com/0giinn0/Aud.io/actions)

---

## Screenshots

| Home | Now Playing | Themes | Library |
|:----:|:-----------:|:------:|:-------:|
| ![Home screen](docs/home.svg) | ![Now Playing](docs/now-playing.svg) | ![Themes](docs/themes.svg) | ![Library](docs/library.svg) |

---

## Architecture

![aud.io system architecture](docs/architecture.svg)

---

## What It Does

- **Search everything** — YouTube Music (InnerTube), SoundCloud, Podcast Index. Type a thing, get results.
- **Stream & download** — yt-dlp powered MP3 downloads. Your music, your files, your rules.
- **Podcasts** — Search, trending, and full episode playback via Podcast Index API.
- **Local files** — Scans your device for audio. VLC-style. Finds what you forgot you had.
- **Spotify import** — OAuth login → import your playlists. All 200 of them.
- **7 themes** — Ink & Red · Black & Grey · Black & Gold · Midnight Blue · Cream & Red · Pure White · Warm Sand.
- **Bento box UI** — Mixed-size cards, Fibonacci spacing, gradients. Your eyes will thank you.
- **Golden spiral nav** — 4 tabs arranged using φ (the golden ratio). Math is beautiful.
- **Offline playback** — Downloads stored locally with Hive, playable anywhere.
- **Playlists & favorites** — Stored on-device. No cloud required, no tracking.
- **Transfer files** — Import from URL · export as M3U/JSON · WiFi send to other devices.
- **Lyrics** — Pulled live, shown during playback.

---

## Getting It Running

### Prerequisites

- Flutter 3.24+
- Node.js 20+

### 1 — Start the server

```bash
cd aud.io/server
npm install
cp .env.example .env   # fill in your API keys
npm run dev
```

Server runs on `http://localhost:3000`.

### 2 — Run the Flutter app

```bash
cd aud.io
flutter pub get
flutter run -d chrome
```

Chrome opens. App loads. You feel accomplished. Good.

---

## Deployment

### Server → Render

Push to GitHub → Render picks up `render.yaml` → add your env vars in the dashboard → done.

### Web → Cloudflare Pages

Push to `main` → GitHub Actions builds Flutter web → deploys automatically.  
Add `CLOUDFLARE_API_TOKEN` as a repo secret if CI complains.

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `PODCAST_INDEX_API_KEY` | Podcast Index API key |
| `PODCAST_INDEX_API_SECRET` | Podcast Index API secret |
| `SOUNDCLOUD_CLIENT_ID` | SoundCloud client ID |
| `SPOTIFY_CLIENT_ID` | Spotify app client ID |
| `SPOTIFY_CLIENT_SECRET` | Spotify app client secret |
| `SPOTIFY_REDIRECT_URI` | OAuth redirect URL |

---

## API Reference

```
GET  /api/search?q={query}&source={youtube|soundcloud|podcasts}
GET  /api/stream?videoId={id}&source={youtube|soundcloud}
GET  /api/ytmusic/search?q={query}
GET  /api/ytmusic/videos?videoId={id}
POST /api/spotify/token
POST /api/spotify/refresh
GET  /api/spotify/playlists
GET  /api/spotify/playlists/{id}/tracks
GET  /api/podcasts/search?q={query}
GET  /api/podcasts/trending
GET  /api/podcasts/{id}/episodes
```

---

## Tech Stack

| Layer | Tech | Why |
|-------|------|-----|
| Frontend | Flutter + Provider | Cross-platform, fast, one codebase |
| Audio | just_audio + audio_service | Background playback, lock screen controls |
| Server | Node.js / Express | CORS bypass, API proxy, yt-dlp |
| YouTube | yt-dlp + InnerTube | Audio extraction that actually works |
| Podcasts | Podcast Index API | Free, open, no BS |
| Persistence | Hive | Fast local storage, works offline |
| Hosting | Cloudflare Pages + Render | Generous free tiers |

---

## Contributing

1. Fork it
2. `git checkout -b feat/your-thing`
3. `cd aud.io && flutter analyze` must pass clean (zero errors)
4. `dart format lib/` before committing
5. Open a PR — describe the why, not just the what

Design language: bento boxes · 7 themes · golden ratio spacing. If it doesn't feel right, we'll ask you to tweak it.

---

## Roadmap

- [ ] iOS / Android native builds
- [ ] Last.fm scrobbling
- [ ] Smart playlists (recently played, top tracks)
- [ ] Equalizer
- [ ] Lyrics sync
- [ ] Chromecast / AirPlay
- [ ] Collaborative playlists

---

## License

MIT — do whatever you want with it. Just don't make another subscription music app.

---

*Built with ☕ and mild sleep deprivation by people who just wanted a decent music player.*
