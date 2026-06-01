'use strict';

const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis').default || require('rate-limit-redis');
const { cache } = require('../models/redis');
const logger = require('../utils/logger');

// ── Shared options ─────────────────────────────────────────────
const sharedOptions = {
  standardHeaders: true,   // Return RateLimit-* headers
  legacyHeaders:   false,  // Disable X-RateLimit-* headers
  keyGenerator: (req) => {
    // Prefer API key over IP
    return req.user?.apiKey || req.ip;
  },
  handler: (req, res) => {
    logger.warn('[RateLimit] Limit exceeded', {
      key:      req.user?.apiKey || req.ip,
      endpoint: req.path,
      method:   req.method,
    });

    // Record violation
    const db = require('../models/db');
    db.query(
      `INSERT INTO rate_limit_violations (identifier, endpoint, request_count)
       VALUES ($1, $2, $3)`,
      [req.user?.apiKey || req.ip, req.path, req.rateLimit?.totalHits]
    ).catch(() => {}); // fire-and-forget

    res.status(429).json({
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please slow down.',
      retryAfter: req.rateLimit?.resetTime,
    });
  },
};

// ── Create a Redis-backed store ────────────────────────────────
function makeStore(prefix) {
  return new RedisStore({
    sendCommand: async (...args) => {
      const client = cache.getClient();
      if (!client) throw new Error('Redis not connected');
      return client.sendCommand(args);
    },
    prefix: `rl:${prefix}:`,
  });
}

// ── Rate Limiters ──────────────────────────────────────────────

/**
 * Global API rate limiter (100 req/min by default)
 */
const globalLimiter = rateLimit({
  ...sharedOptions,
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000'),
  max:      parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  store:    makeStore('global'),
  message:  'Too many requests from this IP, please try again in a minute.',
});

/**
 * Strict limiter for URL creation (20/min for free, 200/min for pro)
 */
const createUrlLimiter = rateLimit({
  ...sharedOptions,
  windowMs: 60_000,
  max: (req) => {
    if (req.user?.plan === 'enterprise') return 1000;
    if (req.user?.plan === 'pro')        return 200;
    return 20; // free
  },
  store: makeStore('create'),
});

/**
 * Auth limiter — very strict to prevent brute force
 */
const authLimiter = rateLimit({
  ...sharedOptions,
  windowMs: 15 * 60_000, // 15 minutes
  max:      10,
  store:    makeStore('auth'),
  skipSuccessfulRequests: true,
});

/**
 * Redirect limiter — generous, 1000/min per IP
 */
const redirectLimiter = rateLimit({
  ...sharedOptions,
  windowMs: 60_000,
  max:      1000,
  store:    makeStore('redirect'),
  skip: (req) => {
    // Skip bots / health checks
    const ua = req.headers['user-agent'] || '';
    return ua.includes('Googlebot') || ua.includes('kube-probe');
  },
});

/**
 * Analytics read limiter
 */
const analyticsLimiter = rateLimit({
  ...sharedOptions,
  windowMs: 60_000,
  max:      60,
  store:    makeStore('analytics'),
});

/**
 * Password-protected URL check — prevent brute force
 */
const passwordCheckLimiter = rateLimit({
  ...sharedOptions,
  windowMs: 5 * 60_000,
  max:      5,
  store:    makeStore('pw-check'),
  keyGenerator: (req) => `${req.ip}:${req.params.code}`,
});

module.exports = {
  globalLimiter,
  createUrlLimiter,
  authLimiter,
  redirectLimiter,
  analyticsLimiter,
  passwordCheckLimiter,
};
