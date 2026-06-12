import axios from 'axios';
import logger from '../utils/logger.js';

const ITUNES_API = 'https://itunes.apple.com/search';

/**
 * Search for artists on iTunes
 * @param {string} query - artist name or search term
 * @param {number} max - max results (1-200, default 20)
 * @returns {Promise<Array>} array of artist objects
 */
export async function searchArtists(query, max = 20) {
  try {
    const response = await axios.get(ITUNES_API, {
      params: {
        term: query,
        entity: 'musicArtist',
        limit: Math.min(max, 200),
        media: 'music',
      },
      timeout: 10000,
    });

    if (!response.data.results) return [];

    return response.data.results.map((result) => ({
      id: `itunes_${result.artistId}`,
      name: result.artistName,
      image: result.artworkUrl100 || result.artworkUrl60 || null,
      source: 'itunes',
      genre: result.primaryGenreName || null,
      link: result.artistLinkUrl || null,
      artistId: result.artistId,
    }));
  } catch (error) {
    logger.error({ error: error.message, query }, 'iTunes search failed');
    throw new Error(`iTunes search error: ${error.message}`);
  }
}

/**
 * Get top tracks by an artist (iTunes)
 * @param {number} artistId - iTunes artist ID
 * @param {number} max - max results
 * @returns {Promise<Array>} array of track objects
 */
export async function getArtistTracks(artistId, max = 20) {
  try {
    const response = await axios.get(ITUNES_API, {
      params: {
        term: artistId,
        entity: 'song',
        attribute: 'artistTerm',
        limit: Math.min(max, 200),
        media: 'music',
      },
      timeout: 10000,
    });

    if (!response.data.results) return [];

    return response.data.results
      .filter((t) => t.kind === 'song')
      .map((track) => ({
        id: `itunes_${track.trackId}`,
        title: track.trackName,
        artist: track.artistName,
        duration: track.trackTimeMillis / 1000,
        image: track.artworkUrl100 || null,
        source: 'itunes',
        previewUrl: track.previewUrl || null,
        link: track.trackViewUrl || null,
      }));
  } catch (error) {
    logger.error({ error: error.message, artistId }, 'iTunes get artist tracks failed');
    throw new Error(`iTunes get tracks error: ${error.message}`);
  }
}
