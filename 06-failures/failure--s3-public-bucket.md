# Failure: Accidentally Public S3 Bucket

## Overview
An S3 bucket that is publicly accessible exposes every file inside it to anyone on the internet — no authentication required. This has caused major breaches: medical records, financial documents, customer PII, source code, and credentials have all been leaked via misconfigured S3 buckets. The default changed in 2018 (new buckets are private by default), but legacy buckets, IAM policies, and bucket ACLs can override this. Misconfiguration is one configuration option away.

## Why It Happens

S3 has layered access controls that interact in non-obvious ways:
1. **Block Public Access settings** — account-level and bucket-level safeguards (can override everything else)
2. **Bucket ACL** — deprecated but still functional; `public-read` ACL makes everything public
3. **Bucket policy** — JSON policy; `"Principal": "*"` with `"Effect": "Allow"` = public
4. **Object ACL** — per-object access controls

Any one of these can inadvertently make a bucket public. The most common mistakes:
- Setting `"Principal": "*"` in a bucket policy thinking it means "any authenticated user" (it means anyone, unauthenticated)
- Copying a policy from a Stack Overflow answer without understanding it
- Infrastructure automation that creates buckets without enabling Block Public Access

## Correct Configuration

### Block Public Access (First Line of Defense)
```bash
# Enable at ACCOUNT level (blocks all new public settings)
aws s3control put-public-access-block \
  --account-id 123456789012 \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Also enable at BUCKET level
aws s3api put-public-access-block \
  --bucket my-private-bucket \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Enable at both levels. Account-level setting can be overridden by bucket-level settings — both must be set.

### IAM Least Privilege
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::my-bucket/uploads/*",
    "Condition": {
      "StringEquals": {
        "aws:PrincipalAccount": "123456789012"
      }
    }
  }]
}
```

Never `"Resource": "*"` for S3 operations. Scope to specific bucket and path prefix.

### Pre-Signed URLs for Private Asset Delivery
Users should never access S3 directly. Generate expiring pre-signed URLs:
```typescript
import { GetObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({ region: "us-east-1" });

async function getPrivateFileUrl(key: string): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
  });
  // URL expires in 15 minutes — not cached, not shareable long-term
  return getSignedUrl(s3, command, { expiresIn: 900 });
}
```

Pre-signed URLs require no bucket policy changes. The bucket remains completely private. Access is controlled by your backend.

## Audit Commands

```bash
# Find buckets with public access NOT blocked
aws s3api list-buckets --query 'Buckets[].Name' --output text | \
  xargs -I{} aws s3api get-public-access-block --bucket {} 2>/dev/null

# Find buckets with ACL-based public access
aws s3api list-buckets --query 'Buckets[].Name' --output text | \
  xargs -I{} sh -c 'aws s3api get-bucket-acl --bucket {} | grep -i public && echo "PUBLIC: {}"'

# Enable CloudTrail for S3 access logging
aws cloudtrail put-event-selectors --trail-name my-trail \
  --event-selectors '[{"DataResources":[{"Type":"AWS::S3::Object","Values":["arn:aws:s3"]}]}]'
```

## Key Rules
- Block Public Access enabled at account level AND bucket level for every bucket
- Pre-signed URLs (expiry 15 minutes) for all private asset delivery — never direct S3 URLs
- IAM policies scoped to specific bucket and prefix — never `s3:*` on `*`
- Audit all buckets monthly with automated script or AWS Config rule `s3-bucket-public-read-prohibited`
- CloudTrail S3 data events enabled for compliance and breach detection
- Terraform/CDK: always set `block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` to `true`
- Never store secrets, credentials, or private keys in S3 (even "private" buckets)
