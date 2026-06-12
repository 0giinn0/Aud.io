import axios from 'axios';
import logger from '../utils/logger.js';

const LASTFM_API = 'https://ws.audioscrobbler.com/2.0/';
const LASTFM_API_KEY = process.env.LASTFM_API_KEY || 'MISSING_KEY';

/**
 * Search for artists on Last.fm
 * Note: Last.fm requires a FREE API key from https://www.last.fm/api/account/create
 * Set LASTFM_API_KEY in .env or Render dashboard
 * @param {string} query - artist name
 * @param {number} max - max results
 * @returns {Promise<Array>} array of artist objects
 */
export async function searchArtists(query, max = 20) {
  if (LASTFM_API_KEY === 'MISSING_KEY') {
    logger.warn('LASTFM_API_KEY not set; skipping Last.fm search');
    return [];
  }

  try {
    const response = await axios.get(LASTFM_API, {
      params: {
        method: 'artist.search',
        artist: query,
        api_key: LASTFM_API_KEY,
        format: 'json',
        limit: Math.min(max, 30),
      },
      timeout: 10000,
    });

    if (!response.data.results || !response.data.results.artistmatches) return [];

    return response.data.results.artistmatches.artist.map((artist) => ({
      id: `lastfm_${artist.name.toLowerCase().replace(/\s+/g, '_')}`,
      name: artist.name,
      image: artist.image?.[2]?.['#text'] || artist.image?.[1]?.['#text'] || null,
      source: 'lastfm',
      mbid: artist.mbid || null,
      link: artist.url || null,
      listeners: artist.listeners || 0,
    }));
  } catch (error) {
    logger.error({ error: error.message, query }, 'Last.fm search failed');
    throw new Error(`Last.fm search error: ${error.message}`);
  }
}

/**
 * Get trending artists globally on Last.fm
 * @param {number} max - max results
 * @returns {Promise<Array>} array of artist objects
 */
export async function getTrendingArtists(max = 20) {
  if (LASTFM_API_KEY === 'MISSING_KEY') {
    logger.warn('LASTFM_API_KEY not set; skipping Last.fm trending');
    return [];
  }

  try {
    const response = await axios.get(LASTFM_API, {
      params: {
        method: 'chart.gettopartists',
        api_key: LASTFM_API_KEY,
        format: 'json',
        limit: Math.min(max, 50),
        period: '7day', // Last 7 days trending
      },
      timeout: 10000,
    });

    if (!response.data.artists) return [];

    return response.data.artists.artist.map((artist) => ({
      id: `lastfm_${artist.name.toLowerCase().replace(/\s+/g, '_')}`,
      name: artist.name,
      image: artist.image?.[2]?.['#text'] || artist.image?.[1]?.['#text'] || null,
      source: 'lastfm',
      mbid: artist.mbid || null,
      link: artist.url || null,
      playcount: parseInt(artist.playcount, 10) || 0,
      listeners: parseInt(artist.listeners, 10) || 0,
      rank: parseInt(artist['@attr']?.rank, 10) || 0,
    }));
  } catch (error) {
    logger.error({ error: error.message }, 'Last.fm trending failed');
    throw new Error(`Last.fm trending error: ${error.message}`);
  }
}

/**
 * Get artist info (bio, similar artists, etc)
 * @param {string} artistName - artist name
 * @returns {Promise<Object>} artist details
 */
export async function getArtistInfo(artistName) {
  if (LASTFM_API_KEY === 'MISSING_KEY') {
    logger.warn('LASTFM_API_KEY not set; skipping Last.fm artist info');
    return null;
  }

  try {
    const response = await axios.get(LASTFM_API, {
      params: {
        method: 'artist.getinfo',
        artist: artistName,
        api_key: LASTFM_API_KEY,
        format: 'json',
        autocorrect: 1,
      },
      timeout: 10000,
    });

    if (!response.data.artist) return null;

    const artist = response.data.artist;
    return {
      name: artist.name,
      bio: artist.bio?.summary || null,
      image: artist.image?.[3]?.['#text'] || artist.image?.[2]?.['#text'] || null,
      listeners: parseInt(artist.listeners, 10) || 0,
      playcount: parseInt(artist.playcount, 10) || 0,
      link: artist.url || null,
      mbid: artist.mbid || null,
    };
  } catch (error) {
    logger.error({ error: error.message, artistName }, 'Last.fm artist info failed');
    return null;
  }
}
