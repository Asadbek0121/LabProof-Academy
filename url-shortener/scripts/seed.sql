-- Seed data for URL Shortener

-- ── 1. Clean existing data (safe cascade) ───────────────────────
TRUNCATE TABLE users, urls, api_keys, analytics RESTART IDENTITY CASCADE;

-- ── 2. Create Users ──────────────────────────────────────────────
-- Password is 'Password123!' (hashed with bcrypt: $2a$12$K.zR/WJ/W43R92.k72pGqu7rE6b8G0b3nBfN1pXz7K6K6K6K6K6K6)
INSERT INTO users (id, email, password_hash, name, plan, created_at)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'admin@short.ly', '$2a$12$K.zR/WJ/W43R92.k72pGqu7rE6b8G0b3nBfN1pXz7K6K6K6K6K6K6', 'Admin Short.ly', 'enterprise', NOW() - INTERVAL '30 days'),
  ('550e8400-e29b-41d4-a716-446655440001', 'pro@example.com', '$2a$12$K.zR/WJ/W43R92.k72pGqu7rE6b8G0b3nBfN1pXz7K6K6K6K6K6K6', 'Pro User', 'pro', NOW() - INTERVAL '15 days'),
  ('550e8400-e29b-41d4-a716-446655440002', 'free@example.com', '$2a$12$K.zR/WJ/W43R92.k72pGqu7rE6b8G0b3nBfN1pXz7K6K6K6K6K6K6', 'Free User', 'free', NOW() - INTERVAL '5 days');

-- ── 3. Create API Keys ───────────────────────────────────────────
INSERT INTO api_keys (user_id, api_key, name, scopes, ip_whitelist)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'sk_prod_admin_key_1234567890', 'Admin Production Key', '["url:create", "url:read", "url:write", "url:delete", "analytics:read"]', NULL),
  ('550e8400-e29b-41d4-a716-446655440001', 'sk_prod_pro_key_1234567890', 'Pro Client Key', '["url:create", "url:read", "url:write"]', '["127.0.0.1", "192.168.1.0/24"]');

-- ── 4. Create URLs ───────────────────────────────────────────────
INSERT INTO urls (id, short_code, original_url, user_id, title, description, tags, click_count, is_active, created_at)
VALUES
  ('110e8400-e29b-41d4-a716-446655440000', 'google', 'https://google.com', '550e8400-e29b-41d4-a716-446655440000', 'Google', 'Search engine giant', '["search", "tech"]', 1500, TRUE, NOW() - INTERVAL '10 days'),
  ('110e8400-e29b-41d4-a716-446655440001', 'github', 'https://github.com', '550e8400-e29b-41d4-a716-446655440000', 'GitHub', 'Developer platform', '["code", "dev"]', 850, TRUE, NOW() - INTERVAL '8 days'),
  ('110e8400-e29b-41d4-a716-446655440002', 'secure', 'https://example.com/sensitive-docs', '550e8400-e29b-41d4-a716-446655440001', 'Secure Docs', 'Password-protected secret repository', '["security", "private"]', 10, TRUE, NOW() - INTERVAL '5 days'),
  ('110e8400-e29b-41d4-a716-446655440003', 'promo', 'https://example.com/landing?utm_source=twitter&utm_medium=social&utm_campaign=summer_sale', '550e8400-e29b-41d4-a716-446655440001', 'Summer Promo', 'Summer campaign link', '["marketing", "campaign"]', 320, TRUE, NOW() - INTERVAL '3 days'),
  ('110e8400-e29b-41d4-a716-446655440004', 'expired', 'https://example.com/expired-offer', '550e8400-e29b-41d4-a716-446655440002', 'Expired Offer', 'Old deal page', '["offers"]', 99, TRUE, NOW() - INTERVAL '30 days');

-- Update password for 'secure' URL (hashed bcrypt of 'secret123')
UPDATE urls SET password_hash = '$2a$12$R.S/O8X9D3dpeZzN/P1Moe6Bw0vX911m32f518eA6O6v6v6v6v6v6' WHERE short_code = 'secure';

-- Update expires_at for expired URL
UPDATE urls SET expires_at = NOW() - INTERVAL '1 day' WHERE short_code = 'expired';

-- ── 5. Create Analytics Data ─────────────────────────────────────
-- Let's pre-populate standard partitioned analytics tables
-- We will write them using a dynamic date generation loop to populate recent 7 days
DO $$
DECLARE
  url_rec RECORD;
  i INT;
  click_time TIMESTAMP;
  ip VARCHAR(45);
  ua VARCHAR(500);
  ref VARCHAR(500);
  country CHAR(2);
  city VARCHAR(100);
  browser VARCHAR(50);
  os VARCHAR(50);
  device VARCHAR(20);
BEGIN
  -- Sample arrays
  FOR url_rec IN SELECT id, short_code, created_at FROM urls WHERE is_active = TRUE LOOP
    -- Generate clicks
    FOR i IN 1..100 LOOP
      click_time := NOW() - (random() * (NOW() - url_rec.created_at));
      
      -- Choose random attributes
      IF random() < 0.4 THEN
        country := 'US'; city := 'New York'; ip := '192.0.2.1';
      ELSIF random() < 0.7 THEN
        country := 'GB'; city := 'London'; ip := '198.51.100.2';
      ELSE
        country := 'UZ'; city := 'Tashkent'; ip := '203.0.113.3';
      END IF;

      IF random() < 0.6 THEN
        ua := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        browser := 'Chrome'; os := 'Windows'; device := 'desktop';
      ELSIF random() < 0.8 THEN
        ua := 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1';
        browser := 'Safari'; os := 'iOS'; device := 'mobile';
      ELSE
        ua := 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15';
        browser := 'Safari'; os := 'macOS'; device := 'desktop';
      END IF;

      IF random() < 0.5 THEN
        ref := 'https://twitter.com/';
      ELSIF random() < 0.8 THEN
        ref := 'https://github.com/';
      ELSE
        ref := 'direct';
      END IF;

      -- Insert record
      INSERT INTO analytics (
        url_id, short_code, ip_hash, user_agent, referrer, country, city,
        browser, os, device, created_at, is_unique
      ) VALUES (
        url_rec.id, url_rec.short_code, encode(digest(ip || 'analytics-ip-salt-change-me', 'sha256'), 'hex'),
        ua, ref, country, city, browser, os, device, click_time, (random() < 0.8)
      );
    END LOOP;
  END LOOP;
END;
$$;

-- Refresh the materialized view for dashboard
SELECT refresh_dashboard_stats();
