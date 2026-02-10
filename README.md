# Bobo - Your Personal AI Assistant

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Go Version](https://img.shields.io/badge/go-1.25+-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)

> 👋 **Hello! I'm Bobo, your personal voice-guided assistant.** I can help you with intelligent conversations, answer questions, and control different functions using just your voice. I'm here to make your day easier and more productive.

A high-performance AI assistant developed in Go with Claude AI integration, voice recognition, and text-to-speech capabilities.

## ✨ Features

- **🤖 Claude AI Integration** - Smart conversations via Google Cloud Vertex AI
- **🎤 Voice Recognition** - Real-time speech-to-text with whisper.cpp
- **🔊 Text-to-Speech** - Multi-platform audio output
- **⚡ High Performance** - 15-25x faster than Python version
- **📦 Single Binary** - No runtime dependencies
- **🗺️ Future-Ready** - Roadmap includes TinyGo ESP32 integration ([see roadmap](docs/ROADMAP.md))

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/jparrill/bobo-desk-pet
cd bobo-desk-pet

# Configure (edit with your Google Cloud project ID)
cp .env.example .env
nano .env

# Build and run everything
make all-run
```

## 🎯 Usage

Once running, use these commands:
- `r` + ENTER: Record and process voice (7 seconds)
- `l` + ENTER: Long recording (12 seconds)
- `t` + ENTER: Test microphone
- `x` + ENTER: Test text-to-speech
- `s` + ENTER: Toggle speech on/off
- `q` + ENTER: Quit

## 📋 Requirements

- **Go 1.21+**
- **Google Cloud account** with Vertex AI enabled
- **gcloud CLI** installed and configured

## 📚 Documentation

- **[Project Roadmap](docs/ROADMAP.md)** - Vision, phases, and future plans
- **[Changelog](CHANGELOG.md)** - Release notes and version history
- **[Setup Guide](docs/setup.md)** - Detailed installation and configuration
- **[Authentication](docs/authentication.md)** - Google Cloud setup
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Development](docs/development.md)** - Build commands and development guide

## 🔧 Common Commands

```bash
make build          # Build the application
make run            # Run the application
make clean          # Clean build artifacts
make test-auth      # Test Google Cloud authentication
make help           # Show all available commands
```

## 🆘 Getting Help

If you encounter issues:

1. **Check authentication**: `make test-auth`
2. **View verbose logs**: `make run-verbose`
3. **See troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)

## 📄 License

This project is licensed under the [MIT License](LICENSE) - feel free to use, modify, and distribute as you wish!

---

**Made with ❤️ in Go** | [Documentation](docs/) | [Roadmap](docs/ROADMAP.md) | [Development Guide](docs/development.md)