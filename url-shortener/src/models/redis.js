'use strict';

const { createClient } = require('redis');
const logger = require('../utils/logger');

let client = null;
let subClient = null;

/**
 * Initialize Redis connection with retry logic
 */
async function connect() {
  const opts = {
    socket: {
      host:           process.env.REDIS_HOST || 'localhost',
      port:           parseInt(process.env.REDIS_PORT || '6379'),
      reconnectStrategy: (retries) => {
        if (retries > 10) {
          logger.error('[Redis] Max reconnection attempts reached');
          return new Error('Too many retries');
        }
        const delay = Math.min(retries * 100, 3000);
        logger.warn(`[Redis] Reconnecting in ${delay}ms (attempt ${retries})`);
        return delay;
      },
    },
    password: process.env.REDIS_PASSWORD || undefined,
    database: parseInt(process.env.REDIS_DB || '0'),
  };

  client = createClient(opts);

  client.on('error',   (err) => logger.error('[Redis] Error', { message: err.message }));
  client.on('connect', ()    => logger.info('[Redis] Connected'));
  client.on('ready',   ()    => logger.info('[Redis] Ready'));
  client.on('reconnecting', () => logger.warn('[Redis] Reconnecting...'));

  await client.connect();
  return client;
}

// ── Cache Operations ───────────────────────────────────────────
const cache = {
  /**
   * Get a value (JSON deserialized)
   */
  async get(key) {
    if (!client) return null;
    try {
      const value = await client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (err) {
      logger.error('[Redis] GET error', { key, error: err.message });
      return null;
    }
  },

  /**
   * Set a value with optional TTL in seconds
   */
  async set(key, value, ttlSeconds = null) {
    if (!client) return false;
    try {
      const serialized = JSON.stringify(value);
      if (ttlSeconds) {
        await client.setEx(key, ttlSeconds, serialized);
      } else {
        await client.set(key, serialized);
      }
      return true;
    } catch (err) {
      logger.error('[Redis] SET error', { key, error: err.message });
      return false;
    }
  },

  /**
   * Delete key(s)
   */
  async del(...keys) {
    if (!client || !keys.length) return;
    try {
      await client.del(keys);
    } catch (err) {
      logger.error('[Redis] DEL error', { keys, error: err.message });
    }
  },

  /**
   * Delete all keys matching a pattern
   */
  async delPattern(pattern) {
    if (!client) return;
    try {
      let cursor = 0;
      do {
        const result = await client.scan(cursor, { MATCH: pattern, COUNT: 100 });
        cursor = result.cursor;
        if (result.keys.length > 0) {
          await client.del(result.keys);
        }
      } while (cursor !== 0);
    } catch (err) {
      logger.error('[Redis] DEL pattern error', { pattern, error: err.message });
    }
  },

  /**
   * Increment a counter with optional expiry
   */
  async incr(key, ttlSeconds = null) {
    if (!client) return 0;
    try {
      const value = await client.incr(key);
      if (ttlSeconds && value === 1) {
        await client.expire(key, ttlSeconds);
      }
      return value;
    } catch (err) {
      logger.error('[Redis] INCR error', { key, error: err.message });
      return 0;
    }
  },

  /**
   * Expire a key
   */
  async expire(key, ttlSeconds) {
    if (!client) return;
    try {
      await client.expire(key, ttlSeconds);
    } catch (err) {
      logger.error('[Redis] EXPIRE error', { key, error: err.message });
    }
  },

  /**
   * Add to sorted set (for analytics)
   */
  async zadd(key, score, member) {
    if (!client) return;
    try {
      await client.zAdd(key, [{ score, value: member }]);
    } catch (err) {
      logger.error('[Redis] ZADD error', { key, error: err.message });
    }
  },

  /**
   * Get sorted set range with scores
   */
  async zrangeWithScores(key, start, stop, reverse = false) {
    if (!client) return [];
    try {
      if (reverse) {
        return client.zRangeWithScores(key, stop, start, { REV: true });
      }
      return client.zRangeWithScores(key, start, stop);
    } catch (err) {
      logger.error('[Redis] ZRANGE error', { key, error: err.message });
      return [];
    }
  },

  /**
   * Pipeline for multiple operations
   */
  async pipeline(operations) {
    if (!client) return [];
    try {
      const pipeline = client.multi();
      operations(pipeline);
      return pipeline.exec();
    } catch (err) {
      logger.error('[Redis] Pipeline error', { error: err.message });
      return [];
    }
  },

  /**
   * Health check
   */
  async healthCheck() {
    if (!client) return false;
    try {
      const pong = await client.ping();
      return pong === 'PONG';
    } catch {
      return false;
    }
  },

  async close() {
    if (client) {
      await client.quit();
      logger.info('[Redis] Connection closed');
    }
  },

  getClient() { return client; },
};

module.exports = { connect, cache };
