'use strict';

const UAParser = require('ua-parser-js');
const geoip    = require('geoip-lite');
const crypto   = require('crypto');
const db       = require('../models/db');
const { cache } = require('../models/redis');
const logger   = require('../utils/logger');

// In-memory buffer for batch inserts
const BUFFER_KEY      = 'analytics:buffer';
const FLUSH_INTERVAL  = parseInt(process.env.ANALYTICS_FLUSH_INTERVAL || '5000');
const BATCH_SIZE      = parseInt(process.env.ANALYTICS_BATCH_SIZE     || '100');

let buffer = [];
let flushTimer = null;

const analyticsService = {
  /**
   * Record a click event (buffered, non-blocking)
   */
  async recordClick(req, urlData) {
    try {
      const event = this._buildEvent(req, urlData);
      buffer.push(event);

      // Flush if buffer is full
      if (buffer.length >= BATCH_SIZE) {
        await this._flush();
      }
    } catch (err) {
      logger.error('[Analytics] Error recording click', { error: err.message });
    }
  },

  /**
   * Get click stats for a URL
   */
  async getStats(shortCode, userId, period = '7d') {
    const cacheKey = `stats:${shortCode}:${period}`;
    const cached   = await cache.get(cacheKey);
    if (cached) return cached;

    const interval = this._periodToInterval(period);

    const [overview, byDay, byCountry, byDevice, byBrowser, byReferrer] = await Promise.all([
      // Overview
      db.queryRead(`
        SELECT 
          COUNT(*) AS total_clicks,
          COUNT(*) FILTER (WHERE is_unique) AS unique_clicks,
          COUNT(DISTINCT country) AS countries,
          COUNT(DISTINCT session_id) AS sessions
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}'
      `, [shortCode]),

      // Clicks by day
      db.queryRead(`
        SELECT 
          DATE_TRUNC('day', clicked_at) AS day,
          COUNT(*) AS clicks,
          COUNT(*) FILTER (WHERE is_unique) AS unique_clicks
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}'
        GROUP BY DATE_TRUNC('day', clicked_at)
        ORDER BY day ASC
      `, [shortCode]),

      // By country
      db.queryRead(`
        SELECT 
          country, country_name,
          COUNT(*) AS clicks,
          ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0), 1) AS pct
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}' AND country IS NOT NULL
        GROUP BY country, country_name
        ORDER BY clicks DESC
        LIMIT 20
      `, [shortCode]),

      // By device
      db.queryRead(`
        SELECT 
          device_type,
          COUNT(*) AS clicks,
          ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0), 1) AS pct
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}'
        GROUP BY device_type
        ORDER BY clicks DESC
      `, [shortCode]),

      // By browser
      db.queryRead(`
        SELECT 
          browser,
          COUNT(*) AS clicks,
          ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0), 1) AS pct
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}' AND browser IS NOT NULL
        GROUP BY browser
        ORDER BY clicks DESC
        LIMIT 10
      `, [shortCode]),

      // By referrer
      db.queryRead(`
        SELECT 
          COALESCE(referrer_domain, 'Direct') AS referrer,
          COUNT(*) AS clicks,
          ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0), 1) AS pct
        FROM analytics
        WHERE short_code = $1 AND clicked_at >= NOW() - INTERVAL '${interval}'
        GROUP BY referrer_domain
        ORDER BY clicks DESC
        LIMIT 15
      `, [shortCode]),
    ]);

    const stats = {
      period,
      overview: overview.rows[0],
      byDay:      byDay.rows,
      byCountry:  byCountry.rows,
      byDevice:   byDevice.rows,
      byBrowser:  byBrowser.rows,
      byReferrer: byReferrer.rows,
    };

    await cache.set(cacheKey, stats, parseInt(process.env.CACHE_TTL_ANALYTICS || '900'));
    return stats;
  },

  /**
   * Get dashboard-level aggregate stats
   */
  async getDashboardStats(userId) {
    const cacheKey = `dashboard:${userId}`;
    const cached   = await cache.get(cacheKey);
    if (cached) return cached;

    const result = await db.queryRead(`
      SELECT
        COUNT(DISTINCT u.id)                                         AS total_urls,
        COALESCE(SUM(u.click_count), 0)                             AS total_clicks,
        COUNT(DISTINCT u.id) FILTER (WHERE u.is_active)             AS active_urls,
        COALESCE(SUM(u.click_count) FILTER (
          WHERE u.last_accessed_at >= NOW() - INTERVAL '24 hours'
        ), 0)                                                        AS clicks_today,
        COALESCE(SUM(u.click_count) FILTER (
          WHERE u.last_accessed_at >= NOW() - INTERVAL '7 days'
        ), 0)                                                        AS clicks_7d,
        COUNT(DISTINCT u.id) FILTER (
          WHERE u.expires_at IS NOT NULL AND u.expires_at < NOW()
        )                                                            AS expired_urls
      FROM urls u
      WHERE u.user_id = $1
    `, [userId]);

    // Top performing URLs
    const topUrls = await db.queryRead(`
      SELECT short_code, original_url, title, click_count, unique_clicks, last_accessed_at
      FROM urls
      WHERE user_id = $1 AND is_active = TRUE
      ORDER BY click_count DESC
      LIMIT 5
    `, [userId]);

    const stats = {
      ...result.rows[0],
      topUrls: topUrls.rows,
    };

    await cache.set(cacheKey, stats, 300);
    return stats;
  },

  // ── Internal ──────────────────────────────────────────────────

  _buildEvent(req, urlData) {
    const ua      = UAParser(req.headers['user-agent'] || '');
    const ip      = req.ip || req.socket?.remoteAddress;
    const geo     = ip ? geoip.lookup(ip) : null;
    const referer = req.headers['referer'] || req.headers['referrer'] || null;

    let referrerDomain = null;
    if (referer) {
      try { referrerDomain = new URL(referer).hostname; } catch {}
    }

    const deviceType = (() => {
      if (ua.device?.type === 'mobile')  return 'mobile';
      if (ua.device?.type === 'tablet')  return 'tablet';
      if ((ua.ua || '').toLowerCase().includes('bot') ||
          (ua.ua || '').toLowerCase().includes('crawler')) return 'bot';
      if (ua.browser?.name) return 'desktop';
      return 'unknown';
    })();

    return {
      url_id:          urlData.id,
      short_code:      urlData.short_code,
      clicked_at:      new Date(),
      ip_address:      ip,
      ip_hash:         ip ? crypto.createHash('sha256').update(ip + (process.env.IP_HASH_SALT || 'salt')).digest('hex').slice(0, 16) : null,
      country:         geo?.country || null,
      country_name:    geo?.country ? geo.country : null,
      city:            geo?.city    || null,
      region:          geo?.region  || null,
      latitude:        geo?.ll?.[0] || null,
      longitude:       geo?.ll?.[1] || null,
      user_agent:      (req.headers['user-agent'] || '').slice(0, 512),
      browser:         ua.browser?.name   || null,
      browser_version: ua.browser?.version || null,
      os:              ua.os?.name        || null,
      os_version:      ua.os?.version     || null,
      device_type:     deviceType,
      referrer:        referer,
      referrer_domain: referrerDomain,
      is_unique:       false, // set by dedup logic
      session_id:      null,
      language:        req.headers['accept-language']?.split(',')[0] || null,
    };
  },

  async _flush() {
    if (!buffer.length) return;
    const toInsert = buffer.splice(0, buffer.length);
    
    try {
      // Dedup check via Redis
      for (const event of toInsert) {
        const dedupKey = `dedup:${event.url_id}:${event.ip_hash}`;
        const isNew = await cache.incr(dedupKey, 86400); // 24h window
        event.is_unique = isNew === 1;
      }

      const cols = [
        'url_id', 'short_code', 'clicked_at', 'ip_address', 'ip_hash',
        'country', 'country_name', 'city', 'region', 'latitude', 'longitude',
        'user_agent', 'browser', 'browser_version', 'os', 'os_version',
        'device_type', 'referrer', 'referrer_domain', 'is_unique', 'session_id', 'language',
      ];

      const values = toInsert.flatMap(row => cols.map(c => row[c] ?? null));
      const rowPlaceholders = toInsert.map((_, ri) =>
        `(${cols.map((__, ci) => `$${ri * cols.length + ci + 1}`).join(', ')})`
      ).join(', ');

      await db.query(
        `INSERT INTO analytics (${cols.join(', ')}) VALUES ${rowPlaceholders}`,
        values
      );

      // Update unique click counts
      const uniqueByUrl = {};
      for (const e of toInsert.filter(e => e.is_unique)) {
        uniqueByUrl[e.url_id] = (uniqueByUrl[e.url_id] || 0) + 1;
      }
      for (const [urlId, cnt] of Object.entries(uniqueByUrl)) {
        await db.query(
          'UPDATE urls SET unique_clicks = unique_clicks + $1 WHERE id = $2',
          [cnt, urlId]
        );
      }

      logger.debug(`[Analytics] Flushed ${toInsert.length} events`);
    } catch (err) {
      logger.error('[Analytics] Flush failed', { error: err.message, count: toInsert.length });
      // Re-add to buffer (up to max)
      buffer.unshift(...toInsert.slice(0, BATCH_SIZE));
    }
  },

  startFlushTimer() {
    if (flushTimer) return;
    flushTimer = setInterval(() => this._flush(), FLUSH_INTERVAL);
    logger.info(`[Analytics] Flush timer started (${FLUSH_INTERVAL}ms)`);
  },

  async stopFlushTimer() {
    if (flushTimer) {
      clearInterval(flushTimer);
      flushTimer = null;
    }
    await this._flush(); // Final flush
  },

  _periodToInterval(period) {
    const map = { '24h': '24 hours', '7d': '7 days', '30d': '30 days', '90d': '90 days', '1y': '1 year' };
    return map[period] || '7 days';
  },
};

module.exports = analyticsService;
