import NodeCache from 'node-cache';
import config from '../config.js';

const cache = new NodeCache({ stdTTL: config.cache.ttl, checkperiod: 60 });

export function cacheMiddleware(duration) {
  return (req, res, next) => {
    const key = `${req.path}${JSON.stringify(req.query)}`;
    const cached = cache.get(key);
    if (cached) {
      res.json(cached);
      return;
    }
    res.locals.cacheKey = key;
    res.locals.cacheDuration = duration || config.cache.ttl;
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode < 400) {
        cache.set(key, body, res.locals.cacheDuration);
      }
      originalJson(body);
    };
    next();
  };
}

export function invalidateCache(pattern) {
  const keys = cache.keys().filter((k) => k.startsWith(pattern));
  keys.forEach((k) => cache.del(k));
}
