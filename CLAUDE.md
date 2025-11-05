# MinIO - Central Object Storage Service

## Executive Summary
MinIO is a high-performance, S3-compatible object storage system. Successfully deployed with Keycloak SSO integration after experiencing issues with basic console authentication.

## Current Status ✅
- **S3 API**: ✅ Working perfectly at https://s3.ai-servicers.com
- **MC Client**: ✅ Working with root credentials
- **Web Console**: ✅ Working via Keycloak SSO at https://minio.ai-servicers.com
- **Authentication**: ✅ Keycloak SSO for users, Service Accounts for applications
- **Access Control**: ✅ Policy-based bucket isolation for applications

## Solution Overview

### The Problem
Newer versions of MinIO (2024+) had issues with basic authentication in the web console. While the S3 API and MC client worked perfectly with root credentials, the web console would reject all login attempts with "invalid login" errors.

### The Solution
Integrated MinIO with Keycloak SSO, which:
1. Bypassed the console authentication issues
2. Provided centralized user management
3. Enabled group-based access control
4. Maintained compatibility with service accounts for applications

## Architecture

### Authentication Flow
```
Users (Human Access)
    ↓
Keycloak SSO → MinIO Console
    ↓
Group-based Policies (administrators, developers, users)

Applications (Programmatic Access)
    ↓
Service Accounts → S3 API
    ↓
Bucket-specific Policies (plane-policy, backup-policy, etc.)
```

### Current Configuration

#### Keycloak Integration
- **Client ID**: minio
- **Client Secret**: JtlMtJZZyDc371EejEmkDC6Bwn72L1es
- **Config URL**: http://keycloak:8080/realms/master/.well-known/openid-configuration
- **Vendor**: keycloak

#### Group Mappings
- `administrators` → consoleAdmin (full admin access)
- `developers` → developer-policy (read/write media & plane buckets)
- `users` → user-readonly (read-only access to all buckets)

#### Buckets
- `plane-uploads` - Plane project management files
- `openproject-files` - OpenProject document storage
- `backup-archives` - System backup storage
- `media-library` - Shared media files
- `mcp-storage` - AI/MCP generated content (screenshots, uploads, temp files)

## Service Accounts

### Management
Service accounts are documented in `$HOME/projects/secrets/minio-service-accounts.md`

**Purpose**: This file contains all service account credentials for applications that need S3 access. It includes:
- Access keys and secret keys for each application
- Policy assignments and permissions
- Configuration examples for applications
- Management commands for service accounts

**Security Note**: This file contains sensitive credentials and should NEVER be committed to version control.

### Created Accounts

#### 1. Plane Application
- **Access Key**: VQUR5MZF6HHADT9TCEKF
- **Policy**: plane-policy
- **Access**: plane-uploads bucket only

#### 2. Backup Service
- **Access Key**: P4L4FC335O6LF0ADNFBL
- **Policy**: backup-policy
- **Access**: backup-archives bucket only

### Creating New Service Accounts
```bash
# Create service account
docker exec minio sh -c "mc admin user svcacct add local minioadmin"

# Attach specific policy
docker exec minio sh -c "mc admin policy attach local POLICY_NAME --user=ACCESS_KEY"

# Edit policy (if needed)
docker exec minio sh -c "mc admin user svcacct edit local ACCESS_KEY --policy=/tmp/policy.json"
```

## File Locations

### Configuration Files
- **Environment Variables**: `$HOME/projects/secrets/minio.env`
  - Contains root credentials, Keycloak SSO config, and MinIO settings
  
- **SSO Configuration**: `$HOME/projects/secrets/minio-sso.env`
  - Keycloak-specific settings (merged into minio.env)
  
- **Service Accounts**: `$HOME/projects/secrets/minio-service-accounts.md`
  - All application service account credentials
  - Policy assignments and permissions
  - Configuration examples for applications

### Scripts
- **Main Deployment**: `/home/administrator/projects/minio/deploy.sh`
  - Primary deployment script with all configurations
  
- **Bucket Policies**: `/home/administrator/projects/minio/setup-bucket-policies.sh`
  - Creates buckets and policies for applications
  
- **Keycloak Setup**: `/home/administrator/projects/minio/setup-keycloak.sh`
  - Configures Keycloak client for MinIO SSO

### Documentation
- **README**: `/home/administrator/projects/minio/README.md`
  - Access control best practices
  - Common operations
  - Troubleshooting guide

## Access Methods

### Web Console (Users)
- URL: https://minio.ai-servicers.com
- Login: Click "Login with SSO" → Authenticate with Keycloak
- Permissions: Based on Keycloak group membership

### S3 API (Applications)
- Endpoint: https://s3.ai-servicers.com
- Authentication: Service account access/secret keys
- Permissions: Bucket-specific policies

### MC Client (Administration)
```bash
docker exec -it minio sh
mc alias set local http://127.0.0.1:9000 minioadmin 'MinioAdmin2025!'
mc admin info local
```

## Common Operations

### List All Service Accounts
```bash
docker exec minio sh -c "mc admin user svcacct list local"
```

### Create New Bucket
```bash
docker exec minio sh -c "mc mb local/bucket-name"
```

### Check User Permissions
```bash
docker exec minio sh -c "mc admin user info local USERNAME"
```

### View Policies
```bash
docker exec minio sh -c "mc admin policy list local"
```

## Troubleshooting

### Console Login Issues
1. Ensure user is in appropriate Keycloak group
2. Check MinIO logs: `docker logs minio --tail 50`
3. Verify SSO configuration is loaded: `docker exec minio printenv | grep MINIO_IDENTITY`

### Service Account Access Issues
1. Verify policy is attached: `mc admin user svcacct info local ACCESS_KEY`
2. Test with mc client: `mc alias set test http://localhost:9000 ACCESS_KEY SECRET_KEY`
3. Check bucket exists: `mc ls test/`

### Policy Not Working
1. Restart MinIO to reload policies: `docker restart minio`
2. Check policy syntax: `mc admin policy info local POLICY_NAME`
3. Verify resource ARNs match bucket names

## Version Information
- **MinIO Version**: RELEASE.2024-10-02T17-50-41Z
- **Deployment Date**: 2025-08-31
- **Authentication**: Keycloak SSO + Service Accounts
- **Container**: minio/minio:RELEASE.2024-10-02T17-50-41Z

## Key Learnings

1. **Console Authentication**: Newer MinIO versions (2024+) have issues with basic auth in console
2. **SSO Solution**: Keycloak integration bypasses console auth issues completely
3. **Service Accounts**: Inherit parent permissions by default - must explicitly set policies
4. **Policy Format**: Remove quotes from ROLE_POLICY environment variable
5. **Network Configuration**: Use internal URLs (http://keycloak:8080) for container-to-container communication
6. **Access Control**: Separate human users (SSO) from applications (service accounts) for better security

## MCP Storage Integration (2025-09-07)

### MCP Storage Bucket Configuration
- **Bucket**: `mcp-storage`
- **Access**: Requires Keycloak authentication (any authenticated user can read)
- **Directories**: 
  - `/screenshots/` - AI-generated screenshots
  - `/uploads/` - User uploaded files
  - `/temp/` - Temporary processing files

### Authentication Policy
- **Public Access**: Removed - files require authentication
- **Authenticated Users**: All Keycloak users can read via `authenticated-read-policy`
- **Presigned URLs**: AI generates time-limited URLs for sharing (24-hour default)
- **Direct URLs**: Return 404 without authentication

### Access Methods
1. **MinIO Console**: Login at https://minio.ai-servicers.com with SSO
2. **Presigned URLs**: Generated by AI for sharing without login
3. **S3 API**: Service accounts for programmatic access

## Success Metrics
- ✅ S3 API fully functional for applications
- ✅ Web console accessible via Keycloak SSO
- ✅ Service accounts isolated to specific buckets
- ✅ Group-based access control for users
- ✅ MC client working for administration
- ✅ All buckets created and policies configured
- ✅ MCP storage integrated with authentication

---
*Last Updated: 2025-09-07*
*Status: Fully Operational with Keycloak SSO and MCP Integration*