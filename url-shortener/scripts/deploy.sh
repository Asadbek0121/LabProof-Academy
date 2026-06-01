#!/bin/bash
# ============================================================
# deploy.sh — One-command deployment script
# Usage: ./scripts/deploy.sh [local|docker|k8s]
# ============================================================
set -euo pipefail

MODE=${1:-docker}
IMAGE_TAG=${IMAGE_TAG:-latest}
REGISTRY=${REGISTRY:-}
IMAGE_NAME="url-shortener"

log()  { echo -e "\033[0;32m[DEPLOY] $*\033[0m"; }
warn() { echo -e "\033[0;33m[WARN]   $*\033[0m"; }
err()  { echo -e "\033[0;31m[ERROR]  $*\033[0m" >&2; exit 1; }

# ── Check prerequisites ────────────────────────────────────────
check_deps() {
  log "Checking dependencies..."
  for cmd in docker node; do
    command -v "$cmd" >/dev/null 2>&1 || err "$cmd is required but not installed."
  done
  if [[ "$MODE" == "k8s" ]]; then
    command -v kubectl >/dev/null 2>&1 || err "kubectl is required for k8s mode."
  fi
}

# ── Build Docker image ─────────────────────────────────────────
build_image() {
  log "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}..."
  docker build \
    --target production \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --tag "${IMAGE_NAME}:latest" \
    --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --label "git.commit=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    .
  log "Image built successfully."

  if [[ -n "$REGISTRY" ]]; then
    log "Pushing to registry ${REGISTRY}..."
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
  fi
}

# ── Copy .env if not exists ────────────────────────────────────
setup_env() {
  if [[ ! -f .env ]]; then
    warn ".env not found. Copying from .env.example..."
    cp .env.example .env
    warn "Please edit .env with your secrets before proceeding!"
    if [[ -t 0 ]]; then
      read -rp "Press Enter to continue (or Ctrl+C to abort)..."
    else
      log "Non-interactive environment detected. Continuing automatically..."
    fi
  fi
}

# ── Local mode ─────────────────────────────────────────────────
deploy_local() {
  log "Starting local development server..."
  npm install
  npm run dev
}

# ── Docker Compose mode ────────────────────────────────────────
deploy_docker() {
  log "Deploying with Docker Compose..."
  setup_env
  build_image

  docker-compose down --remove-orphans 2>/dev/null || true
  docker-compose up -d

  log "Waiting for services to be healthy..."
  sleep 5

  for i in {1..30}; do
    if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
      log "✅ Application is healthy!"
      log "  API:      http://localhost:3000"
      log "  Grafana:  http://localhost:3001  (admin / \${GRAFANA_PASSWORD})"
      log "  Prometheus: http://localhost:9090"
      break
    fi
    [[ $i -eq 30 ]] && err "Application failed to start after 30 seconds."
    sleep 1
  done
}

# ── Kubernetes mode ────────────────────────────────────────────
deploy_k8s() {
  log "Deploying to Kubernetes..."
  [[ -z "$REGISTRY" ]] && err "Set REGISTRY env var for Kubernetes deployments."

  build_image

  log "Applying Kubernetes manifests..."
  kubectl apply -f k8s/00-namespace.yaml
  kubectl apply -f k8s/01-config.yaml
  kubectl apply -f k8s/02-databases.yaml

  log "Waiting for databases to be ready..."
  kubectl wait --namespace url-shortener \
    --for=condition=ready pod \
    --selector=app=postgres \
    --timeout=120s

  kubectl wait --namespace url-shortener \
    --for=condition=ready pod \
    --selector=app=redis \
    --timeout=60s

  kubectl apply -f k8s/03-deployment.yaml
  kubectl apply -f k8s/04-ingress-netpol.yaml
  kubectl apply -f k8s/05-cronjobs.yaml

  # Update image in deployment
  kubectl set image deployment/url-shortener \
    url-shortener="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" \
    --namespace url-shortener

  log "Waiting for rollout to complete..."
  kubectl rollout status deployment/url-shortener --namespace url-shortener --timeout=300s

  log "✅ Kubernetes deployment complete!"
  kubectl get pods --namespace url-shortener
}

# ── Run migration ──────────────────────────────────────────────
run_migration() {
  log "Running database migration..."
  node scripts/migrate.js
}

# ── Main ───────────────────────────────────────────────────────
check_deps

case "$MODE" in
  local)  deploy_local  ;;
  docker) deploy_docker ;;
  k8s)    deploy_k8s    ;;
  migrate) run_migration ;;
  *)      err "Unknown mode: $MODE. Use: local | docker | k8s | migrate" ;;
esac
