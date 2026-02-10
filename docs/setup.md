# Setup Guide

## System Requirements

### Dependencies
- **Go 1.21+** for building
- **gcloud CLI** for Google Cloud authentication
- **whisper.cpp** for speech recognition (auto-installed)
- **espeak** for text-to-speech (Linux optional)

### Google Cloud Setup
- Google Cloud Project with Vertex AI API enabled
- Application Default Credentials configured
- Appropriate IAM permissions for Vertex AI

## Installation

### 1. Clone and Setup
```bash
git clone https://github.com/jparrill/bobo-desk-pet
cd bobo-desk-pet

# Copy configuration template
cp .env.example .env

# Edit .env with your Google Cloud project ID
nano .env
```

### 2. Install Dependencies
```bash
# Install Go dependencies and initialize work directory
make deps

# Setup whisper.cpp (downloads to work/repos/, builds, and configures)
make setup-whisper

# Test Google Cloud authentication
make test-auth
```

### 3. Build and Run
```bash
# Build the binary
make build

# Run the assistant
make run

# Or run with verbose logging
make run-verbose
```

## Configuration

Edit `.env` file for configuration:

```bash
# Google Cloud Settings
ANTHROPIC_VERTEX_PROJECT_ID=your-gcp-project-id
CLOUD_ML_REGION=us-east5
ANTHROPIC_MODEL=claude-sonnet-4@20250514

# Voice Recognition
USE_WHISPER_CPP=true
WHISPER_CPP_MODEL=./work/repos/whisper.cpp/models/ggml-small.bin

# Text-to-Speech
TTS_DISABLED=false
TTS_RATE=160
```

## Linux TTS Setup (Optional)

For text-to-speech support on Linux:

```bash
# Ubuntu/Debian
sudo apt-get install espeak espeak-data

# RHEL/CentOS/Fedora
sudo yum install espeak espeak-devel
# or
sudo dnf install espeak espeak-devel

# Arch Linux
sudo pacman -S espeak espeak-data
```

## Project Structure

```
bobo-desk-pet/
├── cmd/bobo/               # Main application entry point
├── pkg/
│   ├── claude/             # Claude AI client implementations
│   ├── voice/              # Voice recognition and TTS
│   └── config/             # Configuration management
├── scripts/                # Setup and utility scripts
├── work/                   # Build artifacts and external repos
│   ├── bin/                # Compiled binaries
│   ├── temp/               # Temporary files (audio, etc.)
│   └── repos/              # External repositories (whisper.cpp)
└── Makefile               # Build automation
```