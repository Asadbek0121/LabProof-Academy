'use strict';

require('dotenv').config();

const express      = require('express');
const helmet       = require('helmet');
const cors         = require('cors');
const compression  = require('compression');
const morgan       = require('morgan');
const cron         = require('node-cron');

const logger       = require('./utils/logger');
const db           = require('./models/db');
const { connect: connectRedis } = require('./models/redis');
const analyticsService = require('./services/analyticsService');
const { metricsMiddleware, metricsHandler } = require('./services/metricsService');

const authRoutes     = require('./routes/auth');
const urlRoutes      = require('./routes/urls');
const redirectRouter = require('./routes/redirect');
const { globalLimiter } = require('./middleware/rateLimiter');

const app  = express();
const PORT = parseInt(process.env.PORT || '3000');
const HOST = process.env.HOST || '0.0.0.0';

// ── Trust proxy (Kubernetes/Nginx) ────────────────────────────
app.set('trust proxy', parseInt(process.env.TRUST_PROXY || '1'));

// ── Security middleware ───────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:  ["'self'"],
      scriptSrc:   ["'self'"],
      styleSrc:    ["'self'", "'unsafe-inline'"],
      imgSrc:      ["'self'", 'data:', 'https:'],
      connectSrc:  ["'self'"],
      frameAncestors: ["'none'"],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
}));

app.use(cors({
  origin: (origin, cb) => {
    const allowed = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
    if (!origin || !allowed.length || allowed.includes(origin) || allowed.includes('*')) {
      cb(null, true);
    } else {
      cb(new Error(`CORS: origin ${origin} not allowed`));
    }
  },
  credentials: true,
  methods:     ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key', 'X-Metrics-Token'],
}));

app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ── Logging ───────────────────────────────────────────────────
app.use(morgan('combined', {
  stream: { write: (msg) => logger.http(msg.trim()) },
  skip: (req) => req.path === '/health' || req.path === '/readyz',
}));

// ── Prometheus metrics ────────────────────────────────────────
app.use(metricsMiddleware);
if (process.env.METRICS_ENABLED !== 'false') {
  app.get(process.env.METRICS_PATH || '/metrics', metricsHandler);
}

// ── Global rate limiter ───────────────────────────────────────
app.use('/api', globalLimiter);

// ── Health probes (Kubernetes liveness/readiness) ─────────────
app.get('/health', async (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/readyz', async (req, res) => {
  const [dbHealth, redisOk] = await Promise.allSettled([
    db.healthCheck(),
    require('./models/redis').cache.healthCheck(),
  ]);

  const healthy =
    dbHealth.status  === 'fulfilled' && dbHealth.value.write &&
    redisOk.status   === 'fulfilled' && redisOk.value;

  res.status(healthy ? 200 : 503).json({
    status:  healthy ? 'ready' : 'not ready',
    db:      dbHealth.value  || false,
    redis:   redisOk.value   || false,
  });
});

// ── API Routes ────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/urls', urlRoutes);

// ── Redirect route (must be last, catches all /:code) ─────────
app.use('/', redirectRouter);

// ── 404 handler ───────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ── Global error handler ──────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error('[Server] Unhandled error', {
    error:  err.message,
    stack:  err.stack,
    path:   req.path,
    method: req.method,
  });

  if (err.message.includes('CORS')) {
    return res.status(403).json({ error: err.message });
  }

  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// ── Startup ───────────────────────────────────────────────────
async function start() {
  try {
    // Connect to Redis
    await connectRedis();
    logger.info('[Server] Redis connected');

    // Verify DB connectivity
    const dbStatus = await db.healthCheck();
    if (!dbStatus.write) throw new Error('Database not reachable');
    logger.info('[Server] Database connected', dbStatus);

    // Start analytics flush timer
    analyticsService.startFlushTimer();

    // Cron: refresh materialized view every 5 minutes
    cron.schedule('*/5 * * * *', async () => {
      await db.query('SELECT refresh_dashboard_stats()').catch(err =>
        logger.error('[Cron] Dashboard stats refresh failed', { error: err.message })
      );
    });

    // Cron: create next month's analytics partition on the 25th of each month
    cron.schedule('0 2 25 * *', async () => {
      const nextMonth = new Date();
      nextMonth.setMonth(nextMonth.getMonth() + 2);
      nextMonth.setDate(1);
      const partName = `analytics_${nextMonth.getFullYear()}_${String(nextMonth.getMonth() + 1).padStart(2, '0')}`;
      const from     = nextMonth.toISOString().slice(0, 10);
      const to       = new Date(nextMonth.getFullYear(), nextMonth.getMonth() + 1, 1).toISOString().slice(0, 10);
      await db.query(
        `CREATE TABLE IF NOT EXISTS ${partName} PARTITION OF analytics FOR VALUES FROM ('${from}') TO ('${to}')`
      ).catch(err => logger.error('[Cron] Partition creation failed', { error: err.message }));
    });

    // Start listening
    const server = app.listen(PORT, HOST, () => {
      logger.info(`[Server] Listening on ${HOST}:${PORT} (${process.env.NODE_ENV || 'development'})`);
    });

    // Graceful shutdown
    const shutdown = async (signal) => {
      logger.info(`[Server] ${signal} received — shutting down gracefully`);
      server.close(async () => {
        await analyticsService.stopFlushTimer();
        await db.close();
        await require('./models/redis').cache.close();
        logger.info('[Server] Shutdown complete');
        process.exit(0);
      });
      setTimeout(() => {
        logger.error('[Server] Forced shutdown after timeout');
        process.exit(1);
      }, 15000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT',  () => shutdown('SIGINT'));

    process.on('unhandledRejection', (reason) => {
      logger.error('[Server] Unhandled rejection', { reason: String(reason) });
    });
    process.on('uncaughtException', (err) => {
      logger.error('[Server] Uncaught exception', { error: err.message, stack: err.stack });
      process.exit(1);
    });

    return server;
  } catch (err) {
    logger.error('[Server] Failed to start', { error: err.message });
    process.exit(1);
  }
}

start();

module.exports = app; // for testing
