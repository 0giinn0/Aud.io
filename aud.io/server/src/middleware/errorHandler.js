import logger from '../utils/logger.js';

export function errorHandler(err, req, res, _next) {
  logger.error({ err, path: req.path }, 'Unhandled error');
  const status = err.status || 500;
  res.status(status).json({
    error: true,
    message: status === 500 && !process.env.NODE_ENV === 'development'
      ? 'Internal server error'
      : err.message || 'Internal server error',
  });
}

export function notFound(req, res) {
  res.status(404).json({ error: true, message: `Not found: ${req.path}` });
}
