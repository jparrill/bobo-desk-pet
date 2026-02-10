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
	@go build $(BUILD_FLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) ./$(CMD_DIR)
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

# Test authentication with Google Cloud
test-auth:
	@echo "🔐 Testing Google Cloud authentication..."
	@gcloud auth application-default print-access-token >/dev/null && echo "✅ Authentication OK" || echo "❌ Authentication failed"
	@echo "Project: $$(gcloud config get-value project 2>/dev/null || echo 'Not set')"

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
	@GOOS=linux GOARCH=arm64 go build $(BUILD_FLAGS) -o release/$(BINARY_NAME)-linux-arm64 ./$(CMD_DIR)
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
	@echo "📦 Dependencies:"
	@echo "  deps          Install and update Go dependencies"
	@echo "  init-work     Initialize work directory structure"
	@echo "  setup-whisper Setup whisper.cpp for speech recognition"
	@echo "  setup-env     Create .env configuration file"
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