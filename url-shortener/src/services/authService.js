'use strict';

const jwt     = require('jsonwebtoken');
const bcrypt  = require('bcryptjs');
const crypto  = require('crypto');
const db      = require('../models/db');
const { cache } = require('../models/redis');
const logger  = require('../utils/logger');

const JWT_SECRET     = process.env.JWT_SECRET || 'change-me-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

const authService = {
  /**
   * Register a new user
   */
  async register({ email, password, name }) {
    const exists = await db.queryRead('SELECT id FROM users WHERE email = $1', [email]);
    if (exists.rows.length) throw new Error('Email already registered');

    const passwordHash = await bcrypt.hash(password, 12);
    const apiKey = this._generateApiKey();

    const result = await db.query(
      `INSERT INTO users (email, password_hash, name, api_key, api_key_created_at)
       VALUES ($1, $2, $3, $4, NOW()) RETURNING id, email, name, plan, api_key, created_at`,
      [email.toLowerCase(), passwordHash, name, apiKey]
    );

    const user = result.rows[0];
    logger.info('[Auth] User registered', { userId: user.id, email: user.email });
    return { user, token: this._signToken(user) };
  },

  /**
   * Login
   */
  async login({ email, password }) {
    const result = await db.queryRead(
      'SELECT * FROM users WHERE email = $1 AND is_active = TRUE',
      [email.toLowerCase()]
    );

    if (!result.rows.length) throw new Error('Invalid credentials');
    const user = result.rows[0];

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) throw new Error('Invalid credentials');

    // Update last login
    await db.query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [user.id]);

    const safeUser = this._sanitizeUser(user);
    logger.info('[Auth] User logged in', { userId: user.id });
    return { user: safeUser, token: this._signToken(safeUser) };
  },

  /**
   * Middleware: Verify JWT token
   */
  requireAuth(req, res, next) {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }

    try {
      const token = header.slice(7);
      const payload = jwt.verify(token, JWT_SECRET);
      req.user = payload;
      next();
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ error: 'Token expired' });
      }
      return res.status(401).json({ error: 'Invalid token' });
    }
  },

  /**
   * Middleware: Verify API key (alternative to JWT)
   */
  async requireApiKey(req, res, next) {
    const key = req.headers['x-api-key'] || req.query.api_key;
    if (!key) return next(); // Let requireAuth handle it

    const cacheKey = `apikey:${key}`;
    let user = await cache.get(cacheKey);

    if (!user) {
      const result = await db.queryRead(
        `SELECT u.id, u.email, u.name, u.plan, u.is_active, u.rate_limit_override,
                ak.scopes, ak.ip_whitelist, ak.expires_at
         FROM users u
         JOIN api_keys ak ON u.id = ak.user_id
         WHERE ak.key_hash = $1 AND ak.is_active = TRUE AND u.is_active = TRUE`,
        [this._hashApiKey(key)]
      );

      if (!result.rows.length) {
        return res.status(401).json({ error: 'Invalid API key' });
      }

      user = result.rows[0];

      // Check expiry
      if (user.expires_at && new Date(user.expires_at) < new Date()) {
        return res.status(401).json({ error: 'API key expired' });
      }

      // Check IP whitelist
      if (user.ip_whitelist?.length) {
        const clientIp = req.ip;
        if (!user.ip_whitelist.includes(clientIp)) {
          return res.status(403).json({ error: 'IP not in whitelist' });
        }
      }

      await cache.set(cacheKey, user, 300);

      // Update last used (async, don't await)
      db.query(
        'UPDATE api_keys SET last_used_at = NOW() WHERE key_hash = $1',
        [this._hashApiKey(key)]
      ).catch(() => {});
    }

    req.user = { ...user, apiKey: key };
    next();
  },

  /**
   * Middleware: Optional auth (allows anonymous access)
   */
  optionalAuth(req, res, next) {
    const header = req.headers.authorization;
    if (header?.startsWith('Bearer ')) {
      try {
        req.user = jwt.verify(header.slice(7), JWT_SECRET);
      } catch {}
    }
    next();
  },

  /**
   * Rotate API key
   */
  async rotateApiKey(userId) {
    const newKey = this._generateApiKey();
    await db.query(
      `UPDATE users SET api_key = $1, api_key_created_at = NOW() WHERE id = $2`,
      [newKey, userId]
    );
    // Invalidate cached API key lookups
    await cache.delPattern('apikey:*');
    return newKey;
  },

  // ── Helpers ─────────────────────────────────────────────────
  _signToken(user) {
    return jwt.sign(
      { id: user.id, email: user.email, plan: user.plan },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );
  },

  _generateApiKey() {
    return `sk_${crypto.randomBytes(24).toString('base64url')}`;
  },

  _hashApiKey(key) {
    return crypto.createHash('sha256').update(key).digest('hex');
  },

  _sanitizeUser(user) {
    const { password_hash, ...safe } = user;
    return safe;
  },
};

module.exports = authService;
