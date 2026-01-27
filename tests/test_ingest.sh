#!/bin/bash

# Test script for Ingest Lambda Function
# Usage: ./test_ingest.sh <LAMBDA_URL>

set -e

if [ -z "$1" ]; then
    echo "Error: Lambda URL required"
    echo "Usage: ./test_ingest.sh <LAMBDA_URL>"
    exit 1
fi

LAMBDA_URL="$1"

echo "========================================"
echo "Testing Ingest Lambda Function"
echo "========================================"
echo "URL: $LAMBDA_URL"
echo ""

# Test 1: Valid INFO log
echo "Test 1: Creating INFO log entry..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "info", "message": "Test info log - Application started successfully"}')

echo "Response: $RESPONSE"
echo ""

# Extract status code
STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "201" ]; then
    echo "✓ Test 1 PASSED - INFO log created"
else
    echo "✗ Test 1 FAILED - Expected status 201, got $STATUS_CODE"
fi
echo ""

# Test 2: Valid WARNING log
echo "Test 2: Creating WARNING log entry..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "warning", "message": "Test warning log - High memory usage detected"}')

echo "Response: $RESPONSE"
echo ""

STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "201" ]; then
    echo "✓ Test 2 PASSED - WARNING log created"
else
    echo "✗ Test 2 FAILED - Expected status 201, got $STATUS_CODE"
fi
echo ""

# Test 3: Valid ERROR log
echo "Test 3: Creating ERROR log entry..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "error", "message": "Test error log - Database connection failed"}')

echo "Response: $RESPONSE"
echo ""

STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "201" ]; then
    echo "✓ Test 3 PASSED - ERROR log created"
else
    echo "✗ Test 3 FAILED - Expected status 201, got $STATUS_CODE"
fi
echo ""

# Test 4: Invalid severity
echo "Test 4: Testing invalid severity (should fail)..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "critical", "message": "Test invalid severity"}')

echo "Response: $RESPONSE"
echo ""

STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "400" ]; then
    echo "✓ Test 4 PASSED - Invalid severity rejected"
else
    echo "✗ Test 4 FAILED - Expected status 400, got $STATUS_CODE"
fi
echo ""

# Test 5: Missing message field
echo "Test 5: Testing missing message field (should fail)..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "info"}')

echo "Response: $RESPONSE"
echo ""

STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "400" ]; then
    echo "✓ Test 5 PASSED - Missing message rejected"
else
    echo "✗ Test 5 FAILED - Expected status 400, got $STATUS_CODE"
fi
echo ""

# Test 6: Empty message
echo "Test 6: Testing empty message (should fail)..."
RESPONSE=$(curl -s -X POST "$LAMBDA_URL" \
    -H "Content-Type: application/json" \
    -d '{"severity": "info", "message": "   "}')

echo "Response: $RESPONSE"
echo ""

STATUS_CODE=$(echo "$RESPONSE" | grep -o '"statusCode":[0-9]*' | cut -d':' -f2)
if [ "$STATUS_CODE" = "400" ]; then
    echo "✓ Test 6 PASSED - Empty message rejected"
else
    echo "✗ Test 6 FAILED - Expected status 400, got $STATUS_CODE"
fi
echo ""

# Test 7: Bulk create multiple logs
echo "Test 7: Creating 10 log entries for volume test..."
for i in {1..10}; do
    SEVERITY=("info" "warning" "error")
    RANDOM_SEVERITY=${SEVERITY[$RANDOM % 3]}
    
    curl -s -X POST "$LAMBDA_URL" \
        -H "Content-Type: application/json" \
        -d "{\"severity\": \"$RANDOM_SEVERITY\", \"message\": \"Bulk test log entry $i\"}" > /dev/null
    
    echo -n "."
done
echo ""
echo "✓ Test 7 COMPLETED - Bulk creation test"
echo ""

echo "========================================"
echo "All tests completed!"
echo "========================================"
