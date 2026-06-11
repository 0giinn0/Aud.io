import axios from 'axios';
import logger from '../utils/logger.js';

const TIMEOUT = 8000;
let cachedClientId = null;

async function fetchClientId() {
  const { data } = await axios.get('https://soundcloud.com', {
    timeout: TIMEOUT,
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
  });

  const match = data.match(/client_id:"([^"]+)"/);
  if (match) return match[1];

  // Fallback: known working client IDs
  const fallbacks = [
    'iX3TkAHCh8ZLMiFTFjxfBB7SYyoBEEN',
    'a3e059563d7fd3372b49b37f00a00bca',
  ];
  for (const fb of fallbacks) {
    try {
      const test = await axios.get('https://api-v2.soundcloud.com/search/tracks', {
        params: { q: 'test', client_id: fb, limit: 1 },
        timeout: 5000,
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      if (test.status === 200) return fb;
    } catch {}
  }

  throw new Error('Could not find SoundCloud client ID');
}

async function getClientId() {
  if (cachedClientId) return cachedClientId;
  cachedClientId = await fetchClientId();
  logger.info('SoundCloud client ID acquired');
  return cachedClientId;
}

export async function searchSoundCloud(query, maxResults = 20) {
  const clientId = await getClientId();
  const { data } = await axios.get('https://api-v2.soundcloud.com/search/tracks', {
    params: { q: query, client_id: clientId, limit: maxResults, offset: 0 },
    timeout: TIMEOUT,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
    },
  });

  const collection = data?.collection || [];
  return collection.map((t) => {
    const user = t.user || {};
    const artwork = t.artwork_url || '';
    return {
      trackId: `sc_${t.id}`,
      title: t.title || 'Unknown',
      author: user.username || 'Unknown',
      thumbnail: artwork.replace('large', 't500x500'),
      duration: Math.floor((t.duration || 0) / 1000),
      source: 'soundcloud',
    };
  });
}

export async function getSoundCloudStreamUrl(trackId) {
  try {
    const clientId = await getClientId();
    const scId = trackId.replace('sc_', '');
    const { data } = await axios.get(`https://api.soundcloud.com/tracks/${scId}/streams`, {
      params: { client_id: clientId },
      timeout: TIMEOUT,
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
    });
    return data?.http_mp3_128_url || data?.hls_mp3_128_url || null;
  } catch (err) {
    logger.error({ err, trackId }, 'SoundCloud stream URL failed');
    if (err.response?.status === 401) {
      cachedClientId = null; // force refresh
      return getSoundCloudStreamUrl(trackId);
    }
    return null;
  }
}
