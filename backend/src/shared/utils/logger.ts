import pino from 'pino';
import { env } from '../../config/env.js';

export const logger = pino({
  level: env.LOG_LEVEL || 'info',
  redact: {
    paths: [
      'req.headers.authorization',
      'password',
      'passwordHash',
      'refreshToken',
      'token',
    ],
    censor: '[REDACTED]'
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
