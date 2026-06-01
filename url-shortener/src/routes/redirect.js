'use strict';

const express      = require('express');
const urlService   = require('../services/urlService');
const analyticsService = require('../services/analyticsService');
const { metrics }  = require('../services/metricsService');
const { redirectLimiter } = require('../middleware/rateLimiter');
const logger       = require('../utils/logger');

const router = express.Router();

/**
 * GET /:code — The core redirect handler
 * This is the hottest path — must be as fast as possible.
 */
router.get('/:code', redirectLimiter, async (req, res) => {
  const start = Date.now();
  const { code } = req.params;

  // Validate code format (security: prevent path traversal)
  if (!/^[a-zA-Z0-9_-]{1,50}$/.test(code)) {
    return res.status(400).send('Invalid short code');
  }

  try {
    const url = await urlService.resolveUrl(code);

    if (!url) {
      metrics.redirectsTotal.inc({ status: 'not_found' });
      return res.status(404).render
        ? res.status(404).render('404', { code })
        : res.status(404).json({ error: 'Short URL not found or expired' });
    }

    // Password protection
    if (url.has_password) {
      return res.status(401).json({
        error:          'Password required',
        password_required: true,
        short_code:     code,
      });
    }

    // Record analytics (non-blocking, fire-and-forget)
    setImmediate(() => {
      analyticsService.recordClick(req, url).catch(err =>
        logger.error('[Redirect] Analytics error', { error: err.message })
      );
      urlService.incrementClicks(code, url.id).catch(err =>
        logger.error('[Redirect] Click count error', { error: err.message })
      );
    });

    const duration = Date.now() - start;
    metrics.redirectsTotal.inc({ status: 'success' });
    metrics.redirectLatency.observe(duration);

    // 301 for permanent (cached by browsers), 302 for temporary/expiring
    const isPermanent = !url.expires_at && !url.max_clicks;
    const redirectCode = isPermanent ? 301 : 302;

    // Security: strip Referer header to prevent leaking the short URL to destination
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Redirect-Time', `${duration}ms`);
    return res.redirect(redirectCode, url.original_url);

  } catch (err) {
    logger.error('[Redirect] Error', { code, error: err.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
