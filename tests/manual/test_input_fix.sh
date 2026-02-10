#!/bin/bash

# Test script for input handling fix

echo "🧪 Testing Input Fix for Bobo"
echo "======================================"
echo

echo "Test 1: Auto-quit test (sends 'q' automatically)"
echo "Expected: Should quit cleanly without ^M characters"
echo

# Send 'q' command automatically and timeout after 10 seconds
cd "$(dirname "$0")"
echo "q" | timeout 10 ./work/bin/desk-pet 2>&1 | head -20

echo
echo "✅ Input fix test completed"
echo
echo "If you saw the startup messages and 'Goodbye!' without ^M characters,"
echo "then the input handling is fixed!"
echo
echo "Manual test: Run 'make run' and try pressing:"
echo "- 'r' + ENTER"
echo "- 'q' + ENTER"
echo "- Just ENTER (should be ignored)"