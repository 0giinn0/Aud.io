import { Router } from 'express';
import axios from 'axios';
import { searchSoundCloud } from '../services/soundcloud.js';
import { getSoundCloudStreamUrl } from '../services/soundcloud.js';
import { searchPodcasts, getPodcastDetails, getTrendingPodcasts, getEpisodesFromFeed } from '../services/podcast.js';
import { cacheMiddleware } from '../middleware/cache.js';
import logger from '../utils/logger.js';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs';
import config from '../config.js';

const execFileAsync = promisify(execFile);
const router = Router();

const DOWNLOAD_DIR = path.join(process.cwd(), 'downloads');
if (!fs.existsSync(DOWNLOAD_DIR)) fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });

// GET /api/debug/ytdlp — keep for diagnostics
router.get('/debug/ytdlp', async (req, res) => {
  const videoId = (req.query.id || 'khnokW3Mw24').trim();
  const out = { node: process.version, env: { YOUTUBE_DL_DIR: process.env.YOUTUBE_DL_DIR || null } };

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
    if (cookiePath && cookiePath.endsWith('debug-cookies.txt')) { try { fs.unlinkSync(cookiePath); } catch {} }
  }
  res.json(out);
});

// GET /api/search?q=query&max=20 — SoundCloud only (YouTube is client-side now)
router.get('/search', cacheMiddleware(60), async (req, res, next) => {
  try {
    const query = (req.query.q || '').trim();
    const max = Math.min(parseInt(req.query.max || '20', 10), 50);
    if (!query) {
      res.status(400).json({ error: true, message: 'Missing ?q=' });
      return;
    }
    const results = await searchSoundCloud(query, max);
    res.json({ results, total: results.length });
  } catch (err) {
    next(err);
  }
});

// GET /api/stream/:id/audio?source=soundcloud — audio proxy for SoundCloud
router.get('/stream/:id/audio', async (req, res) => {
  const { id } = req.params;
  const source = (req.query.source || '').toLowerCase();
  if (source !== 'soundcloud') {
    res.status(400).json({ error: true, message: 'Only ?source=soundcloud is supported from server' });
    return;
  }
  try {
    let url = await getSoundCloudStreamUrl(id);
    if (!url) {
      res.status(404).json({ error: true, message: 'No audio stream available' });
      return;
    }
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
    if (!res.headersSent) res.status(502).json({ error: true, message: 'Stream proxy failed' });
    else res.end();
  }
});

// GET /api/proxy?url=<encoded> — generic audio proxy with CORS + Range
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

// GET /api/proxy-image?url=X — image proxy with CORS + HTTPS upgrade
router.get('/proxy-image', async (req, res) => {
  let target = req.query.url;
  if (!target || !/^https?:\/\//i.test(target)) {
    res.status(400).json({ error: true, message: 'Missing or invalid ?url=' });
    return;
  }
  target = target.replace(/^http:/i, 'https:');
  try {
    const upstream = await axios.get(target, {
      responseType: 'stream',
      headers: { 'User-Agent': 'Mozilla/5.0' },
      timeout: 10000,
      maxRedirects: 5,
      validateStatus: (s) => s < 500,
    });
    if (upstream.status >= 400) {
      upstream.data.destroy();
      res.status(upstream.status).end();
      return;
    }
    res.status(upstream.status);
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('cache-control', 'public, max-age=86400');
    if (upstream.headers['content-type']) res.setHeader('content-type', upstream.headers['content-type']);
    upstream.data.pipe(res);
    res.on('close', () => upstream.data.destroy());
  } catch (err) {
    logger.error({ err: err.message, target }, 'Image proxy failed');
    if (!res.headersSent) res.status(502).end();
    else res.end();
  }
});

// ===== PODCAST ROUTES =====

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

// ===== DOWNLOAD ROUTES =====

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

// ===== SPOTIFY ROUTES =====

router.post('/spotify/token', async (req, res, next) => {
  try {
    const { code } = req.body;
    if (!code) {
      res.status(400).json({ error: true, message: 'Missing code' });
      return;
    }
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: config.spotify.redirectUri,
    });
    const authHeader = Buffer.from(
      `${config.spotify.clientId}:${config.spotify.clientSecret}`
    ).toString('base64');
    const resp = await axios.post('https://accounts.spotify.com/api/token', params.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${authHeader}`,
      },
    });
    res.json(resp.data);
  } catch (err) {
    logger.error({ err: err.message }, 'Spotify token exchange failed');
    const status = err.response?.status || 502;
    res.status(status).json({ error: true, message: err.response?.data?.error_description || 'Token exchange failed' });
  }
});

router.post('/spotify/refresh', async (req, res, next) => {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      res.status(400).json({ error: true, message: 'Missing refresh_token' });
      return;
    }
    const params = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token,
    });
    const authHeader = Buffer.from(
      `${config.spotify.clientId}:${config.spotify.clientSecret}`
    ).toString('base64');
    const resp = await axios.post('https://accounts.spotify.com/api/token', params.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${authHeader}`,
      },
    });
    res.json(resp.data);
  } catch (err) {
    logger.error({ err: err.message }, 'Spotify token refresh failed');
    res.status(502).json({ error: true, message: 'Token refresh failed' });
  }
});

router.get('/spotify/playlists', async (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token) {
      res.status(401).json({ error: true, message: 'Missing Authorization header' });
      return;
    }
    const limit = Math.min(parseInt(req.query.limit || '50', 10), 50);
    const offset = parseInt(req.query.offset || '0', 10);
    const resp = await axios.get('https://api.spotify.com/v1/me/playlists', {
      headers: { Authorization: `Bearer ${token}` },
      params: { limit, offset },
    });
    const playlists = resp.data.items.map((p) => ({
      id: p.id,
      name: p.name,
      description: p.description || '',
      image: p.images?.[0]?.url || null,
      trackCount: p.tracks.total,
      owner: p.owner?.display_name || '',
      externalUrl: p.external_urls?.spotify || '',
    }));
    res.json({ playlists, total: resp.data.total });
  } catch (err) {
    logger.error({ err: err.message }, 'Spotify playlists fetch failed');
    res.status(err.response?.status || 502).json({ error: true, message: 'Failed to fetch playlists' });
  }
});

router.get('/spotify/playlists/:id/tracks', async (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token) {
      res.status(401).json({ error: true, message: 'Missing Authorization header' });
      return;
    }
    const limit = Math.min(parseInt(req.query.limit || '100', 10), 100);
    const offset = parseInt(req.query.offset || '0', 10);
    const resp = await axios.get(`https://api.spotify.com/v1/playlists/${req.params.id}/tracks`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { limit, offset, market: 'US' },
    });
    const tracks = resp.data.items
      .filter((item) => item.track && item.track.name)
      .map((item) => {
        const t = item.track;
        return {
          id: t.id,
          title: t.name,
          artist: t.artists?.map((a) => a.name).join(', ') || 'Unknown',
          album: t.album?.name || '',
          artwork: t.album?.images?.[0]?.url || null,
          duration: Math.floor((t.duration_ms || 0) / 1000),
          previewUrl: t.preview_url || null,
          externalUrl: t.external_urls?.spotify || '',
        };
      });
    res.json({ tracks, total: resp.data.total });
  } catch (err) {
    logger.error({ err: err.message }, 'Spotify playlist tracks fetch failed');
    res.status(err.response?.status || 502).json({ error: true, message: 'Failed to fetch playlist tracks' });
  }
});

export default router;
