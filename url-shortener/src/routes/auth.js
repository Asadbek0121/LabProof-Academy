'use strict';

const express      = require('express');
const authService  = require('../services/authService');
const analyticsService = require('../services/analyticsService');
const { authLimiter } = require('../middleware/rateLimiter');
const Joi = require('joi');
const db  = require('../models/db');

const router = express.Router();

const registerSchema = Joi.object({
  email:    Joi.string().email().required(),
  password: Joi.string().min(8).max(128).required(),
  name:     Joi.string().min(1).max(255).required(),
});

const loginSchema = Joi.object({
  email:    Joi.string().email().required(),
  password: Joi.string().required(),
});

// POST /api/auth/register
router.post('/register', authLimiter, async (req, res) => {
  const { error, value } = registerSchema.validate(req.body, { abortEarly: false });
  if (error) return res.status(400).json({ error: 'Validation failed', details: error.details.map(d => d.message) });

  try {
    const result = await authService.register(value);
    res.status(201).json(result);
  } catch (err) {
    if (err.message.includes('already registered')) return res.status(409).json({ error: err.message });
    throw err;
  }
});

// POST /api/auth/login
router.post('/login', authLimiter, async (req, res) => {
  const { error, value } = loginSchema.validate(req.body, { abortEarly: false });
  if (error) return res.status(400).json({ error: 'Validation failed', details: error.details.map(d => d.message) });

  try {
    const result = await authService.login(value);
    res.json(result);
  } catch (err) {
    if (err.message === 'Invalid credentials') return res.status(401).json({ error: err.message });
    throw err;
  }
});

// GET /api/auth/me
router.get('/me', authService.requireAuth, async (req, res) => {
  const result = await db.queryRead(
    'SELECT id, email, name, plan, api_key, total_urls, monthly_clicks, created_at, last_login_at FROM users WHERE id = $1',
    [req.user.id]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'User not found' });
  res.json(result.rows[0]);
});

// POST /api/auth/rotate-key
router.post('/rotate-key', authService.requireAuth, async (req, res) => {
  const newKey = await authService.rotateApiKey(req.user.id);
  res.json({ api_key: newKey });
});

// GET /api/auth/dashboard
router.get('/dashboard', authService.requireAuth, async (req, res) => {
  const stats = await analyticsService.getDashboardStats(req.user.id);
  res.json(stats);
});

module.exports = router;
