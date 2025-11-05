#!/bin/bash

# Test MinIO login credentials
# This script tests which credentials actually work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MinIO Login Test${NC}"
echo -e "${BLUE}========================================${NC}"

# Wait for MinIO to be ready
echo -e "\n${YELLOW}Waiting for MinIO to be ready...${NC}"
for i in {1..30}; do
    if docker exec minio curl -f http://localhost:9000/minio/health/ready &>/dev/null; then
        echo -e "${GREEN}✓ MinIO is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ MinIO not ready after 30 seconds${NC}"
        exit 1
    fi
    sleep 1
done

echo -e "\n${YELLOW}Testing credentials with mc client...${NC}"
echo ""

# Test root user
echo -e "${BLUE}1. Testing root user (minioadmin):${NC}"
if docker exec minio sh -c "mc alias set test1 http://127.0.0.1:9000 minioadmin 'MinioSecure2025Admin' 2>&1 && mc admin info test1 >/dev/null 2>&1"; then
    echo -e "   ${GREEN}✓ Works with mc client${NC}"
    echo -e "   Username: ${GREEN}minioadmin${NC}"
    echo -e "   Password: ${GREEN}MinioSecure2025Admin${NC}"
else
    echo -e "   ${RED}✗ Failed${NC}"
fi

# Test admin user
echo -e "\n${BLUE}2. Testing admin user:${NC}"
if docker exec minio sh -c "mc alias set test2 http://127.0.0.1:9000 admin 'MinioAdmin2025' 2>&1 && mc ls test2 >/dev/null 2>&1"; then
    echo -e "   ${GREEN}✓ Works with mc client${NC}"
    echo -e "   Username: ${GREEN}admin${NC}"
    echo -e "   Password: ${GREEN}MinioAdmin2025${NC}"
else
    echo -e "   ${RED}✗ Failed${NC}"
fi

# List all users
echo -e "\n${YELLOW}All configured users:${NC}"
docker exec minio sh -c "mc admin user list test1 2>&1" || echo "Could not list users"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT NOTES:${NC}"
echo ""
echo "1. The credentials above work with the mc client (MinIO CLI)"
echo "2. For web console access at https://minio.ai-servicers.com:"
echo "   - Try the root user credentials first (minioadmin)"
echo "   - Clear browser cache/cookies if login fails"
echo "   - Try incognito/private browsing mode"
echo "   - Check browser console for errors (F12)"
echo ""
echo "3. If web console still doesn't work, the issue might be:"
echo "   - Browser caching old session"
echo "   - CORS/CSP policy issues"
echo "   - MinIO console bug with certain password characters"
echo ""
echo -e "${BLUE}To access MinIO data via CLI:${NC}"
echo "  docker exec -it minio sh"
echo "  mc alias set local http://127.0.0.1:9000 minioadmin 'MinioSecure2025Admin'"
echo "  mc ls local"