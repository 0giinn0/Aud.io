import { Router } from 'express';
import axios from 'axios';
import { searchYouTube } from '../services/youtube.js';
import { searchSoundCloud } from '../services/soundcloud.js';
import { searchFMA, getFMAStreamUrl, getFMATrackDetails } from '../services/fma.js';
import { searchPodcasts, getPodcastDetails, getTrendingPodcasts, getEpisodesFromFeed } from '../services/podcast.js';
import { getYouTubeAudioUrl, invalidateYouTubeUrl } from '../services/youtube.js';
import { getSoundCloudStreamUrl } from '../services/soundcloud.js';
import { searchArtists as searchArtistsItunes, getArtistTracks } from '../services/itunes.js';
import { searchArtists as searchArtistsLastfm, getTrendingArtists, getArtistInfo } from '../services/lastfm.js';
import { cacheMiddleware } from '../middleware/cache.js';
import logger from '../utils/logger.js';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

const execFileAsync = promisify(execFile);
const router = Router();

const DOWNLOAD_DIR = path.join(process.cwd(), 'downloads');
if (!fs.existsSync(DOWNLOAD_DIR)) fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });

// GET /api/debug/ytdlp?id=videoId — temporary diagnostics for extraction
// failures on hosts we can't shell into (returns yt-dlp version + stderr
// per player client).
router.get('/debug/ytdlp', async (req, res) => {
  const videoId = (req.query.id || 'khnokW3Mw24').trim();
  const out = { node: process.version, env: { YOUTUBE_DL_DIR: process.env.YOUTUBE_DL_DIR || null } };

  // Materialise cookies the same way the real extractor does, and report on
  // their shape so we can tell a missing/garbled/expired cookie file apart.
  // Sources, in priority order: a mounted file (Render Secret File) or base64.
  let cookiePath = null;
  let cookieText = null;
  out.cookies = {};
  try { out.cookies.secretsDir = fs.readdirSync('/etc/secrets'); } catch (e) { out.cookies.secretsDir = `none (${e.code})`; }
  const fileCandidates = [process.env.YTDLP_COOKIES_FILE, '/etc/secrets/cookies.txt'].filter(Boolean);
  try { for (const f of fs.readdirSync('/etc/secrets')) fileCandidates.push(`/etc/secrets/${f}`); } catch {}
  for (const p of fileCandidates) {
    try {
      if (fs.existsSync(p)) {
        cookieText = fs.readFileSync(p, 'utf8');
        // Copy to a writable temp file — yt-dlp rewrites the cookie file and
        // Render Secret Files are read-only (mirrors the real extractor path).
        cookiePath = path.join(os.tmpdir(), 'debug-cookies.txt');
        fs.writeFileSync(cookiePath, cookieText);
        out.cookies.source = `file:${p}`;
        break;
      }
    } catch {}
  }
  if (!cookieText) {
    const b64 = process.env.YTDLP_COOKIES_B64;
    out.cookies.envPresent = !!b64;
    out.cookies.envLength = b64 ? b64.length : 0;
    if (b64) {
      try {
        cookieText = Buffer.from(b64, 'base64').toString('utf8');
        out.cookies.source = 'env:YTDLP_COOKIES_B64';
        cookiePath = path.join(process.cwd(), 'debug-cookies.txt');
        fs.writeFileSync(cookiePath, cookieText);
      } catch (err) {
        out.cookies.error = err.message;
      }
    }
  }
  if (cookieText) {
    const lines = cookieText.split('\n').filter((l) => l.trim() && !l.startsWith('#'));
    out.cookies.bytes = cookieText.length;
    out.cookies.firstLine = cookieText.split('\n')[0].slice(0, 60);
    out.cookies.cookieLines = lines.length;
    out.cookies.hasLoginCookies = /SID|SAPISID|__Secure-1PSID/.test(cookieText);
  }

  try {
    const ytdlpModule = await import('youtube-dl-exec');
    const binPath = (ytdlpModule.default?.constants || ytdlpModule.constants)?.YOUTUBE_DL_PATH;
    out.binary = binPath || null;
    out.binaryExists = binPath ? fs.existsSync(binPath) : false;
    if (!out.binaryExists) return res.json(out);

    try {
      const { stdout } = await execFileAsync(binPath, ['--version'], { timeout: 20000 });
      out.version = stdout.trim();
    } catch (err) {
      out.version = `ERROR: ${(err.stderr || err.message || '').slice(-300)}`;
    }

    out.attempts = [];
    // Test each client both without and (if available) with cookies.
    const variants = [{ tag: 'no-cookies', cookies: false }];
    if (cookiePath) variants.push({ tag: 'with-cookies', cookies: true });
    for (const client of ['default', 'android_vr', 'tv_simply']) {
      for (const v of variants) {
        const args = ['--dump-single-json', '--no-warnings', '--skip-download'];
        if (client !== 'default') args.push('--extractor-args', `youtube:player_client=${client}`);
        if (v.cookies) args.push('--cookies', cookiePath);
        args.push(videoId);
        try {
          const { stdout } = await execFileAsync(binPath, args, { timeout: 90000, maxBuffer: 64 * 1024 * 1024 });
          const data = JSON.parse(stdout);
          const audio = (data.formats || []).filter(
            (f) => f.acodec && f.acodec !== 'none' && (!f.vcodec || f.vcodec === 'none')
          );
          out.attempts.push({ client, variant: v.tag, ok: true, audioFormats: audio.length });
        } catch (err) {
          out.attempts.push({ client, variant: v.tag, ok: false, error: (err.stderr || err.message || '').slice(-600) });
        }
      }
    }
  } catch (err) {
    out.fatal = err.message;
  } finally {
    // Only remove the temp file we wrote ourselves — never the mounted secret.
    if (cookiePath && cookiePath.endsWith('debug-cookies.txt')) { try { fs.unlinkSync(cookiePath); } catch {} }
  }
  res.json(out);
});

// GET /api/search?q=query&max=20
router.get('/search', cacheMiddleware(60), async (req, res, next) => {
  try {
    const query = (req.query.q || '').trim();
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);

    if (!query) {
      res.status(400).json({ error: true, message: 'Missing ?q=' });
      return;
    }

    const results = [];
    const errors = [];

    // Try YouTube first (faster, more reliable)
    try {
      const yt = await searchYouTube(query, max);
      results.push(...yt);
    } catch (err) {
      errors.push({ source: 'youtube', message: err.message });
    }

    // Try SoundCloud second (slower, client_id may need refresh)
    try {
      const sc = await searchSoundCloud(query, max);
      results.push(...sc);
    } catch (err) {
      errors.push({ source: 'soundcloud', message: err.message });
    }

    // Try FMA (free Creative Commons music)
    try {
      const fma = await searchFMA(query, max);
      results.push(...fma);
    } catch (err) {
      errors.push({ source: 'fma', message: err.message });
    }

    // Shuffle interleave
    results.sort(() => Math.random() - 0.5);

    res.json({ results, total: results.length, errors: errors.length > 0 ? errors : undefined });
  } catch (err) {
    next(err);
  }
});

async function resolveStreamUrl(id, source, { fresh = false } = {}) {
  if (source === 'youtube') {
    if (fresh) invalidateYouTubeUrl(id);
    return getYouTubeAudioUrl(id);
  }
  if (source === 'soundcloud') return getSoundCloudStreamUrl(id);
  if (source === 'fma') return getFMAStreamUrl(id);
  return null;
}

// GET /api/stream/:id?source=youtube|soundcloud|fma
router.get('/stream/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const source = (req.query.source || 'youtube').toLowerCase();

    if (!['youtube', 'soundcloud', 'fma'].includes(source)) {
      res.status(400).json({ error: true, message: 'Invalid source. Use ?source=youtube|soundcloud|fma' });
      return;
    }

    const audioUrl = await resolveStreamUrl(id, source);
    if (!audioUrl) {
      res.status(404).json({ error: true, message: 'No audio stream available' });
      return;
    }

    res.json({ url: audioUrl, source });
  } catch (err) {
    next(err);
  }
});

// GET /api/stream/:id/audio?source=youtube|soundcloud|fma
// Proxies the raw audio bytes with Range support. YouTube googlevideo URLs
// are IP-bound to this server, so clients on other devices must stream
// through here instead of hitting the extracted URL directly.
router.get('/stream/:id/audio', async (req, res) => {
  const { id } = req.params;
  const source = (req.query.source || 'youtube').toLowerCase();

  try {
    let url = await resolveStreamUrl(id, source);
    if (!url) {
      res.status(404).json({ error: true, message: 'No audio stream available' });
      return;
    }

    // HLS playlists (SoundCloud's default) can't be played by browsers/just_audio
    // as raw bytes. Transcode to a progressive MP3 stream with ffmpeg so the
    // same URL plays everywhere. Range/seeking isn't supported for transcoded
    // streams, so we serve the whole thing as 200.
    if (/\.m3u8(\?|$)/i.test(url)) {
      res.status(200);
      res.setHeader('content-type', 'audio/mpeg');
      res.setHeader('cache-control', 'no-store');
      const ff = spawn('ffmpeg', [
        '-hide_banner', '-loglevel', 'error',
        '-user_agent', 'Mozilla/5.0',
        '-i', url,
        '-vn', '-f', 'mp3', '-ab', '128k',
        'pipe:1',
      ]);
      ff.stdout.pipe(res);
      ff.stderr.on('data', (d) => logger.warn({ id, source, ff: d.toString().slice(0, 200) }, 'ffmpeg'));
      ff.on('error', (e) => {
        logger.error({ err: e.message, id, source }, 'ffmpeg spawn failed');
        if (!res.headersSent) res.status(502).end(); else res.end();
      });
      res.on('close', () => ff.kill('SIGKILL'));
      return;
    }

    const fetchUpstream = (u) =>
      axios.get(u, {
        responseType: 'stream',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          ...(req.headers.range ? { Range: req.headers.range } : {}),
        },
        timeout: 20000,
        maxRedirects: 5,
        validateStatus: (s) => s < 500,
      });

    let upstream = await fetchUpstream(url);

    // Expired/invalid cached URL — re-extract once and retry
    if (upstream.status === 403 || upstream.status === 410 || upstream.status === 404) {
      upstream.data.destroy();
      url = await resolveStreamUrl(id, source, { fresh: true });
      if (!url) {
        res.status(404).json({ error: true, message: 'No audio stream available' });
        return;
      }
      upstream = await fetchUpstream(url);
    }

    if (upstream.status >= 400) {
      upstream.data.destroy();
      res.status(upstream.status).json({ error: true, message: 'Upstream rejected the stream request' });
      return;
    }

    res.status(upstream.status);
    for (const h of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      if (upstream.headers[h]) res.setHeader(h, upstream.headers[h]);
    }
    if (!upstream.headers['accept-ranges']) res.setHeader('accept-ranges', 'bytes');
    res.setHeader('cache-control', 'no-store');

    upstream.data.pipe(res);
    res.on('close', () => upstream.data.destroy());
  } catch (err) {
    logger.error({ err: err.message, id, source }, 'Audio proxy failed');
    if (!res.headersSent) {
      res.status(502).json({ error: true, message: 'Stream proxy failed' });
    } else {
      res.end();
    }
  }
});

// GET /api/proxy?url=<encoded> — stream an arbitrary http(s) audio URL with
// CORS + Range support. Used for podcast episodes, whose RSS audio hosts often
// don't send CORS headers (so browsers can't play them directly).
router.get('/proxy', async (req, res) => {
  const target = req.query.url;
  if (!target || !/^https?:\/\//i.test(target)) {
    res.status(400).json({ error: true, message: 'Missing or invalid ?url=' });
    return;
  }
  try {
    const upstream = await axios.get(target, {
      responseType: 'stream',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ...(req.headers.range ? { Range: req.headers.range } : {}),
      },
      timeout: 20000,
      maxRedirects: 5,
      validateStatus: (s) => s < 500,
    });
    if (upstream.status >= 400) {
      upstream.data.destroy();
      res.status(upstream.status).json({ error: true, message: 'Upstream rejected the request' });
      return;
    }
    res.status(upstream.status);
    for (const h of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      if (upstream.headers[h]) res.setHeader(h, upstream.headers[h]);
    }
    if (!upstream.headers['accept-ranges']) res.setHeader('accept-ranges', 'bytes');
    res.setHeader('cache-control', 'no-store');
    upstream.data.pipe(res);
    res.on('close', () => upstream.data.destroy());
  } catch (err) {
    logger.error({ err: err.message, target }, 'Generic proxy failed');
    if (!res.headersSent) res.status(502).json({ error: true, message: 'Proxy failed' });
    else res.end();
  }
});

// GET /api/fma/details/:id - get FMA track details (artist credit, license)
router.get('/fma/details/:id', cacheMiddleware(300), async (req, res, next) => {
  try {
    const details = await getFMATrackDetails(req.params.id);
    if (!details) {
      res.status(404).json({ error: true, message: 'Track not found' });
      return;
    }
    res.json(details);
  } catch (err) {
    next(err);
  }
});

// ===== PODCAST ROUTES (Podcast Index) =====

// GET /api/podcasts/search?q=query&max=10
router.get('/podcasts/search', cacheMiddleware(120), async (req, res, next) => {
  try {
    const query = (req.query.q || '').trim();
    const max = Math.min(parseInt(req.query.max || '10', 10), 50);

    if (!query) {
      res.status(400).json({ error: true, message: 'Missing ?q=' });
      return;
    }

    const results = await searchPodcasts(query, max);
    res.json({ results, total: results.length });
  } catch (err) {
    next(err);
  }
});

// GET /api/podcasts/trending?max=20&lang=en
router.get('/podcasts/trending', cacheMiddleware(600), async (req, res, next) => {
  try {
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);
    const lang = req.query.lang || 'en';
    const results = await getTrendingPodcasts(max, lang);
    res.json({ results, total: results.length });
  } catch (err) {
    next(err);
  }
});

// GET /api/podcasts/podcast/:id?episodes=10
router.get('/podcasts/podcast/:id', cacheMiddleware(300), async (req, res, next) => {
  try {
    const maxEpisodes = Math.min(parseInt(req.query.episodes || '10', 10), 50);
    const details = await getPodcastDetails(req.params.id, maxEpisodes);
    if (!details) {
      res.status(404).json({ error: true, message: 'Podcast not found' });
      return;
    }
    res.json(details);
  } catch (err) {
    next(err);
  }
});

// GET /api/podcasts/feed?url=RSS_URL&max=20
router.get('/podcasts/feed', cacheMiddleware(300), async (req, res, next) => {
  try {
    const feedUrl = req.query.url;
    if (!feedUrl) {
      res.status(400).json({ error: true, message: 'Missing ?url=' });
      return;
    }
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);
    const episodes = await getEpisodesFromFeed(feedUrl, max);
    res.json({ episodes, total: episodes.length });
  } catch (err) {
    next(err);
  }
});

// ===== ARTIST ROUTES (iTunes + Last.fm) =====

// GET /api/artists/search?q=query&max=20
router.get('/artists/search', cacheMiddleware(120), async (req, res, next) => {
  try {
    const query = (req.query.q || '').trim();
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);

    if (!query) {
      res.status(400).json({ error: true, message: 'Missing ?q=' });
      return;
    }

    const results = [];
    const errors = [];

    // Try iTunes first
    try {
      const itunes = await searchArtistsItunes(query, max);
      results.push(...itunes);
    } catch (err) {
      errors.push({ source: 'itunes', message: err.message });
    }

    // Try Last.fm second
    try {
      const lastfm = await searchArtistsLastfm(query, max);
      results.push(...lastfm);
    } catch (err) {
      errors.push({ source: 'lastfm', message: err.message });
    }

    // Remove duplicates by name
    const uniqueResults = Array.from(new Map(results.map((a) => [a.name.toLowerCase(), a])).values());
    uniqueResults.sort(() => Math.random() - 0.5); // Shuffle

    res.json({ results: uniqueResults, total: uniqueResults.length, errors: errors.length > 0 ? errors : undefined });
  } catch (err) {
    next(err);
  }
});

// GET /api/artists/trending?max=20
router.get('/artists/trending', cacheMiddleware(600), async (req, res, next) => {
  try {
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);
    const results = await getTrendingArtists(max);
    res.json({ results, total: results.length });
  } catch (err) {
    next(err);
  }
});

// GET /api/artists/:name/info
router.get('/artists/:name/info', cacheMiddleware(300), async (req, res, next) => {
  try {
    const info = await getArtistInfo(req.params.name);
    if (!info) {
      res.status(404).json({ error: true, message: 'Artist not found' });
      return;
    }
    res.json(info);
  } catch (err) {
    next(err);
  }
});


router.post('/download', async (req, res, next) => {
  try {
    const { id, source } = req.body;
    if (!id || !source) {
      res.status(400).json({ error: true, message: 'Missing id or source' });
      return;
    }

    const safeId = id.replace(/[^a-zA-Z0-9_-]/g, '');
    const outputPath = path.join(DOWNLOAD_DIR, `${safeId}.mp3`);

    if (fs.existsSync(outputPath)) {
      res.json({ success: true, path: outputPath, cached: true });
      return;
    }

    let ytDlpArgs = ['-x', '--audio-format', 'mp3', '--audio-quality', '192K', '-o', outputPath];
    if (source === 'youtube') {
      ytDlpArgs.push(`https://www.youtube.com/watch?v=${safeId}`);
    } else if (source === 'soundcloud') {
      ytDlpArgs.push(`https://soundcloud.com/${safeId}`);
    } else {
      res.status(400).json({ error: true, message: 'Invalid source' });
      return;
    }

    const { stdout, stderr } = await execFileAsync('yt-dlp', ytDlpArgs, { timeout: 120000 });
    if (!fs.existsSync(outputPath)) {
      logger.error({ stdout, stderr }, 'yt-dlp download failed');
      res.status(500).json({ error: true, message: 'Download failed' });
      return;
    }

    res.json({ success: true, path: outputPath, cached: false });
  } catch (err) {
    logger.error({ err }, 'Download error');
    res.status(500).json({ error: true, message: err.message });
  }
});

// GET /api/download/:id - serve downloaded file
router.get('/download/:id', (req, res) => {
  const { id } = req.params;
  const safeId = id.replace(/[^a-zA-Z0-9_-]/g, '');
  const filePath = path.join(DOWNLOAD_DIR, `${safeId}.mp3`);

  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: true, message: 'File not found' });
    return;
  }

  res.sendFile(filePath);
});

export default router;
