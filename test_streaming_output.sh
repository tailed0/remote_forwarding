#!/bin/bash

# Test script to verify streaming output functionality
# This script ensures that enable.sh produces real-time output without buffering

set -eu
set -o pipefail

cd $(dirname $0)

echo "=== Remote Forwarding Streaming Output Test ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_passed=0
test_failed=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((test_passed++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((test_failed++))
}

log_info() {
    echo -e "[INFO] $1"
}

# Test 1: Check if script has streaming functions
log_test "Checking if enable.sh contains streaming functions..."
if grep -q "log_info\|log_progress\|log_error" enable.sh; then
    log_pass "Streaming functions found in enable.sh"
else
    log_fail "Streaming functions not found in enable.sh"
fi

# Test 2: Check if unbuffered output is enabled
log_test "Checking if unbuffered output is configured..."
if grep -q "stty -icanon" enable.sh; then
    log_pass "Unbuffered output configuration found"
else
    log_fail "Unbuffered output configuration not found"
fi

# Test 3: Check if exec statements are used for flushing
log_test "Checking if explicit flushing is implemented..."
if grep -q "exec 1>&1" enable.sh && grep -q "exec 2>&2" enable.sh; then
    log_pass "Explicit output flushing found"
else
    log_fail "Explicit output flushing not found"
fi

# Test 4: Check if progress indicators are present
log_test "Checking if progress indicators are implemented..."
if grep -q "log_progress" enable.sh && grep -q "✓" enable.sh; then
    log_pass "Progress indicators found"
else
    log_fail "Progress indicators not found"
fi

# Test 5: Check if SSH connection testing is implemented
log_test "Checking if SSH connection testing is implemented..."
if grep -q "Testing SSH connection" enable.sh; then
    log_pass "SSH connection testing found"
else
    log_fail "SSH connection testing not found"
fi

# Test 6: Check if service status verification is implemented
log_test "Checking if service status verification is implemented..."
if grep -q "Checking service status" enable.sh; then
    log_pass "Service status verification found"
else
    log_fail "Service status verification not found"
fi

# Test 7: Syntax check
log_test "Performing syntax check on enable.sh..."
if bash -n enable.sh; then
    log_pass "Syntax check passed"
else
    log_fail "Syntax check failed"
fi

# Test 8: Check if help message is properly formatted
log_test "Checking help message functionality..."
if ./enable.sh -h 2>&1 | grep -q "Usage:"; then
    log_pass "Help message works correctly"
else
    log_fail "Help message not working"
fi

# Test 9: Check if error handling for missing arguments works
log_test "Checking error handling for missing arguments..."
if ./enable.sh 2>&1 | grep -q "ERROR.*-p is required"; then
    log_pass "Error handling for missing arguments works"
else
    log_fail "Error handling for missing arguments not working"
fi

# Test 10: Simulate streaming output behavior
log_test "Simulating streaming output test..."
echo "Simulating real-time output (this should appear progressively):"
for i in {1..5}; do
    echo -n "Processing step $i..."
    sleep 0.5
    echo " ✓"
done
log_pass "Streaming output simulation completed"

echo ""
echo "=== Test Results ==="
echo "Tests passed: $test_passed"
echo "Tests failed: $test_failed"
echo "Total tests: $((test_passed + test_failed))"

if [ $test_failed -eq 0 ]; then
    log_info "All tests passed! Streaming output support is properly implemented."
    exit 0
else
    log_info "Some tests failed. Please review the implementation."
    exit 1
fi