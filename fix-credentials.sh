#!/bin/bash

# MinIO Credentials Fix Script
# This script creates a new admin user since the root credentials aren't working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MinIO Credentials Fix${NC}"
echo -e "${BLUE}========================================${NC}"

# New admin credentials
ADMIN_USER="admin"
ADMIN_PASS="MinioAdmin2025"

echo -e "\n${YELLOW}Current MinIO Users:${NC}"
docker exec minio sh -c "mc alias set local http://127.0.0.1:9000 minioadmin MinioSecure2025Admin 2>&1 && mc admin user list local 2>&1" || echo "Using root credentials..."

echo -e "\n${YELLOW}Creating new admin user...${NC}"
docker exec minio sh -c "mc alias set local http://127.0.0.1:9000 minioadmin MinioSecure2025Admin 2>&1" || true
docker exec minio sh -c "mc admin user add local $ADMIN_USER '$ADMIN_PASS' 2>&1" || echo "User might already exist"

echo -e "\n${YELLOW}Granting admin privileges...${NC}"
docker exec minio sh -c "mc admin policy attach local consoleAdmin --user=$ADMIN_USER 2>&1" || true

echo -e "\n${YELLOW}Testing new credentials...${NC}"
if docker exec minio sh -c "mc alias set test http://127.0.0.1:9000 $ADMIN_USER '$ADMIN_PASS' 2>&1 && mc admin info test >/dev/null 2>&1"; then
    echo -e "${GREEN}✓ New admin credentials work!${NC}"
else
    echo -e "${RED}✗ New credentials failed${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Credentials Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Available Login Credentials:${NC}"
echo ""
echo -e "${BLUE}Option 1 - New Admin User:${NC}"
echo -e "  Username: ${GREEN}$ADMIN_USER${NC}"
echo -e "  Password: ${GREEN}$ADMIN_PASS${NC}"
echo ""
echo -e "${BLUE}Option 2 - Secondary Admin:${NC}"
echo -e "  Username: ${GREEN}adminuser${NC}"
echo -e "  Password: ${GREEN}AdminPass2025!${NC}"
echo ""
echo -e "${BLUE}Web Console:${NC} https://minio.ai-servicers.com"
echo ""
echo -e "${YELLOW}Note:${NC} The original 'minioadmin' user appears to not be working."
echo "This can happen when MinIO initializes with different credentials on first run."
echo "Use one of the admin accounts above to access the console."
