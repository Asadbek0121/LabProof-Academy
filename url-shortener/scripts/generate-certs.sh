#!/bin/bash
# ============================================================
# generate-certs.sh — Generates self-signed SSL certs for local development/docker Nginx
# ============================================================
set -euo pipefail

SSL_DIR="$(dirname "$0")/../nginx/ssl"
mkdir -p "$SSL_DIR"

log() { echo -e "\033[0;32m[SSL] $*\033[0m"; }

log "Generating self-signed SSL certificate for local development..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${SSL_DIR}/key.pem" \
  -out "${SSL_DIR}/cert.pem" \
  -subj "/C=US/ST=State/L=City/O=Development/CN=short.ly" \
  -addext "subjectAltName=DNS:short.ly,DNS:www.short.ly,DNS:localhost"

log "SSL Certificates generated successfully:"
log "  Cert: ${SSL_DIR}/cert.pem"
log "  Key:  ${SSL_DIR}/key.pem"
