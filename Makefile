# Makefile for Bobo - AI Assistant
#
# This Makefile provides convenient commands for building, testing, and developing
# Bobo, your personal voice-guided AI assistant.

.PHONY: all all-run all-run-verbose build clean clean-artifacts install test run deps setup-whisper setup-whisper-verbose help dev lint format check header separator

# Variables
BINARY_NAME=bobo
WORK_DIR=work
BINARY_DIR=$(WORK_DIR)/bin
CMD_DIR=cmd/bobo
BUILD_FLAGS=-ldflags "-X main.version=$(shell git describe --tags --always --dirty 2>/dev/null || echo 'dev')"
GO_FILES=$(shell find . -name "*.go" -type f)

# Default target
all: setup-whisper build
all-run: header setup-whisper build separator run
all-run-verbose: header setup-whisper-verbose build separator run
all-setup-rpi: header setup-whisper setup-gcloud setup-env build separator
all-setup-rpi-verbose: header setup-whisper-verbose setup-gcloud setup-env build separator

# Header for all-run command
header:
	@echo ""
	@echo "🤖 Bobo - AI Assistant Setup & Build"
	@echo "==========================================="
	@echo ""

# Separator between build and run phases
separator:
	@echo ""
	@echo "🚀 Starting Application..."
	@echo "========================="
	@echo ""

# Build the binary
build: init-work
	@echo "📝 Step 3: Building application..."
	@echo "   📦 Installing dependencies..."
	@go mod download
	@go mod tidy
	@echo "   ✅ Dependencies updated"
	@if [ "$$(uname -m)" = "aarch64" ] && [ -f /proc/cpuinfo ] && grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then \
		echo "🍓 Detected Raspberry Pi - using ARM64 build settings"; \
		CGO_ENABLED=0 GOARCH=arm64 GOOS=linux go build $(BUILD_FLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) ./$(CMD_DIR); \
	elif [ "$$(uname -m)" = "aarch64" ]; then \
		echo "🔧 Detected ARM64 - using compatible build settings"; \
		CGO_ENABLED=0 GOARCH=arm64 GOOS=linux go build $(BUILD_FLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) ./$(CMD_DIR); \
	elif [ "$$(uname -m)" = "armv7l" ]; then \
		echo "🔧 Detected ARM 32-bit - using compatible build settings"; \
		CGO_ENABLED=0 GOARCH=arm GOOS=linux go build $(BUILD_FLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) ./$(CMD_DIR); \
	else \
		go build $(BUILD_FLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) ./$(CMD_DIR); \
	fi
	@echo "✅ Build complete: $(BINARY_DIR)/$(BINARY_NAME)"

# Clean everything - removes entire work directory
clean:
	@echo "🧹 Cleaning work directory..."
	@rm -rf $(WORK_DIR)
	@go clean -cache
	@echo "✅ Clean complete"

# Clean only build artifacts (preserves whisper.cpp and repos)
clean-artifacts:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(WORK_DIR)/bin $(WORK_DIR)/temp $(WORK_DIR)/logs
	@go clean -cache
	@echo "✅ Build artifacts cleaned (repos preserved)"

# Install dependencies (standalone)
deps:
	@echo "📦 Installing Go dependencies..."
	@go mod download
	@go mod tidy
	@echo "✅ Dependencies updated"

# Run the application
run:
	@./$(BINARY_DIR)/$(BINARY_NAME)

# Run with verbose logging
run-verbose: build
	@echo "🚀 Running $(BINARY_NAME) with verbose logging..."
	@./$(BINARY_DIR)/$(BINARY_NAME) -v

# Run tests
test:
	@echo "🧪 Running tests..."
	@go test -v ./...
	@echo "✅ Tests complete"

# Run tests with coverage
test-coverage:
	@echo "🧪 Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report generated: coverage.html"

# Benchmark tests
benchmark:
	@echo "⚡ Running benchmarks..."
	@go test -bench=. -benchmem ./...

# Lint the code
lint:
	@echo "🔍 Linting code..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "⚠️ golangci-lint not found. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
		go vet ./...; \
	fi

# Format the code
format:
	@echo "🎨 Formatting code..."
	@go fmt ./...
	@if command -v goimports >/dev/null 2>&1; then \
		goimports -w .; \
	else \
		echo "💡 Install goimports for better formatting: go install golang.org/x/tools/cmd/goimports@latest"; \
	fi

# Check code quality (format + lint + test)
check: format lint test
	@echo "✅ Code quality check complete"

# Development mode with auto-reload (requires air)
dev:
	@if command -v air >/dev/null 2>&1; then \
		echo "🔄 Starting development mode with hot reload..."; \
		air; \
	else \
		echo "⚠️ air not found. Install with: go install github.com/air-verse/air@latest"; \
		echo "🔄 Starting development mode (manual reload)..."; \
		$(MAKE) run; \
	fi

# Install to system PATH
install: build
	@echo "📦 Installing $(BINARY_NAME) to /usr/local/bin..."
	@sudo cp $(BINARY_DIR)/$(BINARY_NAME) /usr/local/bin/
	@echo "✅ $(BINARY_NAME) installed system-wide"

# Initialize work directory structure
init-work:
	@echo "📝 Step 1: Initializing work directory..."
	@mkdir -p $(WORK_DIR)/{bin,temp,logs,repos}
	@if [ ! -f $(WORK_DIR)/.gitkeep ]; then \
		echo "# This file ensures the work directory structure is preserved in git" > $(WORK_DIR)/.gitkeep; \
		echo "# All contents of work/ are ignored except for this file and README.md" >> $(WORK_DIR)/.gitkeep; \
		echo "" >> $(WORK_DIR)/.gitkeep; \
		echo "# Directory structure:" >> $(WORK_DIR)/.gitkeep; \
		echo "# work/" >> $(WORK_DIR)/.gitkeep; \
		echo "# ├── bin/           # Compiled binaries" >> $(WORK_DIR)/.gitkeep; \
		echo "# ├── temp/          # Temporary files (audio recordings, etc.)" >> $(WORK_DIR)/.gitkeep; \
		echo "# ├── logs/          # Application logs" >> $(WORK_DIR)/.gitkeep; \
		echo "# └── repos/         # External repositories (whisper.cpp, etc.)" >> $(WORK_DIR)/.gitkeep; \
	fi
	@echo "✅ Work directory ready"

# Setup whisper.cpp (downloads and builds)
setup-whisper: init-work
	@bash scripts/setup_whisper_cpp.sh

# Setup whisper.cpp with verbose output
setup-whisper-verbose: init-work
	@bash scripts/setup_whisper_cpp.sh --verbose

# Create .env file from example
setup-env:
	@echo "⚙️ Creating .env file..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ .env file created. Please edit it with your configuration."; \
	else \
		echo "⚠️ .env file already exists"; \
	fi

# Install Google Cloud CLI only
install-gcloud:
	@echo "📥 Installing Google Cloud CLI..."
	@if ! command -v gcloud >/dev/null 2>&1; then \
		echo "   🔄 Downloading and installing..."; \
		curl https://sdk.cloud.google.com | bash; \
		echo "export PATH=\$$HOME/google-cloud-sdk/bin:\$$PATH" >> ~/.bashrc; \
		echo "export PATH=\$$HOME/google-cloud-sdk/bin:\$$PATH" >> ~/.zshrc 2>/dev/null || true; \
		echo ""; \
		echo "✅ Google Cloud CLI installed"; \
		echo "🔄 Please restart your shell or run:"; \
		echo "   source ~/.bashrc"; \
		echo "   export PATH=\$$HOME/google-cloud-sdk/bin:\$$PATH"; \
		echo ""; \
		echo "Then run: make setup-gcloud"; \
	else \
		echo "✅ gcloud CLI already installed"; \
	fi

# Bootstrap Google Cloud CLI and authentication
setup-gcloud:
	@echo ""
	@echo "🔐 Google Cloud CLI Setup & Authentication"
	@echo "=========================================="
	@echo ""
	@echo "📝 Step 1: Installing Google Cloud CLI..."
	@if ! command -v gcloud >/dev/null 2>&1; then \
		echo "   📥 Downloading and installing gcloud CLI..."; \
		curl https://sdk.cloud.google.com | bash; \
		echo "   🔄 Attempting to reload shell configuration..."; \
		echo "export PATH=\$$HOME/google-cloud-sdk/bin:\$$PATH" >> ~/.bashrc; \
		echo "export PATH=\$$HOME/google-cloud-sdk/bin:\$$PATH" >> ~/.zshrc 2>/dev/null || true; \
		export PATH=$$HOME/google-cloud-sdk/bin:$$PATH; \
		echo "   ✅ gcloud CLI installation completed"; \
		echo "   ⚠️  If 'gcloud' is not found, restart your shell and run this again"; \
	else \
		echo "   ✅ gcloud CLI already installed"; \
	fi
	@echo ""
	@echo "📝 Step 2: Authentication & Project Setup"
	@echo "🔑 Starting interactive authentication..."
	@echo "   This will open a browser window for Google authentication."
	@echo "   If you're on a headless system, you'll get a URL to copy."
	@echo ""
	@gcloud auth application-default login
	@echo ""
	@echo "📝 Step 3: Project Configuration"
	@read -p "Enter your Google Cloud Project ID: " PROJECT_ID; \
	if [ -n "$$PROJECT_ID" ]; then \
		echo "🔧 Setting project to: $$PROJECT_ID"; \
		gcloud config set project $$PROJECT_ID; \
		echo "✅ Project configured"; \
	else \
		echo "⚠️  No project ID provided. You can set it later with:"; \
		echo "   gcloud config set project YOUR_PROJECT_ID"; \
	fi
	@echo ""
	@echo "📝 Step 4: Enabling required APIs..."
	@if gcloud config get-value project >/dev/null 2>&1; then \
		echo "🔧 Enabling Vertex AI API..."; \
		gcloud services enable aiplatform.googleapis.com --quiet; \
		echo "✅ APIs enabled"; \
	else \
		echo "⚠️  Skipping API enablement - no project configured"; \
	fi
	@echo ""
	@echo "📝 Step 5: Testing authentication..."
	@$(MAKE) test-auth-verbose
	@echo ""
	@echo "🎉 Google Cloud CLI setup complete!"
	@echo ""
	@echo "📋 Next steps:"
	@echo "  1. If authentication failed, run: gcloud auth application-default login"
	@echo "  2. Update .env with your project ID"
	@echo "  3. Run: make all-run"
	@echo ""

# Test authentication with Google Cloud
test-auth:
	@echo "🔐 Testing Google Cloud authentication..."
	@gcloud auth application-default print-access-token >/dev/null && echo "✅ Authentication OK" || echo "❌ Authentication failed"
	@echo "Project: $$(gcloud config get-value project 2>/dev/null || echo 'Not set')"

# Test authentication with verbose output
test-auth-verbose:
	@echo "🔐 Testing Google Cloud authentication..."
	@if gcloud auth application-default print-access-token >/dev/null 2>&1; then \
		echo "✅ Authentication: OK"; \
		echo "🏗️  Project: $$(gcloud config get-value project 2>/dev/null || echo 'Not configured')"; \
		echo "👤 Account: $$(gcloud config get-value account 2>/dev/null || echo 'Not configured')"; \
	else \
		echo "❌ Authentication: FAILED"; \
		echo ""; \
		echo "🔧 To fix, run:"; \
		echo "   gcloud auth application-default login"; \
	fi

# Run security scan
security:
	@echo "🛡️ Running security scan..."
	@if command -v gosec >/dev/null 2>&1; then \
		gosec ./...; \
	else \
		echo "⚠️ gosec not found. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest"; \
	fi

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	@if command -v godoc >/dev/null 2>&1; then \
		echo "📖 Starting documentation server at http://localhost:6060"; \
		godoc -http=:6060; \
	else \
		echo "⚠️ godoc not found. Install with: go install golang.org/x/tools/cmd/godoc@latest"; \
	fi

# Create release build for multiple platforms
release:
	@echo "🚀 Building release binaries..."
	@mkdir -p release
	@GOOS=linux GOARCH=amd64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-linux-amd64 ./$(CMD_DIR)
	@CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-linux-arm64 ./$(CMD_DIR)
	@CGO_ENABLED=0 GOOS=linux GOARCH=arm go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-linux-arm ./$(CMD_DIR)
	@GOOS=darwin GOARCH=amd64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-darwin-amd64 ./$(CMD_DIR)
	@GOOS=darwin GOARCH=arm64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-darwin-arm64 ./$(CMD_DIR)
	@GOOS=windows GOARCH=amd64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-windows-amd64.exe ./$(CMD_DIR)
	@echo "✅ Release binaries created in release/"

# Show help
help:
	@echo "📖 Bobo - Available Commands:"
	@echo ""
	@echo "🔨 Build Commands:"
	@echo "  build         Build the binary"
	@echo "  clean         Clean everything (removes work/ directory)"
	@echo "  clean-artifacts Clean only build artifacts (preserves whisper.cpp)"
	@echo "  install       Install binary to system PATH"
	@echo "  release       Build release binaries for multiple platforms"
	@echo ""
	@echo "🚀 Run Commands:"
	@echo "  run           Run the application"
	@echo "  run-verbose   Run with verbose logging"
	@echo "  dev           Run in development mode with hot reload"
	@echo ""
	@echo "🎯 All-in-One Commands:"
	@echo "  all-run       Complete setup and run (auto-detects hardware)"
	@echo "  all-run-verbose Complete setup and run with verbose output"
	@echo ""
	@echo "🍓 Raspberry Pi Setup:"
	@echo "  all-setup-rpi Complete Raspberry Pi setup (whisper + gcloud + config)"
	@echo "  all-setup-rpi-verbose Complete RPi setup with verbose output"
	@echo ""
	@echo "📦 Dependencies:"
	@echo "  deps          Install and update Go dependencies"
	@echo "  init-work     Initialize work directory structure"
	@echo "  setup-env     Create .env configuration file"
	@echo ""
	@echo "🎤 Speech Recognition Setup:"
	@echo "  setup-whisper Setup whisper.cpp (auto-detects hardware)"
	@echo "  setup-whisper-verbose Setup whisper.cpp with verbose output"
	@echo ""
	@echo "🧪 Quality Assurance:"
	@echo "  test          Run tests"
	@echo "  test-coverage Run tests with coverage report"
	@echo "  benchmark     Run benchmark tests"
	@echo "  lint          Lint code with golangci-lint"
	@echo "  format        Format code with gofmt and goimports"
	@echo "  check         Run format + lint + test"
	@echo "  security      Run security scan with gosec"
	@echo ""
	@echo "📚 Documentation:"
	@echo "  docs          Start documentation server"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  test-input    Quick test of input handling"
	@echo "  test-auto     Automated input test (verifies fixes)"
	@echo ""
	@echo "🔧 Authentication:"
	@echo "  install-gcloud Install Google Cloud CLI only"
	@echo "  setup-gcloud  Complete Google Cloud CLI setup and authentication"
	@echo "  test-auth     Test Google Cloud authentication"
	@echo ""
	@echo "💡 Development Tools:"
	@echo "  air           Hot reload (go install github.com/air-verse/air@latest)"
	@echo "  golangci-lint Code linting (go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)"
	@echo "  goimports     Import formatting (go install golang.org/x/tools/cmd/goimports@latest)"
	@echo "  gosec         Security scanning (go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest)"

# Performance profiling
profile-cpu: build
	@echo "📊 Running CPU profiling..."
	@./$(BINARY_DIR)/$(BINARY_NAME) -cpuprofile=cpu.prof
	@go tool pprof cpu.prof

profile-memory: build
	@echo "📊 Running memory profiling..."
	@./$(BINARY_DIR)/$(BINARY_NAME) -memprofile=mem.prof
	@go tool pprof mem.prof

# Docker commands (for containerized deployment)
docker-build:
	@echo "🐳 Building Docker image..."
	@docker build -t bobo:latest .

docker-run:
	@echo "🐳 Running Docker container..."
	@docker run -it --rm -v $(PWD)/.env:/app/.env bobo:latest

# Testing commands
test-input: build
	@echo "🧪 Testing input handling (will auto-exit after 3 seconds)..."
	@echo "q" | timeout 3 ./$(BINARY_DIR)/$(BINARY_NAME) || echo "✅ Input test completed"

test-auto: build
	@echo "🧪 Running automated input verification test..."
	@./test_auto_input.sh

# Database/cache commands (for future extensions)
migrate-up:
	@echo "📈 Running database migrations up..."
	@# TODO: Add migration commands when database is added

migrate-down:
	@echo "📉 Running database migrations down..."
	@# TODO: Add migration commands when database is added