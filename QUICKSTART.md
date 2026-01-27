# Quick Start Guide

Get the Log Service Platform up and running in under 10 minutes.

## Prerequisites Check

Verify you have the required tools:

```bash
# Check Terraform
terraform --version  # Should be >= 1.6.0

# Check AWS CLI
aws --version  # Should be >= 2.0

# Check AWS credentials
aws sts get-caller-identity  # Should return your account info
```

## 5-Minute Setup

### 1. Clone Repository (30 seconds)

```bash
git clone https://github.com/yourusername/log-service-platform.git
cd log-service-platform
```

### 2. Configure Terraform (1 minute)

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars

# Edit if you want to change defaults (optional)
# Default values work fine for testing:
# - Region: us-east-1
# - Environment: production
# - Project name: log-service
```

### 3. Deploy (3 minutes)

```bash
# Initialize and deploy
terraform init
terraform apply -auto-approve

# Save the URLs
export INGEST_URL=$(terraform output -raw ingest_lambda_url)
export READ_RECENT_URL=$(terraform output -raw read_recent_lambda_url)
```

### 4. Test (1 minute)

```bash
# Create a log entry
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "info", "message": "Hello from Log Service!"}'

# Retrieve logs
curl $READ_RECENT_URL
```

**Expected Output:**
```json
{
  "statusCode": 200,
  "count": 1,
  "logs": [
    {
      "logId": "550e8400-e29b-41d4-a716-446655440000",
      "timestamp": 1706356800000,
      "datetime": "2024-01-27T12:00:00.000Z",
      "severity": "info",
      "message": "Hello from Log Service!"
    }
  ]
}
```

## Common Use Cases

### Ingest Logs

**Info Log:**
```bash
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "info", "message": "User logged in successfully"}'
```

**Warning Log:**
```bash
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "warning", "message": "API rate limit approaching"}'
```

**Error Log:**
```bash
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "error", "message": "Payment processing failed"}'
```

### Retrieve Logs

**Get all recent logs:**
```bash
curl $READ_RECENT_URL | jq '.'
```

**Get only log count:**
```bash
curl -s $READ_RECENT_URL | jq '.count'
```

**Get latest log:**
```bash
curl -s $READ_RECENT_URL | jq '.logs[0]'
```

## Integration Examples

### Python

```python
import requests
import json

# Ingest a log
def log_message(severity, message):
    response = requests.post(
        "YOUR_INGEST_URL",
        json={"severity": severity, "message": message}
    )
    return response.json()

# Get recent logs
def get_recent_logs():
    response = requests.get("YOUR_READ_RECENT_URL")
    return response.json()

# Usage
log_message("error", "Database connection failed")
logs = get_recent_logs()
print(f"Found {logs['count']} logs")
```

### JavaScript/Node.js

```javascript
// Ingest a log
async function logMessage(severity, message) {
  const response = await fetch('YOUR_INGEST_URL', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ severity, message })
  });
  return response.json();
}

// Get recent logs
async function getRecentLogs() {
  const response = await fetch('YOUR_READ_RECENT_URL');
  return response.json();
}

// Usage
await logMessage('error', 'API request failed');
const logs = await getRecentLogs();
console.log(`Found ${logs.count} logs`);
```

### Bash Script

```bash
#!/bin/bash

INGEST_URL="your-ingest-url"
READ_RECENT_URL="your-read-recent-url"

# Function to log messages
log_message() {
    local severity=$1
    local message=$2
    curl -X POST "$INGEST_URL" \
        -H "Content-Type: application/json" \
        -d "{\"severity\": \"$severity\", \"message\": \"$message\"}" \
        -s
}

# Function to get logs
get_logs() {
    curl -s "$READ_RECENT_URL" | jq '.'
}

# Usage
log_message "info" "Script started"
log_message "error" "Something went wrong"
get_logs
```

## Running Tests

```bash
# Make scripts executable (if not already)
chmod +x tests/*.sh

# Test ingestion
./tests/test_ingest.sh $INGEST_URL

# Test retrieval
./tests/test_read_recent.sh $READ_RECENT_URL
```

## Viewing Logs in AWS Console

**CloudWatch Logs:**
1. Go to AWS Console → CloudWatch → Log groups
2. Find `/aws/lambda/log-service-production-ingest`
3. View Lambda execution logs

**DynamoDB:**
1. Go to AWS Console → DynamoDB → Tables
2. Select `log-service-production-logs`
3. Click "Explore table items"

## Clean Up

When you're done testing:

```bash
cd infrastructure
terraform destroy -auto-approve
```

This removes all resources and stops any charges.

## Next Steps

- **Production Setup:** See [DEPLOYMENT.md](DEPLOYMENT.md) for production best practices
- **Architecture:** Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the design
- **Full Documentation:** Check [README.md](README.md) for complete details

## Troubleshooting

**Issue:** `terraform: command not found`
```bash
# Install Terraform: https://developer.hashicorp.com/terraform/downloads
```

**Issue:** `aws: command not found`
```bash
# Install AWS CLI: https://aws.amazon.com/cli/
```

**Issue:** Lambda returns 500 error
```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/log-service-production-ingest --follow
```

**Issue:** No logs returned
```bash
# Verify you've created some logs first
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "info", "message": "Test"}'

# Then try retrieving
curl $READ_RECENT_URL
```

## Cost Estimate

For testing/development with moderate usage:
- **Lambda:** ~$0.20/month (1M requests)
- **DynamoDB:** ~$1.50/month (1M writes, 10M reads)
- **CloudWatch Logs:** ~$5.00/month (10GB)
- **Total:** ~$7/month

AWS Free Tier may cover most development usage.

## Support

- 📖 [Full Documentation](README.md)
- 🏗️ [Architecture Guide](ARCHITECTURE.md)
- 🚀 [Deployment Guide](DEPLOYMENT.md)
- 🤝 [Contributing Guide](CONTRIBUTING.md)

---

Ready to deploy? Run the commands above and you'll be logging in minutes!
