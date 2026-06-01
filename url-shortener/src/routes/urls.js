'use strict';

const express      = require('express');
const Joi          = require('joi');
const urlService   = require('../services/urlService');
const analyticsService = require('../services/analyticsService');
const { metrics }  = require('../services/metricsService');
const authService  = require('../services/authService');
const { createUrlLimiter, analyticsLimiter, passwordCheckLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

// ── Validation schemas ────────────────────────────────────────
const createSchema = Joi.object({
  url:         Joi.string().uri({ scheme: ['http', 'https'] }).max(4096).required(),
  custom_alias: Joi.string().alphanum().min(3).max(50).optional(),
  title:       Joi.string().max(500).optional(),
  description: Joi.string().max(2000).optional(),
  tags:        Joi.array().items(Joi.string().max(50)).max(10).optional(),
  expires_at:  Joi.date().greater('now').optional(),
  max_clicks:  Joi.number().integer().min(1).optional(),
  password:    Joi.string().min(4).max(100).optional(),
  utm_source:   Joi.string().max(255).optional(),
  utm_medium:   Joi.string().max(255).optional(),
  utm_campaign: Joi.string().max(255).optional(),
  utm_term:     Joi.string().max(255).optional(),
  utm_content:  Joi.string().max(255).optional(),
});

const updateSchema = Joi.object({
  title:       Joi.string().max(500),
  description: Joi.string().max(2000),
  tags:        Joi.array().items(Joi.string().max(50)).max(10),
  is_active:   Joi.boolean(),
  max_clicks:  Joi.number().integer().min(1).allow(null),
  expires_at:  Joi.date().allow(null),
}).min(1);

// ── POST /api/urls — Create short URL ─────────────────────────
router.post('/',
  authService.requireAuth,
  createUrlLimiter,
  async (req, res) => {
    const { error, value } = createSchema.validate(req.body, { abortEarly: false });
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message),
      });
    }

    try {
      const url = await urlService.createUrl({
        originalUrl: value.url,
        userId:      req.user.id,
        customAlias: value.custom_alias,
        title:       value.title,
        description: value.description,
        tags:        value.tags,
        expiresAt:   value.expires_at,
        maxClicks:   value.max_clicks,
        password:    value.password,
        utmSource:   value.utm_source,
        utmMedium:   value.utm_medium,
        utmCampaign: value.utm_campaign,
        utmTerm:     value.utm_term,
        utmContent:  value.utm_content,
      });

      metrics.urlsCreatedTotal.inc({
        plan:      req.user.plan || 'free',
        is_custom: String(!!value.custom_alias),
      });

      const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
      return res.status(201).json({
        ...url,
        short_url: `${baseUrl}/${url.short_code}`,
      });
    } catch (err) {
      if (err.message.includes('reserved') || err.message.includes('taken') ||
          err.message.includes('Invalid') || err.message.includes('allowed')) {
        return res.status(400).json({ error: err.message });
      }
      throw err;
    }
  }
);

// ── GET /api/urls — List my URLs ──────────────────────────────
router.get('/', authService.requireAuth, async (req, res) => {
  const { page = 1, limit = 20, search, tag, sort_by, sort_dir } = req.query;

  const result = await urlService.listUrls({
    userId:  req.user.id,
    page:    Math.max(1, parseInt(page)),
    limit:   Math.min(100, Math.max(1, parseInt(limit))),
    search:  search?.toString(),
    tag:     tag?.toString(),
    sortBy:  sort_by?.toString(),
    sortDir: sort_dir?.toString(),
  });

  const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  result.urls = result.urls.map(u => ({
    ...u,
    short_url: `${baseUrl}/${u.short_code}`,
  }));

  res.json(result);
});

// ── GET /api/urls/:id — Get URL detail ─────────────────────────
router.get('/:id', authService.requireAuth, async (req, res) => {
  const url = await urlService.getUrlById(req.params.id, req.user.id);
  if (!url) return res.status(404).json({ error: 'URL not found' });

  const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  res.json({ ...url, short_url: `${baseUrl}/${url.short_code}` });
});

// ── PATCH /api/urls/:id — Update URL ──────────────────────────
router.patch('/:id', authService.requireAuth, async (req, res) => {
  const { error, value } = updateSchema.validate(req.body, { abortEarly: false });
  if (error) {
    return res.status(400).json({
      error: 'Validation failed',
      details: error.details.map(d => d.message),
    });
  }

  const updated = await urlService.updateUrl(req.params.id, req.user.id, {
    title:       value.title,
    description: value.description,
    tags:        value.tags,
    is_active:   value.is_active,
    max_clicks:  value.max_clicks,
    expires_at:  value.expires_at,
  });

  if (!updated) return res.status(404).json({ error: 'URL not found' });
  res.json(updated);
});

// ── DELETE /api/urls/:id — Delete URL ─────────────────────────
router.delete('/:id', authService.requireAuth, async (req, res) => {
  const deleted = await urlService.deleteUrl(req.params.id, req.user.id);
  if (!deleted) return res.status(404).json({ error: 'URL not found' });
  res.status(204).send();
});

// ── GET /api/urls/:id/analytics — URL Analytics ───────────────
router.get('/:id/analytics',
  authService.requireAuth,
  analyticsLimiter,
  async (req, res) => {
    const url = await urlService.getUrlById(req.params.id, req.user.id);
    if (!url) return res.status(404).json({ error: 'URL not found' });

    const period = ['24h', '7d', '30d', '90d', '1y'].includes(req.query.period)
      ? req.query.period : '7d';

    const stats = await analyticsService.getStats(url.short_code, req.user.id, period);
    res.json(stats);
  }
);

// ── POST /api/urls/:code/check-password ───────────────────────
router.post('/:code/check-password',
  passwordCheckLimiter,
  async (req, res) => {
    const url = await urlService.resolveUrl(req.params.code);
    if (!url) return res.status(404).json({ error: 'Not found' });
    if (!url.has_password) return res.status(400).json({ error: 'No password set' });

    const bcrypt = require('bcryptjs');
    const db = require('../models/db');
    const row = await db.queryRead(
      'SELECT password_hash FROM urls WHERE short_code = $1',
      [req.params.code]
    );

    const valid = await bcrypt.compare(req.body.password, row.rows[0].password_hash);
    if (!valid) return res.status(401).json({ error: 'Incorrect password' });

    res.json({ redirect_url: url.original_url });
  }
);

module.exports = router;
