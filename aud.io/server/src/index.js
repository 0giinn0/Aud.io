import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import config from './config.js';
import logger from './utils/logger.js';
import rateLimiter from './middleware/rateLimiter.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import apiRouter from './routes/api.js';
import healthRouter from './routes/health.js';

const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    const allowed =
      /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin) ||
      /^https?:\/\/.*\.onrender\.com$/.test(origin);
    callback(allowed ? null : new Error('CORS blocked'), allowed);
  },
  methods: ['GET', 'POST'],
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

app.use('/api', apiRouter);
app.use('/health', healthRouter);

app.use(notFound);
app.use(errorHandler);

app.listen(config.port, () => {
  logger.info(`aud.io-server running on http://localhost:${config.port}`);
  logger.info(`Environment: ${config.nodeEnv}`);
});
