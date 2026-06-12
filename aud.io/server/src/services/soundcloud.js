import axios from 'axios';
import logger from '../utils/logger.js';

const TIMEOUT = 8000;
let cachedClientId = null;

async function isValidClientId(id) {
  try {
    const test = await axios.get('https://api-v2.soundcloud.com/search/tracks', {
      params: { q: 'test', client_id: id, limit: 1 },
      timeout: 5000,
      headers: { 'User-Agent': 'Mozilla/5.0' },
    });
    return test.status === 200;
  } catch {
    return false;
  }
}

async function fetchClientId() {
  // 1. Explicit env var wins — scraping soundcloud.com is blocked from many
  // datacenter IPs (e.g. Render), so a configured ID is the reliable path.
  const envId = process.env.SOUNDCLOUD_CLIENT_ID;
  if (envId && (await isValidClientId(envId))) return envId;
  if (envId) logger.warn('SOUNDCLOUD_CLIENT_ID is set but rejected by SoundCloud');

  // 2. Scrape the public web client (works from residential IPs).
  try {
    const { data } = await axios.get('https://soundcloud.com', {
      timeout: TIMEOUT,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
    });
    const matches = [...data.matchAll(/client_id:"([^"]+)"/g)].map((m) => m[1]);
    for (const id of matches) {
      if (await isValidClientId(id)) return id;
    }
    // Some bundles reference the client_id only in the JS chunks.
    const scriptUrls = [...data.matchAll(/<script[^>]+src="([^"]+)"/g)].map((m) => m[1]);
    for (const url of scriptUrls.reverse()) {
      try {
        const { data: js } = await axios.get(url, { timeout: 5000 });
        const m = js.match(/client_id:"([^"]+)"/);
        if (m && (await isValidClientId(m[1]))) return m[1];
      } catch {}
    }
  } catch (err) {
    logger.warn({ err: err.message }, 'SoundCloud client_id scrape failed');
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
