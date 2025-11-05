#!/bin/bash
set -e

echo "🚀 Deploying MinIO Object Storage"
echo "===================================="
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Environment file
ENV_FILE="$HOME/projects/secrets/minio.env"
DATA_DIR="/home/administrator/projects/data/minio"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Pre-deployment Checks ---
echo "🔍 Pre-deployment checks..."

# Check environment file
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment file exists${NC}"

# Source environment to check credentials
set -o allexport
source "$ENV_FILE"
set +o allexport

# Verify required variables
if [ -z "$MINIO_ROOT_USER" ] || [ -z "$MINIO_ROOT_PASSWORD" ]; then
    echo -e "${RED}❌ MINIO_ROOT_USER or MINIO_ROOT_PASSWORD not set${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment variables validated${NC}"

# Check if network exists
if ! docker network inspect traefik-net &>/dev/null; then
    echo -e "${RED}❌ traefik-net network not found${NC}"
    echo "Run: /home/administrator/projects/infrastructure/setup-networks.sh"
    exit 1
fi
echo -e "${GREEN}✅ Required network exists${NC}"

# Create data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
    echo "Creating MinIO data directory..."
    mkdir -p "$DATA_DIR"
    chmod 755 "$DATA_DIR"
fi
echo -e "${GREEN}✅ MinIO data directory ready${NC}"

# Check for existing data and warn if found
if [ -d "$DATA_DIR/.minio.sys" ]; then
    echo -e "${YELLOW}⚠️  Existing MinIO data found - keeping existing data${NC}"
fi

# Validate docker-compose.yml syntax
echo ""
echo "✅ Validating docker-compose.yml..."
if ! docker compose config > /dev/null 2>&1; then
    echo -e "${RED}❌ docker-compose.yml validation failed${NC}"
    docker compose config
    exit 1
fi
echo -e "${GREEN}✅ docker-compose.yml is valid${NC}"

# --- Deployment ---
echo ""
echo "🚀 Deploying MinIO..."
docker compose up -d --remove-orphans

# --- Post-deployment Validation ---
echo ""
echo "⏳ Waiting for MinIO to be ready..."
timeout 60 bash -c 'until docker exec minio curl -f http://localhost:9000/minio/health/ready &>/dev/null; do sleep 2; done' || {
    echo -e "${RED}❌ MinIO health check failed${NC}"
    docker logs minio --tail 30
    exit 1
}
echo -e "${GREEN}✅ MinIO is healthy${NC}"

# Test MC client authentication
echo ""
echo "⏳ Testing MC client authentication..."
if docker exec minio sh -c "mc alias set local http://127.0.0.1:9000 $MINIO_ROOT_USER '$MINIO_ROOT_PASSWORD' 2>&1 && mc admin info local >/dev/null 2>&1"; then
    echo -e "${GREEN}✅ MC client authentication successful${NC}"
else
    echo -e "${YELLOW}⚠️  MC client authentication issue (may be expected on first start)${NC}"
fi

# --- Summary ---
echo ""
echo "=========================================="
echo "✅ MinIO Deployment Summary"
echo "=========================================="
echo "Container: minio"
echo "Image: minio/minio:RELEASE.2024-10-02T17-50-41Z"
echo "Networks: traefik-net"
echo "Data: $DATA_DIR"
echo ""
echo "Access:"
echo "  - Console (Web UI): https://minio.ai-servicers.com"
echo "  - S3 API: https://s3.ai-servicers.com"
echo "  - Internal S3: http://minio:9000"
echo "  - Internal Console: http://minio:9090"
echo ""
echo "Authentication:"
echo "  - Console: Keycloak SSO (click 'Login with SSO')"
echo "  - S3 API: Service account credentials"
echo "  - Root User: $MINIO_ROOT_USER"
echo ""
echo "Management:"
echo "  - Service Accounts: $HOME/projects/secrets/minio-service-accounts.md"
echo "  - Bucket Policies: ./setup-bucket-policies.sh"
echo ""
echo "=========================================="
echo ""
echo "📊 View logs:"
echo "   docker logs minio -f"
echo ""
echo "🔧 MC Client:"
echo "   docker exec -it minio sh"
echo "   mc alias set local http://127.0.0.1:9000 $MINIO_ROOT_USER 'PASSWORD'"
echo ""
echo "✅ Deployment complete!"
