# Architecture Diagram

## High-Level Architecture

```
                                    ┌─────────────────────────────────┐
                                    │         AWS Cloud               │
                                    │                                 │
                                    │  ┌──────────────────────────┐  │
                    POST            │  │  Lambda Function URL     │  │
                  ┌────────────────►│  │  (Ingest)                │  │
                  │                 │  └──────────┬───────────────┘  │
                  │                 │             │                   │
           ┌──────┴────────┐        │             ▼                   │
           │               │        │  ┌──────────────────────────┐  │
           │   Client      │        │  │  Ingest Lambda Function  │  │
           │ Application   │        │  │  Runtime: Python 3.12    │  │
           │               │        │  │  Memory: 256 MB          │  │
           └──────┬────────┘        │  │  Timeout: 30s            │  │
                  │                 │  └──────────┬───────────────┘  │
                  │     GET         │             │                   │
                  └────────────────►│             │ PutItem           │
                                    │             ▼                   │
                                    │  ┌──────────────────────────┐  │
                                    │  │     DynamoDB Table       │  │
                                    │  │     Name: Logs           │  │
                                    │  │     Mode: On-Demand      │  │
                                    │  │                          │  │
                                    │  │  Primary Key:            │  │
                                    │  │  - PK: logId (String)    │  │
                                    │  │  - SK: timestamp (Number)│  │
                                    │  │                          │  │
                                    │  │  GSI: TimestampIndex     │  │
                                    │  │  - PK: type = "LOG"      │  │
                                    │  │  - SK: timestamp         │  │
                                    │  └──────────▲───────────────┘  │
                                    │             │                   │
                                    │             │ Query             │
                                    │             │ (GSI)             │
                                    │  ┌──────────┴───────────────┐  │
                                    │  │ ReadRecent Lambda        │  │
                                    │  │ Runtime: Python 3.12     │  │
                                    │  │ Memory: 256 MB           │  │
                                    │  │ Timeout: 30s             │  │
                                    │  └──────────▲───────────────┘  │
                                    │             │                   │
                                    │  ┌──────────┴───────────────┐  │
                                    │  │  Lambda Function URL     │  │
                                    │  │  (ReadRecent)            │  │
                                    │  └──────────────────────────┘  │
                                    │                                 │
                                    └─────────────────────────────────┘

                                    ┌─────────────────────────────────┐
                                    │    CloudWatch Logs              │
                                    │    - Lambda execution logs      │
                                    │    - Retention: 7 days          │
                                    └─────────────────────────────────┘
```

## Data Flow

### Ingest Flow
1. Client sends POST request to Ingest Lambda Function URL
2. Lambda validates request (severity, message)
3. Lambda generates UUID and timestamp
4. Lambda writes to DynamoDB table with:
   - logId (partition key)
   - timestamp (sort key)
   - type = "LOG" (for GSI)
   - severity, message, datetime
5. Lambda returns success response with logId and timestamp

### Retrieval Flow
1. Client sends GET request to ReadRecent Lambda Function URL
2. Lambda queries DynamoDB using TimestampIndex GSI
3. Query uses:
   - KeyCondition: type = "LOG"
   - ScanIndexForward = false (descending)
   - Limit = 100
4. Lambda converts Decimal types to JSON-compatible format
5. Lambda returns array of logs (newest first)

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        IAM Roles                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Ingest Lambda Role                ReadRecent Lambda Role  │
│  ├─ AssumeRole: lambda.amazonaws  ├─ AssumeRole: lambda    │
│  ├─ Policy:                        ├─ Policy:               │
│  │  └─ dynamodb:PutItem           │  └─ dynamodb:Query     │
│  │     Resource: Logs table        │     Resources:         │
│  └─ CloudWatch Logs: Write         │     - Logs table       │
│                                    │     - GSI indexes      │
│                                    └─ CloudWatch Logs: Write│
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Data Encryption                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  At Rest:                           In Transit:            │
│  └─ DynamoDB: AWS managed keys      └─ HTTPS (TLS 1.2+)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Infrastructure as Code Structure

```
infrastructure/
├── main.tf              # Core resource definitions
│   ├── DynamoDB Table
│   ├── IAM Roles & Policies
│   ├── Lambda Functions
│   └── Function URLs
├── variables.tf         # Input variables
├── outputs.tf          # Output values
└── terraform.tfvars    # Variable values (not in git)
```

## Scalability Design

**Horizontal Scaling:**
- Lambda: Auto-scales to 1000 concurrent executions
- DynamoDB: On-demand capacity auto-scales

**Vertical Scaling:**
- Lambda memory can be adjusted (current: 256 MB)
- DynamoDB: Can switch to provisioned capacity for predictable loads

**Query Optimization:**
- GSI enables O(1) access to recent logs
- Single query retrieves top 100 without scanning entire table
- Sort key allows efficient descending order retrieval
