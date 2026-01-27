"""
Ingest Lambda Function
Accepts log entries and stores them in DynamoDB.

Functionality:
- Validates incoming log entries
- Generates unique IDs and timestamps
- Stores logs in DynamoDB table with GSI for time-based queries
"""

import json
import os
import uuid
from datetime import datetime
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE_NAME')
table = dynamodb.Table(table_name)

# Valid severity levels
VALID_SEVERITIES = {'info', 'warning', 'error'}


def lambda_handler(event, context):
    """
    Lambda handler for ingesting log entries.
    
    Expected Input (JSON):
    {
        "severity": "info" | "warning" | "error",
        "message": "Log message text"
    }
    
    Returns:
    {
        "statusCode": 201,
        "message": "Log entry created successfully",
        "logId": "uuid",
        "timestamp": 1234567890
    }
    """
    
    try:
        # Parse request body
        body = parse_request_body(event)
        
        # Validate input
        validation_error = validate_log_entry(body)
        if validation_error:
            return create_response(400, {'error': validation_error})
        
        # Generate log entry
        log_entry = create_log_entry(body)
        
        # Store in DynamoDB
        store_log_entry(log_entry)
        
        # Return success response
        return create_response(201, {
            'message': 'Log entry created successfully',
            'logId': log_entry['logId'],
            'timestamp': int(log_entry['timestamp'])
        })
        
    except json.JSONDecodeError:
        return create_response(400, {'error': 'Invalid JSON in request body'})
    
    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return create_response(500, {'error': 'Failed to store log entry'})
    
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})


def parse_request_body(event):
    """
    Parse the request body from the Lambda event.
    Handles both direct invocation and Lambda Function URL formats.
    """
    if isinstance(event.get('body'), str):
        return json.loads(event['body'])
    elif isinstance(event.get('body'), dict):
        return event['body']
    elif 'severity' in event and 'message' in event:
        return event
    else:
        raise ValueError('Invalid request format')


def validate_log_entry(body):
    """
    Validate the log entry payload.
    Returns error message if invalid, None if valid.
    """
    # Check required fields
    if 'severity' not in body:
        return 'Missing required field: severity'
    
    if 'message' not in body:
        return 'Missing required field: message'
    
    # Validate severity
    severity = body['severity']
    if not isinstance(severity, str):
        return 'Severity must be a string'
    
    if severity.lower() not in VALID_SEVERITIES:
        return f'Invalid severity. Must be one of: {", ".join(VALID_SEVERITIES)}'
    
    # Validate message
    message = body['message']
    if not isinstance(message, str):
        return 'Message must be a string'
    
    if not message.strip():
        return 'Message cannot be empty'
    
    if len(message) > 10000:
        return 'Message exceeds maximum length of 10000 characters'
    
    return None


def create_log_entry(body):
    """
    Create a log entry with generated ID and timestamp.
    """
    # Generate unique ID
    log_id = str(uuid.uuid4())
    
    # Generate timestamp (milliseconds since epoch)
    now = datetime.utcnow()
    timestamp = int(now.timestamp() * 1000)
    
    # Create log entry
    log_entry = {
        'logId': log_id,
        'timestamp': Decimal(str(timestamp)),  # DynamoDB requires Decimal for numbers
        'datetime': now.isoformat() + 'Z',
        'severity': body['severity'].lower(),
        'message': body['message'].strip(),
        'type': 'LOG'  # Constant value for GSI partition key
    }
    
    return log_entry


def store_log_entry(log_entry):
    """
    Store the log entry in DynamoDB.
    """
    table.put_item(Item=log_entry)
    print(f"Successfully stored log entry: {log_entry['logId']}")


def create_response(status_code, body):
    """
    Create a standardized HTTP response.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps(body)
    }
