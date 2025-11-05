# MinIO Access Control Best Practices

## Overview
MinIO is configured with Keycloak SSO for user authentication and service accounts for application access. This ensures proper separation between human users and applications.

## Access Control Architecture

```
Users (via Keycloak SSO)
    ↓
Keycloak Groups → MinIO Policies
    ↓
Control what users can see/do in console

Applications (via Access Keys)
    ↓
Service Accounts → Bucket-specific Policies  
    ↓
Control what apps can access
```

## 1. Service Accounts for Applications

Each application gets its own access key/secret with limited permissions:

### Create Service Account Examples:
```bash
# For Plane application (access only to plane-uploads bucket)
docker exec minio sh -c "mc admin user svcacct add local minioadmin --policy plane-policy"

# For OpenProject (access only to openproject-files bucket)
docker exec minio sh -c "mc admin user svcacct add local minioadmin --policy openproject-policy"

# For Backup Service (access only to backup-archives bucket)
docker exec minio sh -c "mc admin user svcacct add local minioadmin --policy backup-policy"
```

### Benefits:
- Apps can't see each other's data
- Limited to specific buckets via policies
- Easy to revoke/rotate credentials
- Audit trail per application

## 2. SSO for Human Users

Users login via Keycloak with no direct access keys. Permissions are managed through Keycloak groups:

### Current Group Mappings:
- **administrators** group → `consoleAdmin` policy (full console admin)
- **developers** group → `developer-policy` (read/write specific buckets)
- **users** group → `user-readonly` (read-only access)

### To Add Users to Groups in Keycloak:
1. Login to Keycloak admin: https://keycloak.ai-servicers.com/admin
2. Navigate to Users → Select user → Groups tab
3. Add user to appropriate group

## 3. Available Buckets and Policies

### Buckets:
- `plane-uploads` - Plane project management uploads
- `openproject-files` - OpenProject file storage
- `backup-archives` - System backup storage
- `media-library` - Shared media files

### Policies:
- `plane-policy` - Access to plane-uploads only
- `openproject-policy` - Access to openproject-files only
- `developer-policy` - Read/write to media-library and plane-uploads
- `user-readonly` - Read-only access to all buckets
- `consoleAdmin` - Full administrative access

## 4. Separation of Concerns

This architecture ensures:
- **Applications** can only access their designated buckets
- **Users** can browse/manage based on their group membership
- **No credential sharing** between users and applications
- **Central management** of user permissions through Keycloak
- **Audit capability** to track access by users vs applications
- **Instant revocation** by disabling service account or removing from Keycloak group

## Common Operations

### List all service accounts:
```bash
docker exec minio sh -c "mc admin user svcacct list local"
```

### Create a new bucket:
```bash
docker exec minio sh -c "mc mb local/new-bucket-name"
```

### Create a custom policy:
```bash
# 1. Create policy JSON file
cat > /tmp/custom-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::bucket-name/*"]
    }
  ]
}
EOF

# 2. Apply the policy
docker cp /tmp/custom-policy.json minio:/tmp/
docker exec minio sh -c "mc admin policy create local custom-policy /tmp/custom-policy.json"
```

### Check user's effective permissions:
```bash
docker exec minio sh -c "mc admin user info local USERNAME"
```

## Security Best Practices

1. **Never share service account credentials** between applications
2. **Rotate credentials regularly** for service accounts
3. **Use least privilege principle** - only grant necessary permissions
4. **Monitor access logs** regularly
5. **Keep Keycloak groups simple** - avoid complex permission hierarchies
6. **Document all service accounts** and their purposes
7. **Use descriptive names** for policies and service accounts

## Troubleshooting

### User can't see buckets after SSO login:
- Check user's Keycloak groups
- Verify group mapping in `MINIO_IDENTITY_OPENID_ROLE_POLICY`
- Restart MinIO after configuration changes

### Application can't access bucket:
- Verify service account has correct policy
- Check bucket name in application configuration
- Test with mc client: `mc ls SERVICE_ACCOUNT_ALIAS/bucket-name`

### Policy changes not taking effect:
```bash
# Restart MinIO to reload policies
docker restart minio
```

## Configuration Files

- **Environment Variables**: `$HOME/projects/secrets/minio.env`
- **Deployment Script**: `/home/administrator/projects/minio/deploy.sh`
- **Bucket Setup**: `/home/administrator/projects/minio/setup-bucket-policies.sh`
- **Keycloak Setup**: `/home/administrator/projects/minio/setup-keycloak.sh`

---
*Last Updated: 2025-08-31*
*MinIO Version: RELEASE.2024-10-02T17-50-41Z*
*Authentication: Keycloak SSO + Service Accounts*