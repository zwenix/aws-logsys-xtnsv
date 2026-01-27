"""
ReadRecent Lambda Function
Retrieves the 100 most recent log entries from DynamoDB.

Functionality:
- Queries DynamoDB using GSI for efficient time-based retrieval
- Returns logs in descending order (newest first)
- Handles pagination and error cases
"""

import json
import os
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE_NAME')
table = dynamodb.Table(table_name)

# Constants
MAX_LOGS_TO_RETURN = 100
GSI_NAME = 'TimestampIndex'


def lambda_handler(event, context):
    """
    Lambda handler for retrieving recent log entries.
    
    Returns:
    {
        "statusCode": 200,
        "count": 50,
        "logs": [
            {
                "logId": "uuid",
                "timestamp": 1234567890,
                "datetime": "2024-01-27T12:00:00.000Z",
                "severity": "info",
                "message": "Log message"
            },
            ...
        ]
    }
    """
    
    try:
        # Query DynamoDB for recent logs
        logs = query_recent_logs()
        
        # Convert to serializable format
        serializable_logs = convert_logs_to_json(logs)
        
        # Return success response
        return create_response(200, {
            'count': len(serializable_logs),
            'logs': serializable_logs
        })
        
    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        error_code = e.response['Error']['Code']
        
        if error_code == 'ResourceNotFoundException':
            return create_response(500, {
                'error': 'Database table not found',
                'details': 'The log storage table does not exist'
            })
        else:
            return create_response(500, {
                'error': 'Failed to retrieve log entries',
                'details': str(e)
            })
    
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error',
            'details': str(e)
        })


def query_recent_logs():
    """
    Query DynamoDB GSI for the most recent logs.
    Uses TimestampIndex GSI with descending sort order.
    
    Returns list of log items (newest first).
    """
    try:
        # Query using GSI for efficient time-based retrieval
        response = table.query(
            IndexName=GSI_NAME,
            KeyConditionExpression='#type = :type_value',
            ExpressionAttributeNames={
                '#type': 'type'
            },
            ExpressionAttributeValues={
                ':type_value': 'LOG'
            },
            ScanIndexForward=False,  # Sort descending (newest first)
            Limit=MAX_LOGS_TO_RETURN
        )
        
        logs = response.get('Items', [])
        print(f"Successfully retrieved {len(logs)} log entries")
        
        return logs
        
    except Exception as e:
        print(f"Error querying logs: {str(e)}")
        raise


def convert_logs_to_json(logs):
    """
    Convert DynamoDB items to JSON-serializable format.
    Handles Decimal conversion and field formatting.
    """
    serializable_logs = []
    
    for log in logs:
        serializable_log = {
            'logId': log['logId'],
            'timestamp': int(log['timestamp']),  # Convert Decimal to int
            'datetime': log['datetime'],
            'severity': log['severity'],
            'message': log['message']
        }
        serializable_logs.append(serializable_log)
    
    return serializable_logs


def create_response(status_code, body):
    """
    Create a standardized HTTP response.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps(body, default=decimal_default)
    }


def decimal_default(obj):
    """
    JSON serializer for objects not serializable by default json code.
    Handles Decimal types from DynamoDB.
    """
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
