# Troubleshooting Guide

## Common Issues

### "whisper.cpp not found"
```bash
make setup-whisper
# Or check WHISPER_CPP_PATH in .env
```

### "No audio device"
```bash
# Linux
sudo apt-get install portaudio19-dev alsa-utils

# Check microphone permissions in system settings
```

### "Input not working (^M characters)"
This should be fixed with the readline library implementation.
If still having issues, try different terminal:
- bash/zsh instead of fish
- Terminal.app instead of custom terminal
- Check terminal encoding (should be UTF-8)

### "TTS not working"
```bash
# Linux - install espeak
sudo apt-get install espeak espeak-data

# Test TTS manually
espeak "Hello this is a test"

# If TTS still fails, the app will run without voice output (TTS disabled)
```

### "gcloud auth errors"
```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### "Vertex AI permission denied"
- Verify project ID in .env
- Check IAM roles in GCP Console
- Ensure Vertex AI API is enabled

### Getting Help

1. Check logs with `make run-verbose`
2. Test components individually:
   - `make test-auth` for authentication
   - `make setup-whisper` for voice recognition
3. Review `.env` configuration
4. Check system dependencies

## Performance Issues

### Slow transcription
- Consider using smaller whisper model (tiny/base instead of small)
- Check available system RAM
- Monitor CPU usage during transcription

### High memory usage
- Use smaller whisper.cpp models
- Check for memory leaks with `go tool pprof`

## Debug Mode

Run with verbose logging to see detailed information:
```bash
make run-verbose
```

Or build with debug info:
```bash
make all-run-verbose
```