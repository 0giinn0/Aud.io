import crypto from 'node:crypto';
import config from '../config.js';
import logger from '../utils/logger.js';
import { parseString } from 'xml2js';

const API_BASE = 'https://api.podcastindex.org/api/1.0';
const { apiKey, apiSecret, userAgent } = config.podcast;

/**
 * Generate authentication headers for Podcast Index API
 */
function getAuthHeaders() {
  if (!apiKey || !apiSecret) return null;
  const timestamp = Math.floor(Date.now() / 1000);
  const raw = apiKey + apiSecret + timestamp;
  const hash = crypto.createHash('sha1').update(raw).digest('hex');
  logger.debug({ apiKey: apiKey.substring(0, 4) + '...', secretLen: apiSecret.length, timestamp, hash }, 'Podcast Index auth headers');
  return {
    'User-Agent': userAgent,
    'X-Auth-Key': apiKey,
    'X-Auth-Date': timestamp.toString(),
    'Authorization': hash,
  };
}

/**
 * Search podcasts - free endpoint (no auth required)
 * Uses Podcast Index's Apple-replacement API
 */
export async function searchPodcasts(query, maxResults = 10) {
  try {
    const params = new URLSearchParams({ term: query, entity: 'podcast' });
    const resp = await fetch(`https://api.podcastindex.org/search?${params}`, {
      headers: { 'User-Agent': userAgent },
    });

    if (!resp.ok) throw new Error(`Podcast search failed: ${resp.status}`);

    const data = await resp.json();
    const results = (data.results || []).slice(0, maxResults);

    return results.map(r => ({
      id: r.collectionId || r.id,
      title: r.collectionName || r.trackName || 'Unknown',
      artist: r.artistName || 'Unknown',
      description: '',
      thumbnail: r.artworkUrl600 || r.artworkUrl100 || '',
      episodeCount: r.trackCount || 0,
      feedUrl: r.feedUrl || '',
      source: 'podcast',
    }));
  } catch (err) {
    logger.error({ err, query }, 'Podcast search error');
    return [];
  }
}

/**
 * Get trending podcasts - requires auth
 */
export async function getTrendingPodcasts(maxResults = 20, lang = 'en') {
  const headers = getAuthHeaders();
  if (!headers) return [];

  try {
    const params = new URLSearchParams({ max: String(maxResults), lang });
    const resp = await fetch(`${API_BASE}/podcasts/trending?${params}`, { headers });
    if (!resp.ok) throw new Error('Trending failed');

    const data = await resp.json();
    return (data.feeds || []).map(feed => ({
      id: feed.id,
      title: feed.title || 'Unknown',
      artist: feed.author || feed.owner || 'Unknown',
      description: feed.description || '',
      thumbnail: feed.image || feed.artwork || '',
      episodeCount: feed.episodeCount || 0,
      feedUrl: feed.url || '',
      source: 'podcast',
    }));
  } catch (err) {
    logger.error({ err }, 'Trending podcasts error');
    return [];
  }
}

/**
 * Get podcast details - requires auth
 */
export async function getPodcastDetails(feedId, maxEpisodes = 10) {
  const headers = getAuthHeaders();
  if (!headers) return null;

  try {
    const podcastResp = await fetch(`${API_BASE}/podcasts/byfeedid?id=${feedId}`, { headers });
    if (!podcastResp.ok) return null;

    const podcastData = await podcastResp.json();
    const feed = podcastData.feed;
    if (!feed) return null;

    const episodesResp = await fetch(`${API_BASE}/episodes/byfeedid?id=${feedId}&max=${maxEpisodes}`, { headers });
    let episodes = [];
    if (episodesResp.ok) {
      const epData = await episodesResp.json();
      episodes = (epData.items || []).map(ep => ({
        id: ep.id,
        title: ep.title || 'Unknown',
        description: ep.description || '',
        audioUrl: ep.enclosureUrl || '',
        duration: ep.duration || 0,
        publishDate: ep.datePublished || 0,
        thumbnail: ep.image || feed.image || '',
        podcastId: feedId,
        podcastTitle: feed.title || '',
        podcastAuthor: feed.author || '',
      }));
    }

    return {
      id: feed.id,
      title: feed.title || 'Unknown',
      author: feed.author || feed.owner || 'Unknown',
      description: feed.description || '',
      thumbnail: feed.image || feed.artwork || '',
      episodeCount: feed.episodeCount || 0,
      feedUrl: feed.url || '',
      episodes,
      source: 'podcast',
    };
  } catch (err) {
    logger.error({ err, feedId }, 'Podcast details error');
    return null;
  }
}

/**
 * Parse RSS feed to get episodes (works without auth)
 */
export async function getEpisodesFromFeed(feedUrl, maxEpisodes = 20) {
  try {
    const resp = await fetch(feedUrl, {
      headers: { 'User-Agent': userAgent },
      signal: AbortSignal.timeout(10000),
    });

    if (!resp.ok) throw new Error(`Feed fetch failed: ${resp.status}`);

    const xml = await resp.text();

    return new Promise((resolve, reject) => {
      parseString(xml, { explicitArray: false }, (err, result) => {
        if (err) {
          reject(err);
          return;
        }

        try {
          const channel = result?.rss?.channel;
          if (!channel) {
            resolve([]);
            return;
          }

          let items = channel.item || [];
          if (!Array.isArray(items)) items = [items];

          const episodes = items.slice(0, maxEpisodes).map(item => ({
            id: item.guid?._ || item.guid || Math.random().toString(36),
            title: item.title || 'Unknown Episode',
            description: (item.description || '').replace(/<[^>]*>/g, '').substring(0, 500),
            audioUrl: item.enclosure?.$.url || item.enclosure?.url || '',
            duration: parseDuration(item['itunes:duration'] || ''),
            publishDate: item.pubDate ? new Date(item.pubDate).getTime() / 1000 : 0,
            thumbnail: (item['itunes:image'] && item['itunes:image'].$ && item['itunes:image'].$.href) || (item['itunes:image'] && item['itunes:image'].href) || '',
            podcastTitle: channel.title || '',
            podcastAuthor: channel.author || channel['itunes:author'] || '',
          }));

          resolve(episodes);
        } catch (parseErr) {
          reject(parseErr);
        }
      });
    });
  } catch (err) {
    logger.error({ err, feedUrl }, 'RSS feed parse error');
    return [];
  }
}

function parseDuration(str) {
  if (!str) return 0;
  const parts = str.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return parseInt(str, 10) || 0;
}
