'use strict';

const winston = require('winston');
const { combine, timestamp, json, colorize, printf, errors } = winston.format;

const isDev = process.env.NODE_ENV !== 'production';

const devFormat = printf(({ level, message, timestamp, ...meta }) => {
  const metaStr = Object.keys(meta).length > 0 ? ' ' + JSON.stringify(meta) : '';
  return `[${timestamp}] ${level.toUpperCase()}: ${message}${metaStr}`;
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  defaultMeta: { service: 'url-shortener' },
  format: combine(
    errors({ stack: true }),
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
    isDev ? combine(colorize(), devFormat) : json(),
  ),
  transports: [
    new winston.transports.Console({ handleExceptions: true }),
    ...(process.env.NODE_ENV === 'production' ? [
      new winston.transports.File({
        filename: 'logs/error.log',
        level: 'error',
        maxsize: 50 * 1024 * 1024, // 50MB
        maxFiles: 10,
        tailable: true,
      }),
      new winston.transports.File({
        filename: 'logs/combined.log',
        maxsize: 100 * 1024 * 1024, // 100MB
        maxFiles: 5,
        tailable: true,
      }),
    ] : []),
  ],
  exitOnError: false,
});

module.exports = logger;
