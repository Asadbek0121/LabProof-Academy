-- ============================================================
-- URL Shortener - Production Database Schema
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255),
    name            VARCHAR(255),
    plan            VARCHAR(20) DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
    is_active       BOOLEAN DEFAULT TRUE,
    is_verified     BOOLEAN DEFAULT FALSE,
    api_key         VARCHAR(64) UNIQUE,
    api_key_created_at TIMESTAMPTZ,
    rate_limit_override INTEGER,         -- NULL = use plan defaults
    monthly_clicks  BIGINT DEFAULT 0,
    total_urls      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ,
    metadata        JSONB DEFAULT '{}'
);

-- ============================================================
-- URLS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS urls (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    short_code      VARCHAR(50) UNIQUE NOT NULL,
    original_url    TEXT NOT NULL,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    title           VARCHAR(500),
    description     TEXT,
    tags            TEXT[] DEFAULT '{}',
    is_active       BOOLEAN DEFAULT TRUE,
    is_custom       BOOLEAN DEFAULT FALSE,       -- custom alias vs auto-generated
    password_hash   VARCHAR(255),               -- password-protected links
    max_clicks      INTEGER,                    -- NULL = unlimited
    click_count     BIGINT DEFAULT 0,
    unique_clicks   BIGINT DEFAULT 0,
    expires_at      TIMESTAMPTZ,
    utm_source      VARCHAR(255),
    utm_medium      VARCHAR(255),
    utm_campaign    VARCHAR(255),
    utm_term        VARCHAR(255),
    utm_content     VARCHAR(255),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ,
    metadata        JSONB DEFAULT '{}'
);

-- ============================================================
-- ANALYTICS TABLE (partitioned by month for performance)
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics (
    id              BIGSERIAL,
    url_id          UUID NOT NULL REFERENCES urls(id) ON DELETE CASCADE,
    short_code      VARCHAR(50) NOT NULL,
    clicked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address      INET,
    ip_hash         VARCHAR(64),               -- hashed for GDPR
    country         VARCHAR(2),
    country_name    VARCHAR(100),
    city            VARCHAR(100),
    region          VARCHAR(100),
    latitude        DECIMAL(9,6),
    longitude       DECIMAL(9,6),
    user_agent      TEXT,
    browser         VARCHAR(100),
    browser_version VARCHAR(50),
    os              VARCHAR(100),
    os_version      VARCHAR(50),
    device_type     VARCHAR(20) CHECK (device_type IN ('desktop', 'mobile', 'tablet', 'bot', 'unknown')),
    referrer        TEXT,
    referrer_domain VARCHAR(255),
    is_unique       BOOLEAN DEFAULT FALSE,
    session_id      VARCHAR(64),
    language        VARCHAR(20),
    screen_width    INTEGER,
    screen_height   INTEGER
) PARTITION BY RANGE (clicked_at);

-- Create initial partitions (current month + next 12 months)
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('month', CURRENT_DATE);
    partition_date DATE;
    partition_name TEXT;
    next_date DATE;
BEGIN
    FOR i IN 0..12 LOOP
        partition_date := start_date + (i || ' months')::INTERVAL;
        next_date := partition_date + '1 month'::INTERVAL;
        partition_name := 'analytics_' || TO_CHAR(partition_date, 'YYYY_MM');
        
        IF NOT EXISTS (
            SELECT 1 FROM pg_tables 
            WHERE tablename = partition_name
        ) THEN
            EXECUTE FORMAT(
                'CREATE TABLE %I PARTITION OF analytics 
                 FOR VALUES FROM (%L) TO (%L)',
                partition_name, partition_date, next_date
            );
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- RATE LIMIT TRACKING TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS rate_limit_violations (
    id          BIGSERIAL PRIMARY KEY,
    identifier  VARCHAR(255) NOT NULL,  -- IP or API key
    endpoint    VARCHAR(255),
    violated_at TIMESTAMPTZ DEFAULT NOW(),
    request_count INTEGER,
    blocked     BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- API KEYS TABLE (for detailed key management)
-- ============================================================
CREATE TABLE IF NOT EXISTS api_keys (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash    VARCHAR(64) UNIQUE NOT NULL,
    key_prefix  VARCHAR(10) NOT NULL,           -- first 10 chars for display
    name        VARCHAR(255),
    scopes      TEXT[] DEFAULT '{"read", "write"}',
    is_active   BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMPTZ,
    expires_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    ip_whitelist INET[] DEFAULT NULL            -- NULL = all IPs allowed
);

-- ============================================================
-- DOMAINS TABLE (custom domains for enterprise)
-- ============================================================
CREATE TABLE IF NOT EXISTS custom_domains (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    domain      VARCHAR(255) UNIQUE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    verify_token VARCHAR(64),
    ssl_enabled BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- QR CODES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS qr_codes (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    url_id      UUID NOT NULL REFERENCES urls(id) ON DELETE CASCADE,
    format      VARCHAR(10) DEFAULT 'png' CHECK (format IN ('png', 'svg', 'pdf')),
    size        INTEGER DEFAULT 256,
    color       VARCHAR(7) DEFAULT '#000000',
    bg_color    VARCHAR(7) DEFAULT '#FFFFFF',
    logo_url    TEXT,
    download_count INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUDIT LOG TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    action      VARCHAR(100) NOT NULL,
    resource    VARCHAR(100),
    resource_id VARCHAR(255),
    ip_address  INET,
    user_agent  TEXT,
    payload     JSONB,
    result      VARCHAR(20) CHECK (result IN ('success', 'failure')),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- urls indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_short_code ON urls(short_code);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_user_id ON urls(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_created_at ON urls(created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_expires_at ON urls(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_is_active ON urls(is_active) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_tags ON urls USING GIN(tags);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_urls_original_url_trgm ON urls USING GIN(original_url gin_trgm_ops);

-- analytics indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_url_id ON analytics(url_id, clicked_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_short_code ON analytics(short_code, clicked_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_clicked_at ON analytics(clicked_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_country ON analytics(country);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_device_type ON analytics(device_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_is_unique ON analytics(url_id, is_unique) WHERE is_unique = TRUE;

-- users indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_api_key ON users(api_key) WHERE api_key IS NOT NULL;

-- api_keys indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);

-- audit_logs indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_action ON audit_logs(action, created_at DESC);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_urls_updated_at
    BEFORE UPDATE ON urls
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-increment user url count
CREATE OR REPLACE FUNCTION increment_user_url_count()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NOT NULL THEN
        UPDATE users SET total_urls = total_urls + 1 WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_url_count
    AFTER INSERT ON urls
    FOR EACH ROW EXECUTE FUNCTION increment_user_url_count();

-- ============================================================
-- VIEWS
-- ============================================================

-- URL summary with analytics
CREATE OR REPLACE VIEW url_stats AS
SELECT
    u.id,
    u.short_code,
    u.original_url,
    u.title,
    u.is_active,
    u.expires_at,
    u.click_count,
    u.unique_clicks,
    u.created_at,
    u.last_accessed_at,
    usr.email AS owner_email,
    -- Last 7 days stats
    COUNT(a.id) FILTER (WHERE a.clicked_at >= NOW() - INTERVAL '7 days') AS clicks_7d,
    COUNT(a.id) FILTER (WHERE a.clicked_at >= NOW() - INTERVAL '30 days') AS clicks_30d
FROM urls u
LEFT JOIN users usr ON u.user_id = usr.id
LEFT JOIN analytics a ON u.id = a.url_id
GROUP BY u.id, usr.email;

-- ============================================================
-- MATERIALIZED VIEW for dashboard stats
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS dashboard_stats AS
SELECT
    DATE_TRUNC('day', clicked_at) AS day,
    short_code,
    COUNT(*) AS total_clicks,
    COUNT(*) FILTER (WHERE is_unique) AS unique_clicks,
    COUNT(DISTINCT country) AS countries,
    MODE() WITHIN GROUP (ORDER BY device_type) AS top_device,
    MODE() WITHIN GROUP (ORDER BY browser) AS top_browser,
    MODE() WITHIN GROUP (ORDER BY country) AS top_country
FROM analytics
WHERE clicked_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', clicked_at), short_code;

CREATE UNIQUE INDEX ON dashboard_stats(day, short_code);

-- Refresh function (called by cron job)
CREATE OR REPLACE FUNCTION refresh_dashboard_stats()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_stats;
END;
$$ LANGUAGE plpgsql;
