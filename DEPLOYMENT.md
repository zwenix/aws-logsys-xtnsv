# Deployment Guide

This guide provides detailed step-by-step instructions for deploying the Log Service Platform to AWS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Validation](#post-deployment-validation)
5. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
- **Terraform** (>= 1.6.0): [Download](https://developer.hashicorp.com/terraform/downloads)
- **AWS CLI** (>= 2.0): [Download](https://aws.amazon.com/cli/)
- **Git**: [Download](https://git-scm.com/downloads)
- **curl**: Usually pre-installed on Unix systems
- **jq** (optional): For JSON parsing in test scripts

### AWS Requirements
- AWS Account with appropriate permissions
- IAM user with the following permissions:
  - DynamoDB: CreateTable, DescribeTable, DeleteTable
  - Lambda: CreateFunction, GetFunction, DeleteFunction, UpdateFunctionCode
  - IAM: CreateRole, AttachRolePolicy, PutRolePolicy
  - CloudWatch: CreateLogGroup, PutRetentionPolicy
  - S3: CreateBucket (for Terraform state, optional)

### Recommended IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:*",
        "lambda:*",
        "iam:*",
        "logs:*",
        "events:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Pre-Deployment Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform installed (version >= 1.6.0)
- [ ] AWS credentials configured with proper permissions
- [ ] Git repository cloned locally
- [ ] AWS region selected (default: us-east-1)
- [ ] Project name and environment defined

## Deployment Steps

### Step 1: Configure AWS Credentials

**Option A: Using AWS CLI**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter output format (json recommended)
```

**Option B: Using Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Verify Configuration**
```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 2: Prepare Terraform Configuration

```bash
# Navigate to infrastructure directory
cd infrastructure

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit variables file
nano terraform.tfvars  # or use your preferred editor
```

**Example Configuration:**
```hcl
# terraform.tfvars
aws_region         = "us-east-1"
environment        = "production"
project_name       = "log-service"
log_retention_days = 7
enable_pitr        = false  # Set to true for production
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 4: Review Deployment Plan

```bash
# Generate and review execution plan
terraform plan
```

Review the planned changes carefully. You should see:
- 1 DynamoDB table
- 2 Lambda functions
- 2 IAM roles
- 2 IAM policies
- 2 Lambda function URLs
- 2 CloudWatch log groups

### Step 5: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Review the plan again
# Type 'yes' when prompted to proceed
```

Deployment typically takes 2-3 minutes.

Expected output:
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

cloudwatch_log_group_ingest = "/aws/lambda/log-service-production-ingest"
cloudwatch_log_group_read_recent = "/aws/lambda/log-service-production-read-recent"
deployment_region = "us-east-1"
dynamodb_table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/log-service-production-logs"
dynamodb_table_name = "log-service-production-logs"
environment = "production"
ingest_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:log-service-production-ingest"
ingest_lambda_function_name = "log-service-production-ingest"
ingest_lambda_url = "https://xyz123abc.lambda-url.us-east-1.on.aws/"
read_recent_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:log-service-production-read-recent"
read_recent_lambda_function_name = "log-service-production-read-recent"
read_recent_lambda_url = "https://abc456def.lambda-url.us-east-1.on.aws/"
```

### Step 6: Save Outputs

```bash
# Export Lambda URLs for testing
export INGEST_URL=$(terraform output -raw ingest_lambda_url)
export READ_RECENT_URL=$(terraform output -raw read_recent_lambda_url)

# Display URLs
echo "Ingest URL: $INGEST_URL"
echo "Read Recent URL: $READ_RECENT_URL"

# Save outputs to file (optional)
terraform output > deployment-outputs.txt
```

## Post-Deployment Validation

### Validate Lambda Functions

```bash
# Check Ingest Lambda status
aws lambda get-function --function-name log-service-production-ingest

# Check ReadRecent Lambda status
aws lambda get-function --function-name log-service-production-read-recent
```

### Validate DynamoDB Table

```bash
# Describe table
aws dynamodb describe-table --table-name log-service-production-logs

# Check GSI
aws dynamodb describe-table --table-name log-service-production-logs \
  --query 'Table.GlobalSecondaryIndexes[0]'
```

### Run Functional Tests

```bash
# Make test scripts executable
chmod +x ../tests/test_ingest.sh
chmod +x ../tests/test_read_recent.sh

# Test Ingest Lambda
../tests/test_ingest.sh $INGEST_URL

# Test ReadRecent Lambda
../tests/test_read_recent.sh $READ_RECENT_URL
```

### Manual Smoke Test

```bash
# Create a log entry
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "info", "message": "Deployment successful!"}'

# Retrieve logs
curl $READ_RECENT_URL | jq '.'
```

## Troubleshooting

### Issue: Terraform Init Fails

**Symptom:** `Error: Failed to install provider`

**Solution:**
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Reinitialize
terraform init
```

### Issue: AWS Authentication Error

**Symptom:** `Error: No valid credential sources found`

**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

### Issue: Insufficient Permissions

**Symptom:** `Error: AccessDeniedException`

**Solution:**
- Verify IAM user has required permissions
- Check CloudTrail logs for specific denied actions
- Update IAM policy accordingly

### Issue: Lambda Function URL Returns 500

**Symptom:** Internal server error when calling function

**Solution:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/log-service-production-ingest --follow

# Invoke directly for detailed error
aws lambda invoke \
  --function-name log-service-production-ingest \
  --payload '{"severity":"info","message":"test"}' \
  response.json

cat response.json
```

### Issue: DynamoDB Query Returns No Results

**Symptom:** ReadRecent returns empty array

**Solution:**
```bash
# Verify table has data
aws dynamodb scan --table-name log-service-production-logs --limit 5

# Check GSI
aws dynamodb query \
  --table-name log-service-production-logs \
  --index-name TimestampIndex \
  --key-condition-expression "type = :type" \
  --expression-attribute-values '{":type":{"S":"LOG"}}' \
  --scan-index-forward false \
  --limit 5
```

### Issue: Terraform State Lock

**Symptom:** `Error acquiring the state lock`

**Solution:**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Updating the Deployment

### Update Lambda Code

```bash
# Modify Lambda function code
# Then run:
terraform apply
```

### Update Configuration

```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Review changes
terraform plan

# Apply updates
terraform apply
```

## Destroying the Infrastructure

**⚠️ WARNING: This will delete all resources and data permanently**

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' when prompted
```

## Production Deployment Recommendations

### 1. Use Remote State

Store Terraform state in S3 with state locking:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "log-service/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 2. Enable Point-in-Time Recovery

```hcl
# terraform.tfvars
enable_pitr = true
```

### 3. Use Multiple Environments

Create separate configurations for dev/staging/production:

```bash
# Workspace approach
terraform workspace new production
terraform workspace new staging

# Directory approach
infrastructure/
├── environments/
│   ├── production/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── development/
│       └── terraform.tfvars
```

### 4. Implement CI/CD

Example GitHub Actions workflow:

```yaml
# .github/workflows/deploy.yml
name: Deploy Log Service
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: hashicorp/setup-terraform@v1
      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: infrastructure
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### 5. Set Up Monitoring

```bash
# Create CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name log-service-high-errors \
  --alarm-description "Alert on high Lambda error rate" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=log-service-production-ingest
```

## Support and Maintenance

### Regular Maintenance Tasks

1. **Monitor CloudWatch Logs** (daily)
2. **Review DynamoDB metrics** (weekly)
3. **Update Lambda runtime** (as needed)
4. **Review IAM policies** (monthly)
5. **Test disaster recovery** (quarterly)

### Getting Help

- Review [README.md](../README.md) for usage instructions
- Check [ARCHITECTURE.md](../ARCHITECTURE.md) for design details
- Review AWS CloudWatch logs for errors
- Check Terraform documentation: https://www.terraform.io/docs

---

**Last Updated:** January 2026
