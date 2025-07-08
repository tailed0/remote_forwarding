#!/bin/bash

# Test script for verifying streaming output functionality
# This script demonstrates real-time output streaming for the cc-web interface

# Color codes for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Ensure unbuffered output
export PYTHONUNBUFFERED=1
stty -F /dev/stdout 2>/dev/null || true

echo -e "${GREEN}=== Streaming Output Test ===${NC}"
echo "This script tests if output streams correctly in real-time"
echo

# Test 1: Character-by-character output
echo -e "${BLUE}Test 1: Character streaming${NC}"
echo -n "Progress: "
for i in {1..20}; do
    echo -n "#"
    sleep 0.1
done
echo " Complete!"
echo

# Test 2: Line-by-line output with timestamps
echo -e "${BLUE}Test 2: Line streaming with timestamps${NC}"
for i in {1..5}; do
    echo "[$(date '+%H:%M:%S')] Processing item $i..."
    sleep 0.5
done
echo

# Test 3: Mixed stdout and stderr
echo -e "${BLUE}Test 3: Mixed stdout/stderr streaming${NC}"
for i in {1..3}; do
    echo "[$i] Normal output (stdout)"
    echo -e "${YELLOW}[$i] Warning output (stderr)${NC}" >&2
    sleep 0.5
done
echo

# Test 4: Spinner animation
echo -e "${BLUE}Test 4: Spinner animation${NC}"
spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
echo -n "Loading "
for i in {1..20}; do
    echo -ne "\b${spinner[$((i % 10))]}"
    sleep 0.1
done
echo -e "\b${GREEN}✓${NC} Done!"
echo

# Test 5: Progress percentage
echo -e "${BLUE}Test 5: Progress percentage${NC}"
for i in {0..100..10}; do
    printf "\rProgress: %3d%%" $i
    sleep 0.2
done
echo -e "\rProgress: 100% ${GREEN}✓${NC}"
echo

echo -e "${GREEN}=== All tests completed ===${NC}"
echo "If you see all output appearing in real-time, streaming is working correctly!"
echo
echo "Note: stderr output may appear buffered at the end in some environments."
echo "This is a known behavior and does not affect the core functionality."