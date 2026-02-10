#!/bin/bash

# Real input test for desk pet

echo "🧪 Testing REAL Input Handling for Bobo"
echo "==============================================="
echo
echo "This will test actual character-by-character input handling"
echo
echo "Expected behavior:"
echo "  - Type 'q' + ENTER → should quit cleanly"
echo "  - Type 'r' + ENTER → should start recording"
echo "  - Just ENTER → should be ignored"
echo "  - Should NOT show ^M characters"
echo
echo "Starting application (type 'q' + ENTER to quit):"
echo "================================================"
echo

# Run the actual application
cd "$(dirname "$0")"
./work/bin/desk-pet