'use strict';

const { customAlphabet } = require('nanoid');
const db   = require('../models/db');
const { cache } = require('../models/redis');
const logger = require('../utils/logger');

// Safe alphabet (no confusing chars like 0/O, 1/l)
const alphabet = '23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ';
const generateId = customAlphabet(alphabet, parseInt(process.env.SHORT_CODE_LENGTH || '7'));

// Reserved short codes that cannot be used
const RESERVED_CODES = new Set([
  'api', 'admin', 'dashboard', 'login', 'register', 'signup', 'logout',
  'health', 'metrics', 'status', 'docs', 'help', 'support', 'about',
  'terms', 'privacy', 'blog', 'pricing', 'contact', 'home', 'app',
  'static', 'assets', 'favicon', 'robots', 'sitemap', 'ads',
]);

const CACHE_TTL   = parseInt(process.env.CACHE_TTL_SHORT || '300');
const CACHE_KEY   = (code) => `url:${code}`;

const urlService = {
  /**
   * Create a new shortened URL
   */
  async createUrl(data) {
    const {
      originalUrl, userId = null, customAlias = null,
      title = null, description = null, tags = [],
      maxClicks = null, expiresAt = null, password = null,
      utmSource, utmMedium, utmCampaign, utmTerm, utmContent,
    } = data;

    // Validate URL
    this._validateUrl(originalUrl);

    // Determine short code
    let shortCode = customAlias;
    if (shortCode) {
      await this._validateCustomAlias(shortCode);
    } else {
      shortCode = await this._generateUniqueCode();
    }

    // Hash password if provided
    let passwordHash = null;
    if (password) {
      const bcrypt = require('bcryptjs');
      passwordHash = await bcrypt.hash(password, 12);
    }

    const result = await db.query(
      `INSERT INTO urls (
         short_code, original_url, user_id, title, description, tags,
         is_custom, password_hash, max_clicks, expires_at,
         utm_source, utm_medium, utm_campaign, utm_term, utm_content
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       RETURNING *`,
      [
        shortCode, originalUrl, userId, title, description, tags,
        !!customAlias, passwordHash, maxClicks,
        expiresAt ? new Date(expiresAt) : null,
        utmSource, utmMedium, utmCampaign, utmTerm, utmContent,
      ]
    );

    const url = result.rows[0];
    // Cache the new URL
    await cache.set(CACHE_KEY(shortCode), this._sanitize(url), CACHE_TTL);

    logger.info('[URL] Created', { shortCode, userId, isCustom: !!customAlias });
    return this._sanitize(url);
  },

  /**
   * Resolve a short code → original URL (with caching)
   */
  async resolveUrl(shortCode) {
    // 1. Try cache first
    const cached = await cache.get(CACHE_KEY(shortCode));
    if (cached !== null) {
      return cached;
    }

    // 2. Query database
    const result = await db.queryRead(
      `SELECT * FROM urls WHERE short_code = $1 AND is_active = TRUE`,
      [shortCode]
    );

    if (!result.rows.length) {
      await cache.set(CACHE_KEY(shortCode), null, 60); // Cache miss for 1 min
      return null;
    }

    const url = result.rows[0];

    // Check expiry
    if (url.expires_at && new Date(url.expires_at) < new Date()) {
      return null;
    }

    // Check click limit
    if (url.max_clicks !== null && url.click_count >= url.max_clicks) {
      return null;
    }

    const sanitized = this._sanitize(url);
    await cache.set(CACHE_KEY(shortCode), sanitized, CACHE_TTL);
    return sanitized;
  },

  /**
   * Increment click count (async, non-blocking)
   */
  async incrementClicks(shortCode, urlId) {
    // Increment in Redis first (atomic, fast)
    const clickKey = `clicks:pending:${shortCode}`;
    await cache.incr(clickKey, 300);

    // Batch flush is handled by AnalyticsService
    // Immediate DB update for accuracy
    await db.query(
      `UPDATE urls 
       SET click_count = click_count + 1, last_accessed_at = NOW()
       WHERE short_code = $1`,
      [shortCode]
    );

    // Invalidate cache so next read fetches fresh data
    await cache.del(CACHE_KEY(shortCode));
  },

  /**
   * Get URL by ID (for management)
   */
  async getUrlById(id, userId = null) {
    const params = [id];
    let query = 'SELECT * FROM urls WHERE id = $1';
    if (userId) {
      query += ' AND user_id = $2';
      params.push(userId);
    }
    const result = await db.queryRead(query, params);
    return result.rows[0] ? this._sanitize(result.rows[0]) : null;
  },

  /**
   * List URLs for a user with pagination
   */
  async listUrls({ userId, page = 1, limit = 20, search = null, tag = null, sortBy = 'created_at', sortDir = 'DESC' }) {
    const offset = (page - 1) * limit;
    const params = [userId, limit, offset];
    let whereExtra = '';

    if (search) {
      params.push(`%${search}%`);
      whereExtra += ` AND (u.original_url ILIKE $${params.length} OR u.title ILIKE $${params.length} OR u.short_code ILIKE $${params.length})`;
    }
    if (tag) {
      params.push(tag);
      whereExtra += ` AND $${params.length} = ANY(u.tags)`;
    }

    const validSorts = { created_at: 'u.created_at', click_count: 'u.click_count', last_accessed_at: 'u.last_accessed_at' };
    const orderCol = validSorts[sortBy] || 'u.created_at';
    const orderDir = sortDir === 'ASC' ? 'ASC' : 'DESC';

    const [rows, countResult] = await Promise.all([
      db.queryRead(
        `SELECT u.*, 
                COALESCE(a7.cnt, 0) AS clicks_7d,
                COALESCE(a30.cnt, 0) AS clicks_30d
         FROM urls u
         LEFT JOIN (
           SELECT url_id, COUNT(*) cnt FROM analytics 
           WHERE clicked_at >= NOW() - INTERVAL '7 days'
           GROUP BY url_id
         ) a7 ON u.id = a7.url_id
         LEFT JOIN (
           SELECT url_id, COUNT(*) cnt FROM analytics 
           WHERE clicked_at >= NOW() - INTERVAL '30 days'
           GROUP BY url_id
         ) a30 ON u.id = a30.url_id
         WHERE u.user_id = $1 ${whereExtra}
         ORDER BY ${orderCol} ${orderDir}
         LIMIT $2 OFFSET $3`,
        params
      ),
      db.queryRead(
        `SELECT COUNT(*) FROM urls u WHERE u.user_id = $1 ${whereExtra}`,
        [userId, ...params.slice(3)]
      ),
    ]);

    return {
      urls: rows.rows.map(r => this._sanitize(r)),
      total: parseInt(countResult.rows[0].count),
      page,
      limit,
      pages: Math.ceil(parseInt(countResult.rows[0].count) / limit),
    };
  },

  /**
   * Update URL properties
   */
  async updateUrl(id, userId, updates) {
    const allowed = ['title', 'description', 'tags', 'is_active', 'max_clicks', 'expires_at'];
    const sets = [];
    const params = [id, userId];

    for (const [key, val] of Object.entries(updates)) {
      if (allowed.includes(key) && val !== undefined) {
        params.push(val);
        sets.push(`${key} = $${params.length}`);
      }
    }

    if (!sets.length) throw new Error('No valid fields to update');

    const result = await db.query(
      `UPDATE urls SET ${sets.join(', ')} 
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      params
    );

    if (!result.rows.length) return null;

    // Invalidate cache
    await cache.del(CACHE_KEY(result.rows[0].short_code));
    return this._sanitize(result.rows[0]);
  },

  /**
   * Delete (soft delete = deactivate) a URL
   */
  async deleteUrl(id, userId) {
    const result = await db.query(
      `UPDATE urls SET is_active = FALSE 
       WHERE id = $1 AND user_id = $2 RETURNING short_code`,
      [id, userId]
    );
    if (result.rows.length) {
      await cache.del(CACHE_KEY(result.rows[0].short_code));
    }
    return result.rows.length > 0;
  },

  // ── Private helpers ────────────────────────────────────────

  _validateUrl(url) {
    try {
      const parsed = new URL(url);
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error('Only HTTP/HTTPS URLs are allowed');
      }
      // Block localhost, private IPs, loopback
      const host = parsed.hostname.toLowerCase();
      if (host === 'localhost' || host.startsWith('127.') || host.startsWith('192.168.') || host.startsWith('10.')) {
        throw new Error('Private/local URLs are not allowed');
      }
    } catch (err) {
      if (err.message.includes('Invalid URL')) throw new Error('Invalid URL format');
      throw err;
    }
  },

  async _validateCustomAlias(alias) {
    if (RESERVED_CODES.has(alias.toLowerCase())) {
      throw new Error(`"${alias}" is a reserved keyword`);
    }
    if (!/^[a-zA-Z0-9_-]+$/.test(alias)) {
      throw new Error('Custom alias can only contain letters, numbers, hyphens, and underscores');
    }
    const minLen = parseInt(process.env.CUSTOM_ALIAS_MIN_LENGTH || '3');
    const maxLen = parseInt(process.env.CUSTOM_ALIAS_MAX_LENGTH || '50');
    if (alias.length < minLen || alias.length > maxLen) {
      throw new Error(`Custom alias must be ${minLen}–${maxLen} characters`);
    }
    const exists = await db.queryRead(
      'SELECT id FROM urls WHERE short_code = $1',
      [alias]
    );
    if (exists.rows.length) {
      throw new Error('This custom alias is already taken');
    }
  },

  async _generateUniqueCode(attempts = 0) {
    if (attempts > 10) throw new Error('Failed to generate unique short code');
    const code = generateId();
    if (RESERVED_CODES.has(code)) return this._generateUniqueCode(attempts + 1);

    const exists = await db.queryRead(
      'SELECT id FROM urls WHERE short_code = $1',
      [code]
    );
    if (exists.rows.length) return this._generateUniqueCode(attempts + 1);
    return code;
  },

  _sanitize(url) {
    if (!url) return null;
    const { password_hash, ...safe } = url;
    return {
      ...safe,
      has_password: !!password_hash,
    };
  },
};

module.exports = urlService;
