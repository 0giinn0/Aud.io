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

export async function getYouTubeAudioUrl(videoId) {
  const hit = urlCache.get(videoId);
  if (hit && hit.expires > Date.now()) return hit.url;

  try {
    const data = await ytDlpExec(videoId, {
      dumpSingleJson: true,
      noCheckCertificates: true,
      noWarnings: true,
      preferFreeFormats: true,
    });

    // Pick the best audio-only format (highest abr)
    const audioFormats = (data.formats || [])
      .filter((f) => f.acodec && f.acodec !== 'none' && (!f.vcodec || f.vcodec === 'none'))
      .sort((a, b) => (b.abr || 0) - (a.abr || 0));

    if (audioFormats.length === 0) {
      logger.warn({ videoId }, 'No audio-only format found');
      return null;
    }

    const url = audioFormats[0].url || null;
    if (url) urlCache.set(videoId, { url, expires: Date.now() + URL_TTL_MS });
    return url;
  } catch (err) {
    logger.error({ err, videoId }, 'YouTube audio URL extraction failed');
    return null;
  }
}
