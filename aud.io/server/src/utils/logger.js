import pino from 'pino';
import config from '../config.js';

export default pino({
  level: config.isDev ? 'debug' : 'info',
  transport: config.isDev ? { target: 'pino-pretty', options: { colorize: true } } : undefined,
});
