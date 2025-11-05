#!/bin/bash
set -e

echo "Setting up MCP Storage in MinIO..."

# MinIO admin credentials
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="MinioAdmin2025!"

# Configure mc alias
docker exec minio sh -c "mc alias set local http://127.0.0.1:9000 ${MINIO_ROOT_USER} '${MINIO_ROOT_PASSWORD}'"

# Create mcp-storage bucket
echo "Creating mcp-storage bucket..."
docker exec minio sh -c "mc mb local/mcp-storage --ignore-existing"

# Create directories in bucket
echo "Creating directory structure..."
docker exec minio sh -c "mc cp /dev/null local/mcp-storage/screenshots/.keep"
docker exec minio sh -c "mc cp /dev/null local/mcp-storage/uploads/.keep"
docker exec minio sh -c "mc cp /dev/null local/mcp-storage/temp/.keep"

# Create bucket policy for public read access (authenticated via Keycloak groups)
echo "Creating bucket policy..."
cat > /tmp/mcp-storage-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": ["*"]
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mcp-storage/*",
        "arn:aws:s3:::mcp-storage"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": ["arn:aws:s3:::root"]
      },
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::mcp-storage/*",
        "arn:aws:s3:::mcp-storage"
      ]
    }
  ]
}
EOF

# Apply bucket policy
docker cp /tmp/mcp-storage-policy.json minio:/tmp/
docker exec minio sh -c "mc policy set-json /tmp/mcp-storage-policy.json local/mcp-storage"

# Alternative: Set bucket to public for read access
echo "Setting bucket access policy to public..."
docker exec minio sh -c "mc anonymous set download local/mcp-storage"

# Create service account for MCP operations
echo "Creating MCP service account..."
docker exec minio sh -c "mc admin user svcacct add local minioadmin" > /tmp/mcp-service-account.txt 2>&1 || true

# Extract credentials
if [ -f /tmp/mcp-service-account.txt ]; then
    ACCESS_KEY=$(grep "Access Key:" /tmp/mcp-service-account.txt | awk '{print $3}')
    SECRET_KEY=$(grep "Secret Key:" /tmp/mcp-service-account.txt | awk '{print $3}')
    
    if [ ! -z "$ACCESS_KEY" ]; then
        echo ""
        echo "Service account created:"
        echo "Access Key: $ACCESS_KEY"
        echo "Secret Key: $SECRET_KEY"
        
        # Update the mcp-minio.env file
        cat > $HOME/projects/secrets/mcp-minio-actual.env << EOF
# MCP MinIO Service Configuration
MINIO_ENDPOINT=minio:9000
MINIO_EXTERNAL_ENDPOINT=https://s3.ai-servicers.com
MINIO_ACCESS_KEY=$ACCESS_KEY
MINIO_SECRET_KEY=$SECRET_KEY
MINIO_BUCKET=mcp-storage
MINIO_USE_SSL=false
EOF
        echo "Credentials saved to $HOME/projects/secrets/mcp-minio-actual.env"
    fi
fi

# Create a test file
echo "Creating test file..."
echo "This is a test document for MCP storage" > /tmp/test-document.txt
docker cp /tmp/test-document.txt minio:/tmp/
docker exec minio sh -c "mc cp /tmp/test-document.txt local/mcp-storage/uploads/test-document.txt"

# Generate presigned URL
echo ""
echo "Generating test URLs..."
docker exec minio sh -c "mc share download local/mcp-storage/uploads/test-document.txt --expire=24h" | sed 's|http://127.0.0.1:9000|https://s3.ai-servicers.com|g'

echo ""
echo "✅ MCP Storage setup complete!"
echo ""
echo "Bucket: mcp-storage"
echo "Public URL: https://s3.ai-servicers.com/mcp-storage/"
echo "Console: https://minio.ai-servicers.com (login with Keycloak SSO)"
echo ""
echo "Test URLs:"
echo "  https://s3.ai-servicers.com/mcp-storage/uploads/test-document.txt"
echo ""
echo "Note: Files are publicly readable via direct URL."
echo "For private access, use presigned URLs with expiration."