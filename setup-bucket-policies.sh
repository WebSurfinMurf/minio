#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MinIO Bucket Access Control Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Create buckets for different applications
echo -e "\n${YELLOW}Creating application buckets...${NC}"
docker exec minio sh -c "
mc mb local/plane-uploads --ignore-existing
mc mb local/openproject-files --ignore-existing
mc mb local/backup-archives --ignore-existing
mc mb local/media-library --ignore-existing
"
echo -e "${GREEN}✓ Buckets created${NC}"

# Create a policy for Plane application
echo -e "\n${YELLOW}Creating Plane application policy...${NC}"
cat > /tmp/plane-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::plane-uploads",
        "arn:aws:s3:::plane-uploads/*"
      ]
    }
  ]
}
EOF

docker cp /tmp/plane-policy.json minio:/tmp/plane-policy.json
docker exec minio sh -c "mc admin policy create local plane-policy /tmp/plane-policy.json"
echo -e "${GREEN}✓ Plane policy created${NC}"

# Create a policy for OpenProject
echo -e "\n${YELLOW}Creating OpenProject policy...${NC}"
cat > /tmp/openproject-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::openproject-files",
        "arn:aws:s3:::openproject-files/*"
      ]
    }
  ]
}
EOF

docker cp /tmp/openproject-policy.json minio:/tmp/openproject-policy.json
docker exec minio sh -c "mc admin policy create local openproject-policy /tmp/openproject-policy.json"
echo -e "${GREEN}✓ OpenProject policy created${NC}"

# Create read-only policy for users to view all buckets
echo -e "\n${YELLOW}Creating user read-only policy...${NC}"
cat > /tmp/user-readonly-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    }
  ]
}
EOF

docker cp /tmp/user-readonly-policy.json minio:/tmp/user-readonly-policy.json
docker exec minio sh -c "mc admin policy create local user-readonly /tmp/user-readonly-policy.json"
echo -e "${GREEN}✓ User read-only policy created${NC}"

# Create developer policy (read-write to specific buckets)
echo -e "\n${YELLOW}Creating developer policy...${NC}"
cat > /tmp/developer-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::media-library",
        "arn:aws:s3:::media-library/*",
        "arn:aws:s3:::plane-uploads",
        "arn:aws:s3:::plane-uploads/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": ["arn:aws:s3:::*"]
    }
  ]
}
EOF

docker cp /tmp/developer-policy.json minio:/tmp/developer-policy.json
docker exec minio sh -c "mc admin policy create local developer-policy /tmp/developer-policy.json"
echo -e "${GREEN}✓ Developer policy created${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Bucket Policies Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Available Policies:${NC}"
docker exec minio sh -c "mc admin policy list local"

echo -e "\n${YELLOW}To create service accounts for applications:${NC}"
echo ""
echo "# For Plane application:"
echo "docker exec minio sh -c \"mc admin user svcacct add local minioadmin --policy plane-policy\""
echo ""
echo "# For OpenProject:"
echo "docker exec minio sh -c \"mc admin user svcacct add local minioadmin --policy openproject-policy\""
echo ""
echo -e "${YELLOW}To map Keycloak groups to policies:${NC}"
echo "Update MINIO_IDENTITY_OPENID_ROLE_POLICY in minio.env:"
echo "  role:administrators=consoleAdmin"
echo "  role:developers=developer-policy"
echo "  role:users=user-readonly"
echo ""
echo -e "${BLUE}Note:${NC} Service accounts are tied to applications, not users."
echo "Users access through SSO with group-based permissions."