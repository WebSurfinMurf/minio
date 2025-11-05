#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MinIO Keycloak SSO Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Configuration
KEYCLOAK_URL="https://keycloak.ai-servicers.com"
KEYCLOAK_INTERNAL="http://keycloak:8080"
REALM="master"
CLIENT_ID="minio"
REDIRECT_URI="https://minio.ai-servicers.com/*"

echo -e "\n${YELLOW}Setting up Keycloak client for MinIO...${NC}"

# Get admin token
echo -e "${YELLOW}Getting admin token...${NC}"
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin' \
  -d 'password=KeycloakAdmin2025' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Failed to get admin token${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Got admin token${NC}"

# Check if client exists
echo -e "${YELLOW}Checking if MinIO client exists...${NC}"
CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "${KEYCLOAK_URL}/admin/realms/$REALM/clients" | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .clientId' | wc -l)

if [ "$CLIENT_EXISTS" != "0" ]; then
    echo -e "${YELLOW}MinIO client already exists, deleting it...${NC}"
    # Get client UUID
    CLIENT_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "${KEYCLOAK_URL}/admin/realms/$REALM/clients" | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .id')
    
    # Delete existing client
    curl -s -X DELETE \
      -H "Authorization: Bearer $TOKEN" \
      "${KEYCLOAK_URL}/admin/realms/$REALM/clients/$CLIENT_UUID"
    echo -e "${GREEN}✓ Deleted existing client${NC}"
fi

# Create MinIO client
echo -e "${YELLOW}Creating MinIO client...${NC}"
CLIENT_SECRET=$(openssl rand -hex 32)

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  "${KEYCLOAK_URL}/admin/realms/$REALM/clients" \
  -d "{
    \"clientId\": \"$CLIENT_ID\",
    \"name\": \"MinIO Object Storage\",
    \"enabled\": true,
    \"clientAuthenticatorType\": \"client-secret\",
    \"secret\": \"$CLIENT_SECRET\",
    \"redirectUris\": [
      \"https://minio.ai-servicers.com/*\",
      \"https://s3.ai-servicers.com/*\",
      \"http://localhost:9090/*\"
    ],
    \"webOrigins\": [
      \"https://minio.ai-servicers.com\",
      \"https://s3.ai-servicers.com\"
    ],
    \"publicClient\": false,
    \"protocol\": \"openid-connect\",
    \"standardFlowEnabled\": true,
    \"implicitFlowEnabled\": true,
    \"directAccessGrantsEnabled\": true,
    \"serviceAccountsEnabled\": true,
    \"authorizationServicesEnabled\": false,
    \"attributes\": {
      \"backchannel.logout.session.required\": \"true\",
      \"backchannel.logout.revoke.offline.tokens\": \"false\"
    },
    \"defaultClientScopes\": [
      \"openid\",
      \"profile\",
      \"email\",
      \"roles\",
      \"groups\"
    ],
    \"optionalClientScopes\": [
      \"offline_access\"
    ]
  }"

echo -e "${GREEN}✓ MinIO client created${NC}"

# Create MinIO SSO environment file
echo -e "\n${YELLOW}Creating MinIO SSO environment file...${NC}"
cat > $HOME/projects/secrets/minio-sso.env << EOF
# MinIO Keycloak SSO Configuration
# Generated: $(date)

# OpenID Connect Configuration
MINIO_IDENTITY_OPENID_CONFIG_URL=${KEYCLOAK_INTERNAL}/realms/${REALM}/.well-known/openid-configuration
MINIO_IDENTITY_OPENID_CLIENT_ID=${CLIENT_ID}
MINIO_IDENTITY_OPENID_CLIENT_SECRET=${CLIENT_SECRET}
MINIO_IDENTITY_OPENID_DISPLAY_NAME=Keycloak SSO

# Claim mappings
MINIO_IDENTITY_OPENID_CLAIM_NAME=preferred_username
MINIO_IDENTITY_OPENID_CLAIM_PREFIX=""
MINIO_IDENTITY_OPENID_SCOPES=openid,profile,email,groups

# URLs (internal for server-to-server)
MINIO_IDENTITY_OPENID_REDIRECT_URI=https://minio.ai-servicers.com/oauth_callback
MINIO_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC=on

# Role mapping - map Keycloak groups to MinIO policies
MINIO_IDENTITY_OPENID_ROLE_POLICY="role:administrators=consoleAdmin,role:users=readwrite"

# Enable vendor-specific behavior for Keycloak
MINIO_IDENTITY_OPENID_VENDOR=keycloak

# Comment out the claim_userinfo if using access tokens
# MINIO_IDENTITY_OPENID_CLAIM_USERINFO=on
EOF

echo -e "${GREEN}✓ SSO environment file created${NC}"

# Merge SSO config with main MinIO env
echo -e "\n${YELLOW}Updating MinIO environment...${NC}"
cat $HOME/projects/secrets/minio-sso.env >> $HOME/projects/secrets/minio.env
echo -e "${GREEN}✓ MinIO environment updated${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Keycloak SSO Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Keycloak URL: ${KEYCLOAK_URL}"
echo "  Client ID: ${CLIENT_ID}"
echo "  Client Secret: Saved in $HOME/projects/secrets/minio-sso.env"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Restart MinIO: docker restart minio"
echo "2. Access MinIO at https://minio.ai-servicers.com"
echo "3. Use 'Login with SSO' option"
echo "4. Authenticate with Keycloak"
echo ""
echo -e "${BLUE}Note:${NC} Users in 'administrators' group will get admin access"