import fs from 'fs';
import os from 'os';
import path from 'path';
import YTMusic from 'ytmusic-api';
import ytDlpExec from 'youtube-dl-exec';
import logger from '../utils/logger.js';

let ytmusic = null;

// Extracted googlevideo URLs stay valid for ~6h; cache them so repeat plays
// and the audio proxy don't re-spawn yt-dlp (which costs several seconds).
const urlCache = new Map(); // videoId -> { url, expires }
const URL_TTL_MS = 60 * 60 * 1000;

export function invalidateYouTubeUrl(videoId) {
  urlCache.delete(videoId);
}

async function getYTMusic() {
  if (!ytmusic) {
    ytmusic = new YTMusic();
    await ytmusic.initialize();
    logger.info('YouTube Music API initialized');
  }
  return ytmusic;
}

export async function searchYouTube(query, maxResults = 20) {
  try {
    const yt = await getYTMusic();
    const songs = await yt.searchSongs(query);
    const limited = songs.slice(0, maxResults);

    return limited.map((s) => ({
      videoId: s.videoId,
      title: s.name || 'Unknown',
      author: s.artist?.name || 'Unknown',
      thumbnail: s.thumbnails?.[s.thumbnails.length - 1]?.url || '',
      duration: s.duration || 0,
      source: 'youtube',
    }));
  } catch (err) {
    logger.error({ err }, 'YouTube Music search failed');
    return [];
  }
}

// Datacenter IPs (Render, AWS, ...) often get YouTube's "confirm you're not
// a bot" wall on the default web client; other player clients are frequently
// exempt, so try a few before giving up. Cookies (YTDLP_COOKIES_B64) are the
// reliable fix when every client is blocked.
const PLAYER_CLIENTS = ['default', 'android_vr', 'tv_simply'];

function looksLikeCookieFile(text) {
  return /# (Netscape|HTTP Cookie File)/i.test(text) || /\t(SID|__Secure-1PSID|LOGIN_INFO)\t/.test(text);
}

let cookiesPath; // undefined = not resolved yet, null = none configured
function getCookiesPath() {
  if (cookiesPath !== undefined) return cookiesPath;
  cookiesPath = null;

  // 1. A mounted file is the most robust on Render (Secret Files land in
  // /etc/secrets/<name>); no base64, no copy-paste truncation. Scan the
  // secrets dir so the exact filename doesn't matter.
  const candidates = [
    process.env.YTDLP_COOKIES_FILE,
    '/etc/secrets/cookies.txt',
  ].filter(Boolean);
  try {
    for (const f of fs.readdirSync('/etc/secrets')) {
      candidates.push(`/etc/secrets/${f}`);
    }
  } catch {}
  // yt-dlp rewrites the cookie file after each request to persist refreshed
  // session cookies. Render Secret Files are read-only, so copy the contents
  // into a writable temp file and hand yt-dlp that.
  const writable = path.join(os.tmpdir(), 'ytdlp-cookies.txt');
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) {
        const text = fs.readFileSync(p, 'utf8');
        if (looksLikeCookieFile(text)) {
          fs.writeFileSync(writable, text);
          cookiesPath = writable;
          logger.info({ source: p }, 'yt-dlp cookies loaded from file (writable copy)');
          return cookiesPath;
        }
      }
    } catch (err) {
      logger.warn({ err: err.message, path: p }, 'cookie file unreadable');
    }
  }

  // 2. Base64 env var fallback.
  const b64 = process.env.YTDLP_COOKIES_B64;
  if (b64) {
    try {
      const decoded = Buffer.from(b64, 'base64').toString('utf8');
      if (looksLikeCookieFile(decoded)) {
        const p = path.join(os.tmpdir(), 'ytdlp-cookies.txt');
        fs.writeFileSync(p, decoded);
        cookiesPath = p;
        logger.info('yt-dlp cookies configured from YTDLP_COOKIES_B64');
      } else {
        logger.warn({ len: b64.length }, 'YTDLP_COOKIES_B64 set but does not decode to a cookie file');
      }
    } catch (err) {
      logger.error({ err: err.message }, 'Failed to write yt-dlp cookies file');
    }
  }
  return cookiesPath;
}

function pickAudioUrl(data) {
  const audioFormats = (data.formats || [])
    .filter((f) => f.acodec && f.acodec !== 'none' && (!f.vcodec || f.vcodec === 'none'))
    .sort((a, b) => (b.abr || 0) - (a.abr || 0));
  return audioFormats[0]?.url || null;
}

export async function getYouTubeAudioUrl(videoId) {
  const hit = urlCache.get(videoId);
  if (hit && hit.expires > Date.now()) return hit.url;

  for (const client of PLAYER_CLIENTS) {
    try {
      const opts = {
        dumpSingleJson: true,
        noCheckCertificates: true,
        noWarnings: true,
        preferFreeFormats: true,
      };
      if (client !== 'default') opts.extractorArgs = `youtube:player_client=${client}`;
      const cookies = getCookiesPath();
      if (cookies) opts.cookies = cookies;

      const data = await ytDlpExec(videoId, opts);
      const url = pickAudioUrl(data);
      if (url) {
        if (client !== 'default') logger.info({ videoId, client }, 'Extracted via fallback player client');
        urlCache.set(videoId, { url, expires: Date.now() + URL_TTL_MS });
        return url;
      }
      logger.warn({ videoId, client }, 'No audio-only format found');
    } catch (err) {
      const stderr = (err?.stderr || err?.message || '').slice(0, 500);
      logger.error({ videoId, client, stderr }, 'YouTube audio URL extraction failed');
    }
  }
  return null;
}
