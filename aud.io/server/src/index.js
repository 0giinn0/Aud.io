import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { execSync } from 'child_process';
import config from './config.js';
import logger from './utils/logger.js';
import rateLimiter from './middleware/rateLimiter.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import apiRouter from './routes/api.js';
import healthRouter from './routes/health.js';

const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

// Extra origins (e.g. a custom domain) can be added via ALLOWED_ORIGINS,
// a comma-separated list. localhost, *.onrender.com, *.netlify.app and
// *.pages.dev (Cloudflare) are always allowed.
const extraOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

function isAllowedOrigin(origin) {
  return (
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin) ||
    /^https?:\/\/([a-z0-9-]+\.)*onrender\.com$/.test(origin) ||
    /^https?:\/\/([a-z0-9-]+\.)*netlify\.app$/.test(origin) ||
    /^https?:\/\/([a-z0-9-]+\.)*pages\.dev$/.test(origin) ||
    extraOrigins.includes(origin)
  );
}

app.use(cors({
  origin: (origin, callback) => {
    // No Origin header => non-browser client (mobile app, curl); allow.
    if (!origin) return callback(null, true);
    // Returning false (not an Error) omits CORS headers without throwing a
    // 500, so disallowed browsers get a clean CORS rejection.
    callback(null, isAllowedOrigin(origin));
  },
  methods: ['GET', 'POST', 'OPTIONS'],
}));

app.use(express.json());
app.use(rateLimiter);

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    logger.debug({ method: req.method, path: req.path, status: res.statusCode, ms: Date.now() - start });
  });
  next();
});

app.get('/', (req, res) => {
  res.json({ service: 'aud.io-server', status: 'running' });
});

app.use('/api', apiRouter);
app.use('/health', healthRouter);

app.use(notFound);
app.use(errorHandler);

app.listen(config.port, () => {
  logger.info(`aud.io-server running on http://localhost:${config.port}`);
  logger.info(`Environment: ${config.nodeEnv}`);
  try {
    const ytver = execSync('yt-dlp --version', { encoding: 'utf8', timeout: 5000 }).trim();
    logger.info(`yt-dlp version: ${ytver}`);
  } catch (err) {
    logger.error({ err: err.message }, 'yt-dlp check failed — install may be broken');
  }
});
