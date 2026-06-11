import logger from '../utils/logger.js';

const ARCHIVE_API = 'https://archive.org/advancedsearch.php';
const ARCHIVE_METADATA = 'https://archive.org/metadata';
const ARCHIVE_DOWNLOAD = 'https://archive.org/download';

/**
 * Search Free Music Archive (via archive.org)
 * FMA collection has 16,800+ Creative Commons licensed tracks
 */
export async function searchFMA(query, maxResults = 10) {
  try {
    const params = new URLSearchParams({
      q: `collection:freemusicarchive AND mediatype:audio AND (${query})`,
      fl: 'identifier,title,creator,licenseurl',
      output: 'json',
      rows: String(maxResults),
    });

    const resp = await fetch(`${ARCHIVE_API}?${params}`);
    if (!resp.ok) throw new Error(`Archive.org search failed: ${resp.status}`);

    const data = await resp.json();
    const docs = data.response?.docs || [];

    return docs
      .filter(d => d.identifier)
      .map(d => ({
        id: d.identifier,
        title: d.title || 'Unknown',
        artist: Array.isArray(d.creator) ? d.creator[0] : (d.creator || 'Unknown Artist'),
        album: d.title || '',
        source: 'fma',
        thumbnail: `https://archive.org/services/img/${d.identifier}`,
        license: d.licenseurl || '',
        duration: 0,
      }));
  } catch (err) {
    logger.error({ err, query }, 'FMA search error');
    return [];
  }
}

/**
 * Get streaming URL for an FMA track
 * Fetches metadata to find the first MP3 file
 */
export async function getFMAStreamUrl(identifier) {
  try {
    const resp = await fetch(`${ARCHIVE_METADATA}/${identifier}`);
    if (!resp.ok) throw new Error(`Metadata fetch failed: ${resp.status}`);

    const data = await resp.json();
    const mp3File = data.files?.find(f =>
      f.format?.includes('MP3') && f.name?.endsWith('.mp3')
    );

    if (!mp3File) {
      logger.warn({ identifier }, 'No MP3 found for FMA item');
      return null;
    }

    return `${ARCHIVE_DOWNLOAD}/${identifier}/${mp3File.name}`;
  } catch (err) {
    logger.error({ err, identifier }, 'FMA stream URL error');
    return null;
  }
}

/**
 * Get track details including artist credit and license info
 */
export async function getFMATrackDetails(identifier) {
  try {
    const resp = await fetch(`${ARCHIVE_METADATA}/${identifier}`);
    if (!resp.ok) return null;

    const data = await resp.json();
    const meta = data.metadata || {};
    const mp3File = data.files?.find(f =>
      f.format?.includes('MP3') && f.name?.endsWith('.mp3')
    );

    return {
      id: identifier,
      title: mp3File?.title || meta.title || 'Unknown',
      artist: mp3File?.artist || (Array.isArray(meta.creator) ? meta.creator[0] : meta.creator) || 'Unknown Artist',
      album: mp3File?.album || meta.title || '',
      genre: mp3File?.genre || '',
      license: meta.licenseurl || '',
      source: 'fma',
      thumbnail: `https://archive.org/services/img/${identifier}`,
      duration: mp3File?.length ? parseFloat(mp3File.length) : 0,
      streamUrl: mp3File ? `${ARCHIVE_DOWNLOAD}/${identifier}/${mp3File.name}` : null,
    };
  } catch (err) {
    logger.error({ err, identifier }, 'FMA track details error');
    return null;
  }
}
