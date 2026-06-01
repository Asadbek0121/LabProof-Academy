# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies (separate layer for cache efficiency)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ── Production stage ──────────────────────────────────────────────────────────
FROM node:20-alpine AS production

# Security: non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy deps from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy application source
COPY --chown=appuser:appgroup . .

# Create logs directory
RUN mkdir -p logs && chown -R appuser:appgroup logs

# Remove dev files
RUN rm -rf .env* .git* tests/ *.test.js

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3000

# Health check (used by Docker & Kubernetes)
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Use dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
