'use strict';

const { Pool } = require('pg');
const logger = require('../utils/logger');

// ── Connection Pools ──────────────────────────────────────────
const writePool = new Pool({
  host:     process.env.DB_HOST || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'urlshortener',
  user:     process.env.DB_USER || 'urluser',
  password: process.env.DB_PASSWORD,
  min:      parseInt(process.env.DB_POOL_MIN || '2'),
  max:      parseInt(process.env.DB_POOL_MAX || '20'),
  idleTimeoutMillis:    parseInt(process.env.DB_POOL_IDLE || '10000'),
  connectionTimeoutMillis: 5000,
  statement_timeout:   30000,
  application_name: 'url-shortener-write',
});

// Read replica pool (falls back to primary if not configured)
const readPool = new Pool({
  host:     process.env.DB_READ_HOST || process.env.DB_HOST || 'localhost',
  port:     parseInt(process.env.DB_READ_PORT || process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'urlshortener',
  user:     process.env.DB_USER || 'urluser',
  password: process.env.DB_PASSWORD,
  min:      1,
  max:      parseInt(process.env.DB_POOL_MAX || '10'),
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 30000,
  application_name: 'url-shortener-read',
});

// Pool event handlers
[
  { pool: writePool, name: 'write' },
  { pool: readPool,  name: 'read'  },
].forEach(({ pool, name }) => {
  pool.on('connect', () => logger.debug(`[DB:${name}] New client connected`));
  pool.on('error',   (err) => logger.error(`[DB:${name}] Pool error`, { error: err.message }));
  pool.on('remove',  () => logger.debug(`[DB:${name}] Client removed from pool`));
});

// ── Query Helpers ─────────────────────────────────────────────
const db = {
  /**
   * Execute a write query (INSERT, UPDATE, DELETE)
   */
  async query(text, params = []) {
    const start = Date.now();
    try {
      const result = await writePool.query(text, params);
      const duration = Date.now() - start;
      if (duration > 1000) {
        logger.warn('[DB] Slow write query detected', { duration, text: text.substring(0, 100) });
      }
      logger.debug('[DB] Write query executed', { duration, rows: result.rowCount });
      return result;
    } catch (err) {
      logger.error('[DB] Write query failed', { error: err.message, text: text.substring(0, 100) });
      throw err;
    }
  },

  /**
   * Execute a read query (SELECT) — uses read replica
   */
  async queryRead(text, params = []) {
    const start = Date.now();
    try {
      const result = await readPool.query(text, params);
      const duration = Date.now() - start;
      if (duration > 500) {
        logger.warn('[DB] Slow read query detected', { duration, text: text.substring(0, 100) });
      }
      return result;
    } catch (err) {
      logger.error('[DB] Read query failed', { error: err.message, text: text.substring(0, 100) });
      // Fallback to write pool on read failure
      logger.warn('[DB] Falling back to write pool for read query');
      return writePool.query(text, params);
    }
  },

  /**
   * Execute a transaction (set of queries)
   */
  async transaction(callback) {
    const client = await writePool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error('[DB] Transaction rolled back', { error: err.message });
      throw err;
    } finally {
      client.release();
    }
  },

  /**
   * Batch insert using COPY-like unnest approach
   */
  async batchInsert(table, columns, rows) {
    if (!rows.length) return;
    const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
    const values = rows.map(row => columns.map(col => row[col]));
    
    const query = `
      INSERT INTO ${table} (${columns.join(', ')})
      SELECT * FROM UNNEST(${columns.map(() => 'ARRAY[]::text[]').join(', ')})
      AS t(${columns.join(', ')})
    `;
    // Use parameterized approach for safety
    const flatValues = values.flat();
    const paramStr = rows.map((_, ri) =>
      `(${columns.map((_, ci) => `$${ri * columns.length + ci + 1}`).join(', ')})`
    ).join(', ');
    
    return this.query(
      `INSERT INTO ${table} (${columns.join(', ')}) VALUES ${paramStr}`,
      flatValues
    );
  },

  /**
   * Health check
   */
  async healthCheck() {
    const writeOk = await writePool.query('SELECT 1 AS ok').then(() => true).catch(() => false);
    const readOk  = await readPool.query('SELECT 1 AS ok').then(() => true).catch(() => false);
    return {
      write: writeOk,
      read:  readOk,
      writePoolTotal: writePool.totalCount,
      writePoolIdle:  writePool.idleCount,
      writePoolWait:  writePool.waitingCount,
    };
  },

  async close() {
    await Promise.all([writePool.end(), readPool.end()]);
    logger.info('[DB] All pools closed');
  },
};

module.exports = db;
