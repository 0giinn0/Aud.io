import { Router } from 'express';
import axios from 'axios';
import { searchYouTube } from '../services/youtube.js';
import { searchSoundCloud } from '../services/soundcloud.js';
import { searchFMA, getFMAStreamUrl, getFMATrackDetails } from '../services/fma.js';
import { searchPodcasts, getPodcastDetails, getTrendingPodcasts, getEpisodesFromFeed } from '../services/podcast.js';
import { getYouTubeAudioUrl, invalidateYouTubeUrl } from '../services/youtube.js';
import { getSoundCloudStreamUrl } from '../services/soundcloud.js';
import { cacheMiddleware } from '../middleware/cache.js';
import logger from '../utils/logger.js';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs';

const execFileAsync = promisify(execFile);
const router = Router();

const DOWNLOAD_DIR = path.join(process.cwd(), 'downloads');
if (!fs.existsSync(DOWNLOAD_DIR)) fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });

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



// POST /api/download { id, source }
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
