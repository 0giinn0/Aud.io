import rateLimit from 'express-rate-limit';
import config from '../config.js';

export default rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  // Players issue a burst of Range requests while buffering/seeking;
  // rate-limiting the audio proxy would stall playback mid-track.
  skip: (req) => req.path.endsWith('/audio'),
  message: { error: true, message: 'Too many requests — slow down, turbo' },
});
