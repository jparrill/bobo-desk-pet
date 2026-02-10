# Manual Test Scripts

This folder contains manual testing scripts used during development.

## Scripts

- `test_audio_recording.sh` - Test audio recording functionality
- `test_input_fix.sh` - Test terminal input handling
- `test_auto_input.sh` - Automated input testing
- `test_input_real.sh` - Real input scenario testing
- `test_readline.sh` - Readline library testing

## Usage

These scripts were used to manually verify bug fixes and functionality during development:

```bash
# Example usage
cd desk_pet_go
./tests/manual/test_audio_recording.sh
```

## Status

These are **development testing scripts** - they may not work with the current codebase as they were created for specific debugging scenarios.

For current testing, use:
```bash
make test          # Run Go tests
make all-run       # Full integration test
```