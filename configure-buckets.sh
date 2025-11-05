#!/bin/bash

# MinIO Initial Configuration Script
# Creates buckets and service accounts for applications

set -e

# Configuration
CONTAINER_NAME="minio"
MC_ALIAS="local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MinIO Bucket Configuration${NC}"
echo -e "${BLUE}========================================${NC}"

# Install mc (MinIO Client) in the container if not present
echo -e "\n${YELLOW}Setting up MinIO client...${NC}"
docker exec $CONTAINER_NAME sh -c "
if ! command -v mc &> /dev/null; then
    wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
fi
"

# Configure mc to connect to local MinIO
echo -e "${YELLOW}Configuring MinIO client connection...${NC}"
docker exec $CONTAINER_NAME mc alias set $MC_ALIAS http://localhost:9000 minioadmin 'MinioSecure2025Admin' --api S3v4

# Create buckets
echo -e "\n${YELLOW}Creating application buckets...${NC}"

# Plane bucket
echo -e "Creating bucket: ${BLUE}plane-uploads${NC}"
docker exec $CONTAINER_NAME mc mb $MC_ALIAS/plane-uploads --ignore-existing

# OpenProject bucket
echo -e "Creating bucket: ${BLUE}openproject-files${NC}"
docker exec $CONTAINER_NAME mc mb $MC_ALIAS/openproject-files --ignore-existing

# Backup bucket
echo -e "Creating bucket: ${BLUE}backup-archives${NC}"
docker exec $CONTAINER_NAME mc mb $MC_ALIAS/backup-archives --ignore-existing

# Media library bucket
echo -e "Creating bucket: ${BLUE}media-library${NC}"
docker exec $CONTAINER_NAME mc mb $MC_ALIAS/media-library --ignore-existing

# Set bucket policies to private by default
echo -e "\n${YELLOW}Setting bucket policies...${NC}"
docker exec $CONTAINER_NAME mc anonymous set none $MC_ALIAS/plane-uploads
docker exec $CONTAINER_NAME mc anonymous set none $MC_ALIAS/openproject-files
docker exec $CONTAINER_NAME mc anonymous set none $MC_ALIAS/backup-archives
docker exec $CONTAINER_NAME mc anonymous set none $MC_ALIAS/media-library

# Create service account for Plane
echo -e "\n${YELLOW}Creating service accounts...${NC}"
echo -e "Creating service account for ${BLUE}Plane${NC}"

# Generate access key for Plane
PLANE_CREDS=$(docker exec $CONTAINER_NAME mc admin user add $MC_ALIAS plane-user 'PlaneAccess2025!' 2>&1 || true)

# Create policy for Plane
echo -e "${YELLOW}Creating IAM policy for Plane...${NC}"
docker exec $CONTAINER_NAME sh -c 'cat > /tmp/plane-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::plane-uploads",
        "arn:aws:s3:::plane-uploads/*"
      ]
    }
  ]
}
EOF'

# Apply the policy
docker exec $CONTAINER_NAME mc admin policy create $MC_ALIAS plane-policy /tmp/plane-policy.json
docker exec $CONTAINER_NAME mc admin policy attach $MC_ALIAS plane-policy --user plane-user

# Enable versioning on important buckets
echo -e "\n${YELLOW}Enabling versioning...${NC}"
docker exec $CONTAINER_NAME mc version enable $MC_ALIAS/backup-archives

# List all buckets
echo -e "\n${YELLOW}Listing all buckets:${NC}"
docker exec $CONTAINER_NAME mc ls $MC_ALIAS

# Display configuration summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Buckets Created:${NC}"
echo -e "  • plane-uploads"
echo -e "  • openproject-files"
echo -e "  • backup-archives (versioning enabled)"
echo -e "  • media-library"
echo ""
echo -e "${YELLOW}Service Account Created:${NC}"
echo -e "  Username: ${BLUE}plane-user${NC}"
echo -e "  Password: ${BLUE}PlaneAccess2025!${NC}"
echo ""
echo -e "${YELLOW}Update Plane configuration:${NC}"
echo "Add these to plane.env:"
echo -e "${BLUE}AWS_ACCESS_KEY_ID=plane-user${NC}"
echo -e "${BLUE}AWS_SECRET_ACCESS_KEY=PlaneAccess2025!${NC}"
echo -e "${BLUE}AWS_S3_ENDPOINT_URL=http://minio:9000${NC}"
echo -e "${BLUE}AWS_S3_BUCKET_NAME=plane-uploads${NC}"
echo ""
echo -e "${YELLOW}Test S3 connectivity:${NC}"
echo "docker exec $CONTAINER_NAME mc ls $MC_ALIAS/plane-uploads"