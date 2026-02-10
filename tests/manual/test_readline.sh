#!/bin/bash

echo "🔥 TESTING READLINE SOLUTION"
echo "============================"
echo
echo "This tests the NEW implementation with readline library"
echo
echo "Expected behavior NOW:"
echo "  ✅ ENTER should work immediately"
echo "  ✅ NO ^M^M^M^M characters"
echo "  ✅ Backspace should work for editing"
echo "  ✅ Ctrl+C should exit cleanly"
echo
echo "Try these commands:"
echo "  r + ENTER  → should start recording"
echo "  q + ENTER  → should quit with 'Goodbye!'"
echo
echo "Starting application with READLINE:"
echo "===================================="

cd "$(dirname "$0")"
./work/bin/desk-pet