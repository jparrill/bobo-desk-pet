#!/bin/bash

echo "🎤 TESTING AUDIO RECORDING FIX"
echo "=============================="
echo
echo "This tests the FIXED audio path implementation"
echo
echo "Expected behavior:"
echo "  ✅ Input works (readline)"
echo "  ✅ Recording creates file with absolute path"
echo "  ✅ whisper.cpp finds the file"
echo "  ✅ Transcription processes (even if placeholder audio)"
echo
echo "Try command 'r' to test audio recording:"
echo

cd "$(dirname "$0")"

echo "Checking current directory and paths..."
echo "PWD: $(pwd)"
echo "work/temp exists: $([ -d work/temp ] && echo 'YES' || echo 'NO')"
echo "whisper-cli path: $(ls work/repos/whisper.cpp/build/bin/whisper-cli 2>/dev/null || echo 'NOT FOUND')"
echo

echo "Starting application..."
echo "======================"
./work/bin/desk-pet