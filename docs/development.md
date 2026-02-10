# Bobo Development Guide

## Available Make Commands

### Building
```bash
make build          # Build the binary
make clean          # Clean everything (removes work/ directory)
make clean-artifacts # Clean only build artifacts (preserves whisper.cpp)
make install        # Install to system PATH
```

### Running
```bash
make run            # Run application
make dev            # Development mode with hot reload
make run-verbose    # Run with verbose logging
```

### Quality Assurance
```bash
make test           # Run tests
make lint           # Lint code
make format         # Format code
make check          # Format + lint + test
```

### Setup
```bash
make setup-whisper # Install whisper.cpp
make setup-env      # Create .env from template
make test-auth      # Test Google Cloud auth
```

## Performance Comparison (Go vs Python)

| Metric | Python Version | Go Version | Improvement |
|--------|---------------|------------|-------------|
| Startup Time | ~3-5 seconds | ~200ms | 15-25x faster |
| Memory Usage | ~200-500MB | ~30-50MB | 4-10x less |
| Binary Size | Dependencies required | Single 15MB binary | Self-contained |
| Response Time | ~200ms | ~50ms | 4x faster |
| Concurrency | asyncio (emulated) | Native goroutines | True parallelism |

## whisper.cpp Models

| Model | Size | Speed | RAM Usage | Accuracy |
|-------|------|-------|-----------|----------|
| tiny | 39 MB | ~32x realtime | ~1 GB | Good |
| base | 74 MB | ~16x realtime | ~1 GB | Better |
| small | 244 MB | ~6x realtime | ~2 GB | **Recommended** |
| medium | 769 MB | ~2x realtime | ~3 GB | Very Good |
| large | 1550 MB | ~1x realtime | ~4 GB | Best |

## Development Workflow

### 1. Setup Development Environment
```bash
# Clone and setup
git clone https://github.com/jparrill/bobo-desk-pet
cd bobo-desk-pet
cp .env.example .env
# Edit .env with your settings

# Install dependencies
make setup-whisper
make deps
```

### 2. Make Changes
```bash
# Build and test
make build
make test

# Run with changes
make run-verbose
```

### 3. Quality Checks
```bash
# Format and lint
make format
make lint

# Full quality check
make check
```

### 4. Clean Builds
```bash
# Clean build artifacts only (fast)
make clean-artifacts && make build

# Complete clean rebuild
make clean && make all-run
```

## Code Organization

### Package Structure
- `cmd/bobo/` - Main application entry point
- `pkg/claude/` - Claude AI client implementations
- `pkg/voice/` - Voice recognition and TTS
- `pkg/config/` - Configuration management
- `internal/` - Private application code
- `scripts/` - Setup and utility scripts

### Key Files
- `Makefile` - Build automation and commands
- `.env.example` - Configuration template
- `go.mod` - Go module dependencies
- `work/` - Build artifacts (gitignored)