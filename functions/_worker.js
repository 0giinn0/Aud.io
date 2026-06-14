// Cloudflare Worker — replaces the entire Render server.
// Serves from the same domain as the Flutter web app (no CORS issues).

const INNERTUBE_API_KEY = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
const INNERTUBE_BASE = 'https://www.youtube.com/youtubei/v1';
const SOUNDCLOUD_API = 'https://api-v2.soundcloud.com';
const PODCAST_INDEX_BASE = 'https://api.podcastindex.org/api/1.0';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // ── Router ──
    if (path === '/health') {
      return json({ status: 'ok', service: 'aud.io worker', timestamp: Date.now() });
    }

    if (path === '/api/proxy') {
      return handleProxy(url, request);
    }

    if (path === '/api/proxy-image') {
      return handleProxyImage(url);
    }

    if (path === '/api/yt-proxy') {
      return handleYouTubeProxy(url, request);
    }

    if (path === '/api/search') {
      return handleSoundCloudSearch(url);
    }

    const streamMatch = path.match(/^\/api\/stream\/([^/]+)\/audio$/);
    if (streamMatch) {
      return handleSoundCloudStream(streamMatch[1], url);
    }

    if (path === '/api/podcasts/search') return handlePodcastSearch(url, env);
    if (path === '/api/podcasts/trending') return handlePodcastTrending(url, env);

    const feedMatch = path.match(/^\/api\/podcasts\/feed$/);
    if (feedMatch) return handlePodcastFeed(url);

    const podcastDetailMatch = path.match(/^\/api\/podcasts\/podcast\/([^/]+)$/);
    if (podcastDetailMatch) return handlePodcastDetail(podcastDetailMatch[1], url, env);

    return new Response('Not Found', { status: 404 });
  },
};

// ── Helpers ──

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json',
      'access-control-allow-origin': '*',
      'cache-control': 'no-store',
    },
  });
}

function userAgent() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 20000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(url, { ...options, signal: controller.signal });
    return resp;
  } finally {
    clearTimeout(id);
  }
}

// ── Generic Proxy ──

async function handleProxy(url, request) {
  const target = url.searchParams.get('url');
  if (!target || !/^https?:\/\//i.test(target)) {
    return json({ error: true, message: 'Missing or invalid ?url=' }, 400);
  }
  try {
    const headers = {
      'User-Agent': userAgent(),
    };
    const range = request.headers.get('range');
    if (range) headers['Range'] = range;

    const upstream = await fetchWithTimeout(target, { headers }, 30000);
    if (upstream.status >= 400) {
      return json({ error: true, message: 'Upstream error' }, upstream.status);
    }

    const respHeaders = new Headers({
      'access-control-allow-origin': '*',
      'cache-control': 'no-store',
    });
    for (const h of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      const val = upstream.headers.get(h);
      if (val) respHeaders.set(h, val);
    }
    if (!respHeaders.has('accept-ranges')) respHeaders.set('accept-ranges', 'bytes');

    return new Response(upstream.body, {
      status: upstream.status,
      headers: respHeaders,
    });
  } catch (err) {
    return json({ error: true, message: 'Proxy failed' }, 502);
  }
}

// ── Image Proxy ──

async function handleProxyImage(url) {
  let target = url.searchParams.get('url');
  if (!target || !/^https?:\/\//i.test(target)) {
    return json({ error: true, message: 'Missing or invalid ?url=' }, 400);
  }
  target = target.replace(/^http:/i, 'https:');
  try {
    const upstream = await fetchWithTimeout(target, {
      headers: { 'User-Agent': userAgent() },
    }, 10000);
    if (upstream.status >= 400) {
      return new Response(null, { status: upstream.status });
    }
    const respHeaders = new Headers({
      'access-control-allow-origin': '*',
      'cache-control': 'public, max-age=86400',
    });
    const ct = upstream.headers.get('content-type');
    if (ct) respHeaders.set('content-type', ct);
    return new Response(upstream.body, { headers: respHeaders });
  } catch {
    return new Response(null, { status: 502 });
  }
}

// ── YouTube Audio Proxy ──
// Calls InnerTube player API, extracts audio stream URL, proxies the bytes.

async function handleYouTubeProxy(url, request) {
  const videoId = url.searchParams.get('videoId');
  if (!videoId || !/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
    return json({ error: true, message: 'Missing or invalid ?videoId=' }, 400);
  }

  try {
    const playerResp = await fetchWithTimeout(
      `${INNERTUBE_BASE}/player?key=${INNERTUBE_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          videoId,
          context: {
            client: {
              clientName: 'ANDROID',
              clientVersion: '19.09.37',
              androidSdkVersion: 30,
            },
          },
        }),
      },
      15000,
    );

    if (!playerResp.ok) {
      return json({ error: true, message: 'InnerTube error' }, 502);
    }

    const data = await playerResp.json();
    const formats = data.streamingData?.adaptiveFormats ?? [];

    // Find audio-only format with a direct URL (no signatureCipher).
    const audioFormat = formats.find(
      (f) => f.url && !f.signatureCipher && !f.cipher && f.mimeType?.startsWith('audio'),
    ) || formats.find(
      (f) => f.url && !f.signatureCipher && !f.cipher,
    );

    if (!audioFormat?.url) {
      return json({ error: true, message: 'No playable audio format found' }, 502);
    }

    // Proxy the audio bytes
    const range = request.headers.get('range');
    const proxyHeaders = { 'User-Agent': userAgent() };
    if (range) proxyHeaders['Range'] = range;

    const upstream = await fetchWithTimeout(audioFormat.url, { headers: proxyHeaders }, 60000);
    if (upstream.status >= 400) {
      return json({ error: true, message: 'Stream fetch failed' }, upstream.status);
    }

    const respHeaders = new Headers({ 'access-control-allow-origin': '*', 'cache-control': 'no-store' });
    for (const h of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      const val = upstream.headers.get(h);
      if (val) respHeaders.set(h, val);
    }
    return new Response(upstream.body, { status: upstream.status, headers: respHeaders });
  } catch (err) {
    return json({ error: true, message: 'YouTube proxy failed: ' + err.message }, 502);
  }
}

// ── SoundCloud ──

let _scClientId = null;
let _scClientIdExpiry = 0;

async function getSoundCloudClientId() {
  if (_scClientId && Date.now() < _scClientIdExpiry) return _scClientId;
  try {
    const resp = await fetchWithTimeout('https://soundcloud.com', {
      headers: { 'User-Agent': userAgent() },
    }, 10000);
    const html = await resp.text();
    const match = html.match(/"clientId":"([^"]+)"/);
    if (match) {
      _scClientId = match[1];
      _scClientIdExpiry = Date.now() + 3600000; // 1hr cache
      return _scClientId;
    }
  } catch {}
  // Fallback: common known client ID
  return 'a3e059563d7fd3372b49b37f00a00bcf';
}

async function handleSoundCloudSearch(url) {
  const query = url.searchParams.get('q')?.trim();
  const max = Math.min(parseInt(url.searchParams.get('max') || '20', 10), 50);
  if (!query) return json({ error: true, message: 'Missing ?q=' }, 400);

  try {
    const clientId = await getSoundCloudClientId();
    const resp = await fetchWithTimeout(
      `${SOUNDCLOUD_API}/search/tracks?q=${encodeURIComponent(query)}&limit=${max}&client_id=${clientId}`,
      { headers: { 'User-Agent': userAgent() } },
      15000,
    );
    if (!resp.ok) return json({ results: [], total: 0 });

    const data = await resp.json();
    const results = (data.collection ?? []).map((t) => ({
      id: t.id?.toString(),
      title: t.title,
      artist: t.user?.username || 'Unknown',
      artistUrl: t.user?.permalink_url || null,
      artworkUrl: t.artwork_url || t.user?.avatar_url || null,
      duration: Math.floor((t.duration ?? 0) / 1000),
      source: 'soundcloud',
    }));

    return json({ results, total: results.length });
  } catch {
    return json({ results: [], total: 0 });
  }
}

async function handleSoundCloudStream(trackId, url) {
  const source = url.searchParams.get('source') || '';
  if (source !== 'soundcloud') {
    return json({ error: true, message: 'Only ?source=soundcloud supported' }, 400);
  }

  try {
    const clientId = await getSoundCloudClientId();
    const resp = await fetchWithTimeout(
      `${SOUNDCLOUD_API}/tracks/${trackId}/streams?client_id=${clientId}`,
      { headers: { 'User-Agent': userAgent() } },
      15000,
    );
    if (!resp.ok) return json({ error: true, message: 'Track not found' }, 404);

    const data = await resp.json();
    // Prefer progressive HTTP MP3, skip HLS (no ffmpeg in Workers)
    const progressive = data.http_mp3_128_url || data.http_mp3_64_url || data.progressive;
    if (!progressive) return json({ error: true, message: 'No progressive stream available' }, 404);

    // Resolve the signed URL
    const resolveResp = await fetchWithTimeout(progressive, {
      method: 'HEAD',
      redirect: 'manual',
    }, 10000);

    const location = resolveResp.headers.get('location') || progressive;
    return json({ url: location });
  } catch {
    return json({ error: true, message: 'Failed to resolve stream' }, 502);
  }
}

// ── Podcast Index API ──

function podcastIndexAuth(env) {
  const apiKey = env.PODCAST_INDEX_API_KEY || '';
  const apiSecret = env.PODCAST_INDEX_API_SECRET || '';
  const apiHeaderTime = Math.floor(Date.now() / 1000).toString();
  const toSign = apiKey + apiSecret + apiHeaderTime;
  const hash = crypto.subtle ? null : null; // simplified — see below

  // Use Web Crypto API for SHA1
  const encoder = new TextEncoder();
  const data = encoder.encode(toSign);
  // Return headers synchronously; auth will be resolved in the caller
  return { apiKey, apiHeaderTime, data };
}

async function podcastIndexFetch(path, env) {
  const apiKey = env.PODCAST_INDEX_API_KEY || '';
  const apiSecret = env.PODCAST_INDEX_API_SECRET || '';
  const apiHeaderTime = Math.floor(Date.now() / 1000).toString();
  const toSign = apiKey + apiSecret + apiHeaderTime;
  const encoder = new TextEncoder();
  const hashBuffer = await crypto.subtle.digest('SHA-1', encoder.encode(toSign));
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hash = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');

  const url = `${PODCAST_INDEX_BASE}${path}`;
  const resp = await fetchWithTimeout(url, {
    headers: {
      'User-Agent': 'aud.io/1.0',
      'X-Auth-Key': apiKey,
      'X-Auth-Date': apiHeaderTime,
      'Authorization': hash,
    },
  }, 15000);
  return resp;
}

async function handlePodcastSearch(url, env) {
  const query = url.searchParams.get('q')?.trim();
  const max = Math.min(parseInt(url.searchParams.get('max') || '10', 10), 50);
  if (!query) return json({ error: true, message: 'Missing ?q=' }, 400);

  try {
    const resp = await podcastIndexFetch(`/search/byterm?q=${encodeURIComponent(query)}&max=${max}`, env);
    if (!resp.ok) return json({ results: [] });

    const data = await resp.json();
    const results = (data.feeds ?? []).map((f) => ({
      id: f.id?.toString(),
      title: f.title || f.name || 'Unknown',
      author: f.author || f.publisher || '',
      description: f.description,
      image: f.image || f.artwork,
      feedUrl: f.url || f.feedUrl,
      episodeCount: f.episodeCount || f.total_episodes || 0,
    }));
    return json({ results, total: results.length });
  } catch {
    return json({ results: [] });
  }
}

async function handlePodcastTrending(url, env) {
  const max = Math.min(parseInt(url.searchParams.get('max') || '20', 10), 50);
  const lang = url.searchParams.get('lang') || 'en';

  try {
    const resp = await podcastIndexFetch(`/podcasts/trending?max=${max}&lang=${lang}`, env);
    if (!resp.ok) {
      // Trending requires auth; if no API key, try search as fallback
      return json({ results: [] });
    }
    const data = await resp.json();
    const results = (data.feeds ?? []).map((f) => ({
      id: f.id?.toString(),
      title: f.title || f.name || 'Unknown',
      author: f.author || f.publisher || '',
      description: f.description,
      image: f.image || f.artwork,
      feedUrl: f.url || f.feedUrl,
      episodeCount: f.episodeCount || f.total_episodes || 0,
    }));
    return json({ results, total: results.length });
  } catch {
    return json({ results: [] });
  }
}

async function handlePodcastFeed(url) {
  const feedUrl = url.searchParams.get('url');
  const max = Math.min(parseInt(url.searchParams.get('max') || '20', 10), 50);
  if (!feedUrl) return json({ error: true, message: 'Missing ?url=' }, 400);

  try {
    const resp = await fetchWithTimeout(feedUrl, {
      headers: { 'User-Agent': userAgent() },
    }, 15000);

    const xml = await resp.text();

    // Parse RSS/XML manually (no xml2js dependency)
    const episodes = parseRssEpisodes(xml, max);
    return json({ episodes, total: episodes.length });
  } catch {
    return json({ episodes: [], total: 0 });
  }
}

function parseRssEpisodes(xml, max) {
  const episodes = [];
  // Simple RSS item parser
  const itemRegex = /<item>([\s\S]*?)<\/item>/gi;
  let match;
  let count = 0;

  while ((match = itemRegex.exec(xml)) !== null && count < max) {
    const item = match[1];

    const getTag = (tag) => {
      const r = new RegExp(`<${tag}[^>]*>(.*?)<\/${tag}>`, 'is');
      const m = r.exec(item);
      return m ? m[1].trim() : '';
    };

    const title = getTag('title');
    const audioMatch = item.match(/<enclosure[^>]*url="([^"]+)"/i);
    const audioUrl = audioMatch ? audioMatch[1] : '';
    const description = stripHtml(getTag('description'));
    const pubDate = getTag('pubDate');
    const durationStr = getTag('itunes:duration');
    const imageMatch = getTag('itunes:image').match(/href="([^"]+)"/);
    const thumbnail = imageMatch ? imageMatch[1] : '';

    if (!title && !audioUrl) continue;

    episodes.push({
      id: `ep_${count}_${Date.now()}`,
      title: decodeHtmlEntities(title || 'Untitled'),
      artist: '',
      podcastTitle: '',
      podcastAuthor: '',
      thumbnail: thumbnail,
      audio: audioUrl,
      duration: parseDuration(durationStr),
      description: description,
      publishDate: parsePubDate(pubDate),
    });
    count++;
  }
  return episodes;
}

function stripHtml(str) {
  return str.replace(/<[^>]*>/g, '').trim();
}

function decodeHtmlEntities(str) {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&#x2F;/g, '/');
}

function parseDuration(str) {
  if (!str) return 0;
  const parts = str.split(':').map((p) => parseInt(p, 10)).filter((n) => !isNaN(n));
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  const num = parseInt(str, 10);
  return isNaN(num) ? 0 : num;
}

function parsePubDate(str) {
  if (!str) return 0;
  const d = new Date(str);
  return isNaN(d.getTime()) ? 0 : d.getTime();
}

async function handlePodcastDetail(podcastId, url, env) {
  const maxEpisodes = Math.min(parseInt(url.searchParams.get('episodes') || '10', 10), 50);

  try {
    const resp = await podcastIndexFetch(`/podcasts/byfeedid?id=${podcastId}&max=${maxEpisodes}`, env);
    if (!resp.ok) return json(null, 404);

    const data = await resp.json();
    const feed = data.feed;
    if (!feed) return json(null, 404);

    const episodes = (data.items ?? []).map((ep) => ({
      id: ep.id?.toString() || `ep_${Date.now()}`,
      title: ep.title || 'Untitled',
      artist: feed.author || '',
      podcastTitle: feed.title || '',
      podcastAuthor: feed.author || '',
      thumbnail: feed.image || feed.artwork || feed.podcastImage,
      audio: ep.enclosureUrl || ep.enclosure?.url || '',
      duration: ep.duration || ep.enclosureLength || 0,
      description: ep.description || '',
      publishDate: ep.datePublished || ep.datePublishedPretty || 0,
    }));

    return json({
      id: feed.id?.toString(),
      title: feed.title || 'Unknown',
      author: feed.author || '',
      description: feed.description,
      thumbnail: feed.image || feed.artwork,
      feedUrl: feed.url || feed.link,
      episodeCount: feed.episodeCount || episodes.length,
      episodes: episodes.slice(0, maxEpisodes),
    });
  } catch {
    return json(null, 502);
  }
}
