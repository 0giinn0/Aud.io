import rateLimit from 'express-rate-limit';
import config from '../config.js';

export default rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  // Players issue a burst of Range requests while buffering/seeking;
  // rate-limiting the audio proxy would stall playback mid-track.
  // Also skip the image proxy and generic proxy — they forward third-party
  // content and can't be stuffed without external agreement anyway.
  skip: (req) => req.path.endsWith('/audio') || req.path.includes('/proxy-image') || req.path.endsWith('/proxy'),
  message: { error: true, message: 'Too many requests — slow down, turbo' },
});
