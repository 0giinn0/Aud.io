import dotenv from 'dotenv';
dotenv.config();

export default {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '60', 10),
  },
  cache: {
    ttl: parseInt(process.env.CACHE_TTL || '300', 10),
  },
  soundcloud: {
    clientId: process.env.SOUNDCLOUD_CLIENT_ID || '',
  },
  podcast: {
    apiKey: process.env.PODCAST_INDEX_API_KEY || '',
    apiSecret: process.env.PODCAST_INDEX_API_SECRET || '',
    userAgent: process.env.PODCAST_INDEX_USER_AGENT || 'aud.io/1.0',
  },
  isDev: (process.env.NODE_ENV || 'development') === 'development',
};
