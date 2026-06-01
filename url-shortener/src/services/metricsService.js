'use strict';

const client = require('prom-client');

// Enable default metrics (GC, event loop, process, memory)
const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: 'urlshortener_' });

// ── Custom Metrics ──────────────────────────────────────────────

const urlsCreatedTotal = new client.Counter({
  name: 'urlshortener_urls_created_total',
  help: 'Total number of short URLs created',
  labelNames: ['plan', 'is_custom'],
  registers: [register],
});

const redirectsTotal = new client.Counter({
  name: 'urlshortener_redirects_total',
  help: 'Total number of redirects served',
  labelNames: ['status'],  // 'success' | 'not_found' | 'expired' | 'max_clicks'
  registers: [register],
});

const redirectLatency = new client.Histogram({
  name: 'urlshortener_redirect_latency_ms',
  help: 'Redirect latency in milliseconds',
  buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000],
  registers: [register],
});

const apiRequestDuration = new client.Histogram({
  name: 'urlshortener_api_request_duration_ms',
  help: 'API request duration in milliseconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [5, 10, 25, 50, 100, 250, 500, 1000, 2500],
  registers: [register],
});

const rateLimitHits = new client.Counter({
  name: 'urlshortener_rate_limit_hits_total',
  help: 'Total number of rate limit violations',
  labelNames: ['endpoint'],
  registers: [register],
});

const cacheHits = new client.Counter({
  name: 'urlshortener_cache_hits_total',
  help: 'Cache hit/miss counter',
  labelNames: ['type'],  // 'hit' | 'miss'
  registers: [register],
});

const dbQueryDuration = new client.Histogram({
  name: 'urlshortener_db_query_duration_ms',
  help: 'Database query duration in milliseconds',
  labelNames: ['type'],  // 'read' | 'write'
  buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000],
  registers: [register],
});

const activeUrlsGauge = new client.Gauge({
  name: 'urlshortener_active_urls_total',
  help: 'Total number of active URLs',
  registers: [register],
});

const analyticsBufferSize = new client.Gauge({
  name: 'urlshortener_analytics_buffer_size',
  help: 'Current analytics event buffer size',
  registers: [register],
});

// ── Middleware to measure HTTP requests ────────────────────────
function metricsMiddleware(req, res, next) {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const route = req.route?.path || req.path;
    apiRequestDuration.labels(req.method, route, res.statusCode.toString()).observe(duration);
  });
  next();
}

// ── Metrics endpoint ───────────────────────────────────────────
async function metricsHandler(req, res) {
  const secret = process.env.METRICS_SECRET;
  if (secret && req.headers['x-metrics-token'] !== secret) {
    return res.status(403).send('Forbidden');
  }
  res.setHeader('Content-Type', register.contentType);
  res.end(await register.metrics());
}

module.exports = {
  register,
  metrics: {
    urlsCreatedTotal,
    redirectsTotal,
    redirectLatency,
    apiRequestDuration,
    rateLimitHits,
    cacheHits,
    dbQueryDuration,
    activeUrlsGauge,
    analyticsBufferSize,
  },
  metricsMiddleware,
  metricsHandler,
};
