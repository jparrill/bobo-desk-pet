#!/bin/bash

# Automated input test for desk pet

echo "🧪 Automated Input Test for Bobo"
echo "========================================"
echo

cd "$(dirname "$0")"

# Test 1: Send 'q' command to quit
echo "Test 1: Sending 'q' command automatically..."
echo
(
    sleep 2  # Wait for app to start
    echo "q"  # Send quit command
) | timeout 10 ./work/bin/desk-pet > test_output.log 2>&1

# Check results
echo "Results:"
echo "--------"

if grep -q "👋 Goodbye\|Shutting down" test_output.log; then
    echo "✅ SUCCESS: Application received 'q' command and quit properly"
else
    echo "❌ FAILED: Application did not quit properly with 'q' command"
fi

# Check for ^M characters
if grep -q "\^M" test_output.log; then
    echo "❌ FAILED: ^M characters still present in output"
else
    echo "✅ SUCCESS: No ^M characters found in output"
fi

# Check for TTS warning (expected)
if grep -q "Failed to initialize TTS" test_output.log; then
    echo "✅ EXPECTED: TTS initialization warning (normal behavior)"
else
    echo "⚠️  Note: TTS warning not found (might be OK if TTS is installed)"
fi

echo
echo "Full output (last 10 lines):"
echo "-----------------------------"
tail -10 test_output.log

# Cleanup
rm -f test_output.log

echo
echo "✅ Automated input test completed"