# Log Service Platform - AWS Serverless Solution by Zwelakhe Msuthu | 28/01/2026

A production-ready, serverless log ingestion and retrieval system built on AWS infrastructure.

## Architecture Overview

This solution implements a scalable, serverless log management system using AWS managed services:

```
┌─────────────────┐
│  Lambda Function│
│   URL (Ingest)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐       ┌──────────────────┐
│ Ingest Lambda   │──────▶│   DynamoDB       │
│  (Python 3.12)  │       │   Table: Logs    │
└─────────────────┘       └────────┬─────────┘
                                   │
┌─────────────────┐                │
│  Lambda Function│                │
│ URL (ReadRecent)│                │
└────────┬────────┘                │
         │                         │
         ▼                         │
┌─────────────────┐                │
│ ReadRecent      │◀───────────────┘
│   Lambda        │
│  (Python 3.12)  │
└─────────────────┘
```

## Rationale Behind Choice of Technology

### Database Selection: Amazon DynamoDB

**Selected Technology:** Amazon DynamoDB

**Rationale:**
- **Serverless & Auto-scaling:** No server management, automatic scaling to handle varying loads
- **Performance:** Single-digit millisecond latency at any scale
- **Cost-effective:** Pay-per-request pricing ideal for variable workloads
- **Built-in sorting:** GSI (Global Secondary Index) enables efficient time-based queries
- **High availability:** Multi-AZ replication by default (99.99% SLA)
- **Low operational overhead:** No patching, backups managed automatically

**Trade-offs vs. Alternatives:**

| Database | Pros | Cons | Why Not Selected |
|----------|------|------|------------------|
| **DynamoDB** | ✅ Serverless, auto-scaling<br>✅ Low latency<br>✅ Pay-per-request | ⚠️ NoSQL learning curve<br>⚠️ Query limitations | **SELECTED** |
| **Aurora Serverless** | ✅ SQL compatibility<br>✅ Complex queries | ❌ Cold start delays<br>❌ Higher cost<br>❌ More complex setup | Overkill for simple schema |
| **RDS** | ✅ Full SQL features<br>✅ Familiar | ❌ Requires provisioning<br>❌ Manual scaling<br>❌ Higher baseline cost | Not serverless, manual management |

### Database Schema Design

**Primary Table: `Logs`**

```
Partition Key: logId (String, UUID)
Sort Key: timestamp (Number, Unix timestamp in milliseconds)

Attributes:
- logId: String (UUID v4)
- timestamp: Number (Unix timestamp in ms)
- datetime: String (ISO 8601 formatted)
- severity: String (info|warning|error)
- message: String

Global Secondary Index (GSI): TimestampIndex
- Partition Key: type (String, constant "LOG")
- Sort Key: timestamp (Number)
- Projection: ALL
```

**Design Rationale:**
1. **Partition Key (logId):** Ensures unique identification and even data distribution
2. **Sort Key (timestamp):** Enables time-based queries within a partition
3. **GSI (TimestampIndex):** Allows efficient querying of most recent logs across all partitions
   - Single partition key ("LOG") groups all logs for time-based queries
   - Sort key (timestamp) enables descending order retrieval
   - Supports "query last 100" efficiently with ScanIndexForward=false
4. **Data Integrity:** UUID prevents collisions, timestamp ensures chronological ordering
5. **Query Efficiency:** GSI optimized for "most recent N" pattern with O(1) access

## Project Structure

```
log-service-platform/
├── README.md                          # This file
├── infrastructure/
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   └── terraform.tfvars.example       # Example variables file
├── lambdas/
│   ├── ingest/
│   │   ├── lambda_function.py         # Ingest Lambda handler
│   │   └── requirements.txt           # Python dependencies
│   └── read_recent/
│       ├── lambda_function.py         # ReadRecent Lambda handler
│       └── requirements.txt           # Python dependencies
├── tests/
│   ├── test_ingest.sh                 # Ingest Lambda test script
│   └── test_read_recent.sh            # ReadRecent Lambda test script
└── .gitignore
```

## Prerequisites

- **AWS Account** with appropriate permissions (IAM, Lambda, DynamoDB, CloudWatch)
- **Terraform** >= 1.6.0 ([Install Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** configured with credentials ([Install Guide](https://aws.amazon.com/cli/))
- **Git** for version control
- **curl** or **Postman** for testing

## Setup and Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/zwenix/aws-logsys.git
cd aws-logsys
```

### 2. Configure AWS Credentials

```bash
# Option 1: Using AWS CLI
aws configure

# Option 2: Using environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Configure Terraform Variables

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your preferences
vi terraform.tfvars
```

**Example `terraform.tfvars`:**
```hcl
aws_region = "us-east-1"
environment = "production"
project_name = "log-service"
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply

# Type 'yes' when prompted
```

**Expected Output:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

dynamodb_table_name = "log-service-production-logs"
ingest_lambda_url = "https://xyz123abc.lambda-url.us-east-1.on.aws/"
read_recent_lambda_url = "https://abc456def.lambda-url.us-east-1.on.aws/"
```

### 5. Save the Lambda URLs

```bash
# Export for easy testing
export INGEST_URL=$(terraform output -raw ingest_lambda_url)
export READ_RECENT_URL=$(terraform output -raw read_recent_lambda_url)

echo "Ingest URL: $INGEST_URL"
echo "Read Recent URL: $READ_RECENT_URL"
```

## Usage Guide

### Ingesting Log Entries

**Endpoint:** `POST` to Ingest Lambda URL

**Request Body:**
```json
{
  "severity": "info",
  "message": "User authentication successful"
}
```

**Example using curl:**
```bash
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{
    "severity": "error",
    "message": "Database connection timeout"
  }'
```

**Response (Success):**
```json
{
  "statusCode": 201,
  "message": "Log entry created successfully",
  "logId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "timestamp": 1706356800000
}
```

**Validation Rules:**
- `severity`: Must be one of: `info`, `warning`, `error`
- `message`: Required, non-empty string

### Retrieving Recent Logs

**Endpoint:** `GET` to ReadRecent Lambda URL

**Example using curl:**
```bash
curl $READ_RECENT_URL
```

**Response (Success):**
```json
{
  "statusCode": 200,
  "count": 3,
  "logs": [
    {
      "logId": "uuid-1",
      "timestamp": 1706356900000,
      "datetime": "2024-01-27T12:15:00.000Z",
      "severity": "error",
      "message": "Database connection timeout"
    },
    {
      "logId": "uuid-2",
      "timestamp": 1706356800000,
      "datetime": "2024-01-27T12:13:20.000Z",
      "severity": "warning",
      "message": "High memory usage detected"
    },
    {
      "logId": "uuid-3",
      "timestamp": 1706356700000,
      "datetime": "2024-01-27T12:11:40.000Z",
      "severity": "info",
      "message": "User authentication successful"
    }
  ]
}
```

## Testing

### Automated Test Scripts

```bash
# Test Ingest Lambda
cd tests
./test_ingest.sh $INGEST_URL

# Test ReadRecent Lambda
./test_read_recent.sh $READ_RECENT_URL
```

### Manual Testing

**1. Ingest Multiple Log Entries:**
```bash
# Info log
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "info", "message": "Application started successfully"}'

# Warning log
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "warning", "message": "API rate limit approaching"}'

# Error log
curl -X POST $INGEST_URL \
  -H "Content-Type: application/json" \
  -d '{"severity": "error", "message": "Failed to process payment"}'
```

**2. Retrieve Recent Logs:**
```bash
curl $READ_RECENT_URL | jq '.'
```

## Monitoring and Observability

### CloudWatch Logs

```bash
# View Ingest Lambda logs
aws logs tail /aws/lambda/log-service-production-ingest --follow

# View ReadRecent Lambda logs
aws logs tail /aws/lambda/log-service-production-read-recent --follow
```

### CloudWatch Metrics

Available metrics:
- Lambda invocations
- Error rates
- Duration
- DynamoDB consumed read/write capacity
- Throttle events

**View in AWS Console:**
```
CloudWatch → Metrics → Lambda → By Function Name
```

## Maintenance and Operations

### Viewing Infrastructure State

```bash
cd infrastructure
terraform show
```

### Updating the Infrastructure

```bash
# Modify Terraform files as needed
terraform plan
terraform apply
```

### Destroying the Infrastructure

**⚠️ Warning: This will delete all resources and data**

```bash
cd infrastructure
terraform destroy
# Type 'yes' when prompted
```

## Security Considerations

### Implemented Security Measures

1. **IAM Least Privilege:** Lambda execution roles have minimal required permissions
2. **Encryption at Rest:** DynamoDB uses AWS-managed encryption
3. **Encryption in Transit:** All API calls use HTTPS
4. **Function URLs:** Consider adding authentication for production use
5. **CloudWatch Logging:** All Lambda invocations are logged for audit

### Production Recommendations

For production environments, consider adding:

1. **Authentication:** Implement AWS IAM authentication or Lambda authorizers
2. **Rate Limiting:** Add API Gateway with throttling
3. **VPC:** Deploy Lambdas in VPC for enhanced security
4. **WAF:** Add AWS WAF for protection against common exploits
5. **Secrets Management:** Use AWS Secrets Manager for sensitive data
6. **Backup:** Enable DynamoDB Point-in-Time Recovery (PITR)

## Scaling Considerations

### Current Capacity

- **DynamoDB:** Pay-per-request mode, auto-scales automatically
- **Lambda:** 1000 concurrent executions (soft limit, can be increased)
- **GSI:** Inherits table's capacity mode

### Scaling to Production

For high-volume production workloads:

1. **DynamoDB Provisioned Capacity:** Consider switching for predictable workloads
2. **Lambda Reserved Concurrency:** Allocate dedicated capacity
3. **CloudWatch Alarms:** Set up alerts for throttling, errors
4. **Time-based Partitioning:** Implement date-based partitions for very large datasets
5. **Caching:** Add ElastiCache for frequently accessed recent logs

## Cost Estimation

**Monthly costs for moderate usage (estimate):**

| Service | Usage | Estimated Cost |
|---------|-------|----------------|
| Lambda | 1M requests/month | $0.20 |
| DynamoDB | 1M writes, 10M reads | $1.50 |
| CloudWatch Logs | 10GB stored | $5.00 |
| **Total** | | **~$6.70/month** |

*Costs scale with usage. AWS Free Tier may cover development/testing.*

## Troubleshooting

### Common Issues

**Issue:** `terraform init` fails
```bash
# Solution: Check AWS credentials
aws sts get-caller-identity
```

**Issue:** Lambda returns 500 error
```bash
# Solution: Check CloudWatch logs
aws logs tail /aws/lambda/log-service-production-ingest --follow
```

**Issue:** No logs returned from ReadRecent
```bash
# Solution: Verify DynamoDB has data
aws dynamodb scan --table-name log-service-production-logs --limit 5
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created for Games Global Platform Engineer Application

## Support

For issues or questions:
- Open an issue in the GitHub repository
- Review CloudWatch logs for Lambda execution details
- Check AWS Service Health Dashboard for service status

---

**Last Updated:** January 2026
