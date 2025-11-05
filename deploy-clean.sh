#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== MinIO Clean Deployment ===${NC}"

# Configuration
DATA_DIR="/home/administrator/projects/data/minio"
SECRETS_FILE="$HOME/projects/secrets/minio.env"

# Validation Step 1: Check environment file
echo -e "\n${YELLOW}Step 1: Validating environment file...${NC}"
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Environment file not found!${NC}"
    exit 1
fi

# Show what we're deploying with
echo -e "${GREEN}Using credentials from $SECRETS_FILE:${NC}"
grep "MINIO_ROOT_USER=" "$SECRETS_FILE"
echo "(password hidden)"

# Validation Step 2: Ensure clean data directory
echo -e "\n${YELLOW}Step 2: Checking data directory...${NC}"
if [ -d "$DATA_DIR/.minio.sys" ]; then
    echo -e "${RED}WARNING: Existing MinIO data found!${NC}"
    read -p "Delete existing data? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf "$DATA_DIR"
        mkdir -p "$DATA_DIR"
        echo -e "${GREEN}✓ Data directory cleaned${NC}"
    else
        echo -e "${YELLOW}Proceeding with existing data...${NC}"
    fi
else
    mkdir -p "$DATA_DIR"
    echo -e "${GREEN}✓ Clean data directory${NC}"
fi

# Validation Step 3: Stop existing container
echo -e "\n${YELLOW}Step 3: Removing existing container...${NC}"
docker stop minio 2>/dev/null || true
docker rm minio 2>/dev/null || true
echo -e "${GREEN}✓ Container removed${NC}"

# Validation Step 4: Deploy MinIO
echo -e "\n${YELLOW}Step 4: Deploying MinIO...${NC}"
docker run -d \
  --name minio \
  --network traefik-net \
  --env-file "$SECRETS_FILE" \
  -v "$DATA_DIR:/data" \
  --restart unless-stopped \
  --health-cmd="curl -f http://localhost:9000/minio/health/ready || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-net" \
  --label "traefik.http.routers.minio-console.rule=Host(\`minio.ai-servicers.com\`)" \
  --label "traefik.http.routers.minio-console.entrypoints=websecure" \
  --label "traefik.http.routers.minio-console.tls=true" \
  --label "traefik.http.routers.minio-console.tls.certresolver=letsencrypt" \
  --label "traefik.http.routers.minio-console.service=minio-console" \
  --label "traefik.http.services.minio-console.loadbalancer.server.port=9090" \
  --label "traefik.http.routers.minio-api.rule=Host(\`s3.ai-servicers.com\`)" \
  --label "traefik.http.routers.minio-api.entrypoints=websecure" \
  --label "traefik.http.routers.minio-api.tls=true" \
  --label "traefik.http.routers.minio-api.tls.certresolver=letsencrypt" \
  --label "traefik.http.routers.minio-api.service=minio-api" \
  --label "traefik.http.services.minio-api.loadbalancer.server.port=9000" \
  minio/minio:latest server /data --console-address ":9090"

# Validation Step 5: Wait for health
echo -e "\n${YELLOW}Step 5: Waiting for MinIO to be healthy...${NC}"
for i in {1..30}; do
    if docker exec minio curl -f http://localhost:9000/minio/health/ready &>/dev/null; then
        echo -e "${GREEN}✓ MinIO is healthy${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ MinIO health check failed${NC}"
        docker logs minio --tail 20
        exit 1
    fi
    sleep 2
done

# Validation Step 6: Test mc client
echo -e "\n${YELLOW}Step 6: Testing mc client access...${NC}"
if docker exec minio sh -c "mc alias set local http://127.0.0.1:9000 minioadmin 'MinioAdmin2025!' 2>&1 && mc admin info local >/dev/null 2>&1"; then
    echo -e "${GREEN}✓ MC client authentication successful${NC}"
else
    echo -e "${RED}✗ MC client authentication failed${NC}"
    exit 1
fi

# Validation Step 7: Check console access
echo -e "\n${YELLOW}Step 7: Checking console availability...${NC}"
if curl -s -I https://minio.ai-servicers.com -k | grep -q "200"; then
    echo -e "${GREEN}✓ Console is responding${NC}"
else
    echo -e "${YELLOW}⚠ Console may not be accessible${NC}"
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\n${YELLOW}Test Web Console:${NC}"
echo "1. Open: https://minio.ai-servicers.com"
echo "2. Try login with:"
echo "   Username: minioadmin"
echo "   Password: MinioAdmin2025!"
echo ""
echo "3. If login fails, try:"
echo "   - Clear ALL browser data for minio.ai-servicers.com"
echo "   - Try incognito/private mode"
echo "   - Try a different browser"
echo "   - Check browser console (F12) for errors"
echo ""
echo -e "${YELLOW}Test MC Client:${NC}"
echo "docker exec -it minio sh"
echo "mc alias set local http://127.0.0.1:9000 minioadmin 'MinioAdmin2025!'"
echo "mc ls local"