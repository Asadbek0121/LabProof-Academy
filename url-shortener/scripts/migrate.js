'use strict';

require('dotenv').config();
const path = require('path');
const fs   = require('fs');
const { Pool } = require('pg');

const pool = new Pool({
  host:     process.env.DB_HOST || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'urlshortener',
  user:     process.env.DB_USER || 'urluser',
  password: process.env.DB_PASSWORD,
  connectionTimeoutMillis: 10000,
});

async function migrate() {
  console.log('[Migrate] Starting database migration...');
  const schemaPath = path.join(__dirname, 'schema.sql');

  if (!fs.existsSync(schemaPath)) {
    throw new Error(`Schema file not found: ${schemaPath}`);
  }

  const sql = fs.readFileSync(schemaPath, 'utf8');
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    console.log('[Migrate] Applying schema...');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('[Migrate] ✅ Migration complete.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[Migrate] ❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
