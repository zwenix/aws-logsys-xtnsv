#!/bin/bash

# Test script for ReadRecent Lambda Function
# Usage: ./test_read_recent.sh <LAMBDA_URL>

set -e

if [ -z "$1" ]; then
    echo "Error: Lambda URL required"
    echo "Usage: ./test_read_recent.sh <LAMBDA_URL>"
    exit 1
fi

LAMBDA_URL="$1"

echo "========================================"
echo "Testing ReadRecent Lambda Function"
echo "========================================"
echo "URL: $LAMBDA_URL"
echo ""

# Test 1: Retrieve recent logs
echo "Test 1: Retrieving recent log entries..."
RESPONSE=$(curl -s "$LAMBDA_URL")

echo "Response:"
echo "$RESPONSE" | jq '.'
echo ""

# Check status code
STATUS_CODE=$(echo "$RESPONSE" | jq -r '.statusCode // 200')
if [ "$STATUS_CODE" = "200" ]; then
    echo "✓ Test 1 PASSED - Successfully retrieved logs"
else
    echo "✗ Test 1 FAILED - Expected status 200, got $STATUS_CODE"
fi
echo ""

# Test 2: Verify response structure
echo "Test 2: Verifying response structure..."
HAS_COUNT=$(echo "$RESPONSE" | jq 'has("count")')
HAS_LOGS=$(echo "$RESPONSE" | jq 'has("logs")')

if [ "$HAS_COUNT" = "true" ] && [ "$HAS_LOGS" = "true" ]; then
    echo "✓ Test 2 PASSED - Response has correct structure"
else
    echo "✗ Test 2 FAILED - Response missing 'count' or 'logs' field"
fi
echo ""

# Test 3: Count logs
echo "Test 3: Checking log count..."
LOG_COUNT=$(echo "$RESPONSE" | jq -r '.count // 0')
echo "Found $LOG_COUNT log entries"

if [ "$LOG_COUNT" -ge 0 ]; then
    echo "✓ Test 3 PASSED - Valid log count"
else
    echo "✗ Test 3 FAILED - Invalid log count"
fi
echo ""

# Test 4: Verify log entry structure
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "Test 4: Verifying log entry structure..."
    FIRST_LOG=$(echo "$RESPONSE" | jq '.logs[0]')
    
    HAS_LOG_ID=$(echo "$FIRST_LOG" | jq 'has("logId")')
    HAS_TIMESTAMP=$(echo "$FIRST_LOG" | jq 'has("timestamp")')
    HAS_DATETIME=$(echo "$FIRST_LOG" | jq 'has("datetime")')
    HAS_SEVERITY=$(echo "$FIRST_LOG" | jq 'has("severity")')
    HAS_MESSAGE=$(echo "$FIRST_LOG" | jq 'has("message")')
    
    if [ "$HAS_LOG_ID" = "true" ] && [ "$HAS_TIMESTAMP" = "true" ] && \
       [ "$HAS_DATETIME" = "true" ] && [ "$HAS_SEVERITY" = "true" ] && \
       [ "$HAS_MESSAGE" = "true" ]; then
        echo "✓ Test 4 PASSED - Log entries have correct structure"
    else
        echo "✗ Test 4 FAILED - Log entries missing required fields"
    fi
    echo ""
    
    # Test 5: Verify chronological order (newest first)
    echo "Test 5: Verifying chronological order (newest first)..."
    if [ "$LOG_COUNT" -ge 2 ]; then
        FIRST_TIMESTAMP=$(echo "$RESPONSE" | jq '.logs[0].timestamp')
        SECOND_TIMESTAMP=$(echo "$RESPONSE" | jq '.logs[1].timestamp')
        
        if [ "$FIRST_TIMESTAMP" -ge "$SECOND_TIMESTAMP" ]; then
            echo "✓ Test 5 PASSED - Logs are in descending order"
        else
            echo "✗ Test 5 FAILED - Logs are not in descending order"
        fi
        echo ""
    else
        echo "⊘ Test 5 SKIPPED - Need at least 2 logs to verify order"
        echo ""
    fi
    
    # Test 6: Display sample logs
    echo "Test 6: Sample log entries:"
    echo "$RESPONSE" | jq '.logs[0:3]'
    echo ""
    
    # Test 7: Verify severity values
    echo "Test 7: Verifying severity values..."
    INVALID_SEVERITY=$(echo "$RESPONSE" | jq -r '.logs[].severity' | grep -v -E '^(info|warning|error)$' | wc -l)
    
    if [ "$INVALID_SEVERITY" -eq 0 ]; then
        echo "✓ Test 7 PASSED - All severity values are valid"
    else
        echo "✗ Test 7 FAILED - Found $INVALID_SEVERITY invalid severity values"
    fi
    echo ""
    
else
    echo "⊘ Tests 4-7 SKIPPED - No logs in database"
    echo "  Run the ingest test first to create some logs"
    echo ""
fi

# Test 8: Verify maximum limit
echo "Test 8: Verifying maximum log limit..."
if [ "$LOG_COUNT" -le 100 ]; then
    echo "✓ Test 8 PASSED - Log count ($LOG_COUNT) is within limit (100)"
else
    echo "✗ Test 8 FAILED - Log count ($LOG_COUNT) exceeds limit (100)"
fi
echo ""

echo "========================================"
echo "All tests completed!"
echo "========================================"
