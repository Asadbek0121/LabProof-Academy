'use strict';

const request = require('supertest');
const app     = require('../src/server');

// Mock DB and Redis to avoid real connections in tests
jest.mock('../src/models/db', () => ({
  query:      jest.fn(),
  queryRead:  jest.fn(),
  transaction: jest.fn((cb) => cb({ query: jest.fn() })),
  healthCheck: jest.fn().mockResolvedValue({ write: true, read: true }),
  close:       jest.fn(),
}));

jest.mock('../src/models/redis', () => ({
  connect: jest.fn().mockResolvedValue(true),
  cache: {
    get:         jest.fn().mockResolvedValue(null),
    set:         jest.fn().mockResolvedValue(true),
    del:         jest.fn(),
    incr:        jest.fn().mockResolvedValue(1),
    healthCheck: jest.fn().mockResolvedValue(true),
    getClient:   jest.fn().mockReturnValue({ sendCommand: jest.fn() }),
    close:       jest.fn(),
  },
}));

const db    = require('../src/models/db');
const { cache } = require('../src/models/redis');

const TEST_USER = {
  id:    '550e8400-e29b-41d4-a716-446655440000',
  email: 'test@example.com',
  plan:  'free',
};

const jwt = require('jsonwebtoken');
const AUTH_HEADER = () => ({
  Authorization: `Bearer ${jwt.sign(TEST_USER, process.env.JWT_SECRET || 'test-secret')}`,
});

describe('Health endpoints', () => {
  test('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok' });
  });

  test('GET /readyz returns 200 when DB and Redis are healthy', async () => {
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ready');
  });
});

describe('URL creation', () => {
  beforeEach(() => jest.clearAllMocks());

  test('POST /api/urls creates a short URL', async () => {
    db.query.mockResolvedValueOnce({
      rows: [{
        id: 'url-uuid-1', short_code: 'abc1234', original_url: 'https://example.com',
        user_id: TEST_USER.id, click_count: 0, unique_clicks: 0,
        is_active: true, created_at: new Date(), password_hash: null,
      }],
    });

    const res = await request(app)
      .post('/api/urls')
      .set(AUTH_HEADER())
      .send({ url: 'https://example.com', title: 'Example' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('short_code');
    expect(res.body).toHaveProperty('short_url');
  });

  test('POST /api/urls rejects invalid URL', async () => {
    const res = await request(app)
      .post('/api/urls')
      .set(AUTH_HEADER())
      .send({ url: 'not-a-url' });
    expect(res.status).toBe(400);
  });

  test('POST /api/urls requires auth', async () => {
    const res = await request(app)
      .post('/api/urls')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(401);
  });

  test('POST /api/urls rejects private IPs', async () => {
    const res = await request(app)
      .post('/api/urls')
      .set(AUTH_HEADER())
      .send({ url: 'http://localhost/admin' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/private|local/i);
  });
});

describe('Redirect', () => {
  test('GET /:code redirects to original URL', async () => {
    cache.get.mockResolvedValueOnce({
      id: 'url-uuid-1', short_code: 'abc1234',
      original_url: 'https://example.com',
      is_active: true, has_password: false,
      expires_at: null, max_clicks: null, click_count: 0,
    });
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app).get('/abc1234');
    expect(res.status).toBe(301);
    expect(res.headers.location).toBe('https://example.com');
  });

  test('GET /:code returns 404 for unknown code', async () => {
    cache.get.mockResolvedValueOnce(null);
    db.queryRead.mockResolvedValueOnce({ rows: [] });

    const res = await request(app).get('/zzzzzzz');
    expect(res.status).toBe(404);
  });

  test('GET /:code rejects invalid format', async () => {
    const res = await request(app).get('/../../etc/passwd');
    expect(res.status).toBe(400);
  });
});

describe('Auth', () => {
  test('POST /api/auth/register creates user', async () => {
    db.queryRead.mockResolvedValueOnce({ rows: [] }); // no existing user
    db.query.mockResolvedValueOnce({
      rows: [{
        id: TEST_USER.id, email: 'new@test.com',
        name: 'Test User', plan: 'free',
        api_key: 'sk_testkey', created_at: new Date(),
      }],
    });

    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'new@test.com', password: 'Password123!', name: 'Test User' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('user');
  });

  test('POST /api/auth/login returns token', async () => {
    const bcrypt = require('bcryptjs');
    const hash   = await bcrypt.hash('Password123!', 12);
    db.queryRead.mockResolvedValueOnce({
      rows: [{ ...TEST_USER, password_hash: hash, is_active: true }],
    });
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Password123!' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });
});
