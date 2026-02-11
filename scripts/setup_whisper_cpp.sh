#!/bin/bash

# Setup script for whisper.cpp - Fast C++ implementation of OpenAI's Whisper
# This script downloads, builds, and configures whisper.cpp for the desk pet

set -e  # Exit on any error

# Default settings
VERBOSE=false

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd)"
WORK_DIR="$PROJECT_DIR/work"
WHISPER_DIR="$WORK_DIR/repos/whisper.cpp"


# Create work directory structure
mkdir -p "$WORK_DIR"/{bin,temp,logs,repos}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Install system dependencies
install_dependencies() {
    if [ "$VERBOSE" = true ]; then
        echo "📦 Installing system dependencies..."
    fi

    case $OS in
        "linux")
            if command -v apt-get >/dev/null 2>&1; then
                if [ "$VERBOSE" = true ]; then
                    sudo apt-get update
                    sudo apt-get install -y build-essential cmake git
                else
                    sudo apt-get update >/dev/null 2>&1
                    sudo apt-get install -y build-essential cmake git >/dev/null 2>&1
                fi
            elif command -v yum >/dev/null 2>&1; then
                if [ "$VERBOSE" = true ]; then
                    sudo yum groupinstall -y "Development Tools"
                    sudo yum install -y cmake git
                else
                    sudo yum groupinstall -y "Development Tools" >/dev/null 2>&1
                    sudo yum install -y cmake git >/dev/null 2>&1
                fi
            elif command -v pacman >/dev/null 2>&1; then
                if [ "$VERBOSE" = true ]; then
                    sudo pacman -S --needed base-devel cmake git
                else
                    sudo pacman -S --needed base-devel cmake git >/dev/null 2>&1
                fi
            else
                echo "⚠️  Please install build-essential, cmake, and git manually"
            fi
            ;;
        "macos")
            if ! command -v git >/dev/null 2>&1; then
                echo "⚠️  Please install Xcode Command Line Tools: xcode-select --install"
                exit 1
            fi
            if ! command -v cmake >/dev/null 2>&1; then
                if command -v brew >/dev/null 2>&1; then
                    if [ "$VERBOSE" = true ]; then
                        brew install cmake
                    else
                        brew install cmake >/dev/null 2>&1
                    fi
                else
                    echo "⚠️  Please install cmake manually or use Homebrew"
                    exit 1
                fi
            fi
            ;;
        "windows")
            echo "⚠️  Windows setup requires manual installation of:"
            echo "   - Visual Studio 2019+ or Build Tools"
            echo "   - CMake"
            echo "   - Git"
            echo "   Please install these and run the script again"
            ;;
        *)
            echo "⚠️  Unsupported OS. Please install build tools, cmake, and git manually"
            ;;
    esac
}

# Clone whisper.cpp repository
clone_whisper_cpp() {
    if [ "$VERBOSE" = true ]; then
        echo "📥 Downloading whisper.cpp..."
    fi

    # Save current directory
    local ORIGINAL_DIR="$(pwd)"

    # Redirect output based on verbose mode
    local REDIRECT=""
    if [ "$VERBOSE" != true ]; then
        REDIRECT=">/dev/null 2>&1"
    fi

    if [ -d "$WHISPER_DIR" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "⚠️  whisper.cpp directory already exists. Updating..."
        fi
        cd "$WHISPER_DIR" || {
            if [ "$VERBOSE" = true ]; then
                echo "❌ Failed to cd to $WHISPER_DIR, removing and re-cloning..."
            fi
            rm -rf "$WHISPER_DIR"
            if [ "$VERBOSE" = true ]; then
                git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
            else
                git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR" >/dev/null 2>&1
            fi
            cd "$ORIGINAL_DIR"
            return 0
        }

        if [ "$VERBOSE" = true ]; then
            git pull origin master || {
                echo "❌ Failed to update whisper.cpp. Removing and re-cloning..."
                cd "$ORIGINAL_DIR"
                rm -rf "$WHISPER_DIR"
                git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
            }
        else
            git pull origin master >/dev/null 2>&1 || {
                cd "$ORIGINAL_DIR"
                rm -rf "$WHISPER_DIR"
                git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR" >/dev/null 2>&1
            }
        fi
        cd "$ORIGINAL_DIR"
    else
        # Ensure parent directory exists
        mkdir -p "$(dirname "$WHISPER_DIR")"
        git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
    fi

    if [ "$VERBOSE" = true ]; then
        echo "✅ whisper.cpp source code ready"
    fi
}

# Detect hardware and return appropriate cmake flags
detect_hardware_flags() {
    local CMAKE_FLAGS=""
    local ARCH=$(uname -m)

    # Check if we're on Raspberry Pi ARM64
    if [ "$ARCH" = "aarch64" ] && [ -f /proc/cpuinfo ]; then
        if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
            # Raspberry Pi ARM64 - optimized for Cortex-A72
            CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DWHISPER_NO_AVX=ON -DWHISPER_NO_AVX2=ON -DWHISPER_NO_FMA=ON -DWHISPER_NO_F16C=ON -DCMAKE_CXX_FLAGS=\"-mcpu=cortex-a72 -mtune=cortex-a72 -O3\" -DCMAKE_EXE_LINKER_FLAGS=\"-latomic\""
        else
            # Generic ARM64, but not RPi
            CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DWHISPER_NO_AVX=ON -DWHISPER_NO_AVX2=ON -DWHISPER_NO_FMA=ON -DWHISPER_NO_F16C=ON -DCMAKE_EXE_LINKER_FLAGS=\"-latomic\""
        fi
    elif [ "$ARCH" = "armv7l" ]; then
        # 32-bit ARM (older RPi)
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DWHISPER_NO_AVX=ON -DWHISPER_NO_AVX2=ON -DWHISPER_NO_FMA=ON -DWHISPER_NO_F16C=ON -DCMAKE_EXE_LINKER_FLAGS=\"-latomic\""
    else
        # x86_64 or other architectures - use default
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"
    fi

    echo "$CMAKE_FLAGS"
}

# Detect hardware type and show appropriate message
show_hardware_detection() {
    local ARCH=$(uname -m)

    if [ "$VERBOSE" = true ]; then
        if [ "$ARCH" = "aarch64" ] && [ -f /proc/cpuinfo ]; then
            if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
                echo "🍓 Detected Raspberry Pi ARM64 - using optimized flags"
            else
                echo "🔧 Detected ARM64 - using compatible flags"
            fi
        elif [ "$ARCH" = "armv7l" ]; then
            echo "🔧 Detected ARM 32-bit - using compatible flags"
        else
            echo "🔧 Using standard build configuration for $ARCH"
        fi
    fi
}

# Build whisper.cpp
build_whisper_cpp() {
    echo "   🔨 Building whisper.cpp..."

    # Save current directory
    local ORIGINAL_DIR="$(pwd)"

    cd "$WHISPER_DIR" || {
        echo "❌ Failed to cd to $WHISPER_DIR"
        return 1
    }

    # Create build directory
    mkdir -p build
    cd build || {
        echo "❌ Failed to cd to build directory"
        cd "$ORIGINAL_DIR"
        return 1
    }

    # Build with appropriate number of cores
    if command -v nproc >/dev/null 2>&1; then
        CORES=$(nproc)
    elif command -v sysctl >/dev/null 2>&1; then
        CORES=$(sysctl -n hw.ncpu)
    else
        CORES=4
    fi

    # Show hardware detection message
    show_hardware_detection

    # Get hardware-specific cmake flags
    local CMAKE_FLAGS=$(detect_hardware_flags)

    if [ "$VERBOSE" = true ]; then
        # Configure and build with full output
        echo "🔧 Building with $CORES cores..."
        if [ -n "$CMAKE_FLAGS" ]; then
            echo "🎛️  Using flags: $CMAKE_FLAGS"
            eval "cmake .. $CMAKE_FLAGS"
        else
            cmake ..
        fi
        make -j$CORES
        echo "✅ whisper.cpp built successfully"
    else
        # Silent build
        if [ -n "$CMAKE_FLAGS" ]; then
            eval "cmake .. $CMAKE_FLAGS" >/dev/null 2>&1
        else
            cmake .. >/dev/null 2>&1
        fi
        make -j$CORES >/dev/null 2>&1
    fi

    # Return to original directory
    cd "$ORIGINAL_DIR"
}

# Download whisper models
download_models() {
    if [ "$VERBOSE" = true ]; then
        echo "📥 Downloading whisper models..."
    fi

    # Save current directory
    local ORIGINAL_DIR="$(pwd)"

    # Ensure whisper directory exists
    if [ ! -d "$WHISPER_DIR" ]; then
        echo "❌ whisper.cpp directory not found: $WHISPER_DIR"
        return 1
    fi

    cd "$WHISPER_DIR" || {
        echo "❌ Failed to cd to $WHISPER_DIR"
        return 1
    }

    # Create models directory
    mkdir -p models

    # Download models using the official script
    if [ ! -f "models/ggml-small.bin" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "🔄 Downloading 'small' model (~244 MB)..."
        fi
        if [ -f "./models/download-ggml-model.sh" ]; then
            if [ "$VERBOSE" = true ]; then
                bash ./models/download-ggml-model.sh small
                echo "✅ Small model downloaded"
            else
                bash ./models/download-ggml-model.sh small >/dev/null 2>&1
            fi
        else
            if [ "$VERBOSE" = true ]; then
                echo "⚠️  Download script not found, attempting alternative download..."
            fi
            # Fallback download method if the script doesn't exist
            if [ "$VERBOSE" = true ]; then
                curl -L -o "models/ggml-small.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
            else
                curl -L -o "models/ggml-small.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" >/dev/null 2>&1
            fi
        fi
    else
        if [ "$VERBOSE" = true ]; then
            echo "✅ Small model already exists"
        fi
    fi

    # Optionally download base model (smaller, faster)
    if [ "$1" = "--include-base" ]; then
        if [ ! -f "models/ggml-base.bin" ]; then
            if [ "$VERBOSE" = true ]; then
                echo "🔄 Downloading 'base' model (~74 MB)..."
            fi
            if [ -f "./models/download-ggml-model.sh" ]; then
                if [ "$VERBOSE" = true ]; then
                    bash ./models/download-ggml-model.sh base
                    echo "✅ Base model downloaded"
                else
                    bash ./models/download-ggml-model.sh base >/dev/null 2>&1
                fi
            else
                if [ "$VERBOSE" = true ]; then
                    echo "⚠️  Download script not found, attempting alternative download..."
                    curl -L -o "models/ggml-base.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
                else
                    curl -L -o "models/ggml-base.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" >/dev/null 2>&1
                fi
            fi
        else
            if [ "$VERBOSE" = true ]; then
                echo "✅ Base model already exists"
            fi
        fi
    fi

    if [ "$VERBOSE" = true ]; then
        echo "📊 Available models:"
        ls -lh models/ggml-*.bin 2>/dev/null || echo "No models found"
    fi

    # Return to original directory
    cd "$ORIGINAL_DIR"
}

# Test whisper.cpp installation
test_whisper_cpp() {
    echo "🧪 Testing whisper.cpp installation..."

    WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
    LEGACY_BIN="$WHISPER_DIR/build/bin/main"

    # Try to find the binary
    if [ -f "$WHISPER_BIN" ]; then
        WHISPER_EXEC="$WHISPER_BIN"
    elif [ -f "$LEGACY_BIN" ]; then
        WHISPER_EXEC="$LEGACY_BIN"
    else
        echo "❌ whisper.cpp binary not found"
        echo "   Expected locations:"
        echo "   - $WHISPER_BIN"
        echo "   - $LEGACY_BIN"
        exit 1
    fi

    # Test help command
    if "$WHISPER_EXEC" --help >/dev/null 2>&1; then
        echo "✅ whisper.cpp is working correctly"
        echo "🎯 Binary location: $WHISPER_EXEC"
    else
        echo "❌ whisper.cpp binary exists but doesn't work correctly"
        exit 1
    fi
}

# Create test audio for verification
create_test_audio() {
    echo "🎵 Creating test audio..."

    # Save current directory
    local ORIGINAL_DIR="$(pwd)"

    # Create test audio in whisper directory
    cd "$WHISPER_DIR" || {
        echo "⚠️  Failed to cd to $WHISPER_DIR, skipping test audio creation"
        return 0
    }

    case $OS in
        "macos")
            if command -v say >/dev/null 2>&1; then
                say "Hello this is a test of whisper speech recognition" -o test_audio.aiff
                # Convert to WAV if ffmpeg is available
                if command -v ffmpeg >/dev/null 2>&1; then
                    ffmpeg -i test_audio.aiff -ar 16000 -ac 1 test_audio.wav -y >/dev/null 2>&1
                    rm test_audio.aiff
                    echo "✅ Test audio created: test_audio.wav"
                else
                    echo "✅ Test audio created: test_audio.aiff (install ffmpeg to convert to WAV)"
                fi
            fi
            ;;
        "linux")
            if command -v espeak >/dev/null 2>&1; then
                espeak "Hello this is a test of whisper speech recognition" -w test_audio.wav --stdout
                echo "✅ Test audio created: test_audio.wav"
            fi
            ;;
        *)
            echo "⚠️  Skipping test audio creation (no TTS available)"
            ;;
    esac

    # Return to original directory
    cd "$ORIGINAL_DIR"
}

# Update .env file with whisper.cpp paths
update_env_config() {
    if [ "$VERBOSE" = true ]; then
        echo "⚙️  Updating configuration..."
    fi

    ENV_FILE="$PROJECT_DIR/.env"
    ENV_EXAMPLE="$PROJECT_DIR/.env.example"

    WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
    LEGACY_BIN="$WHISPER_DIR/build/bin/main"

    # Determine which binary to use
    if [ -f "$WHISPER_BIN" ]; then
        WHISPER_EXEC="$WHISPER_BIN"
    elif [ -f "$LEGACY_BIN" ]; then
        WHISPER_EXEC="$LEGACY_BIN"
    else
        echo "⚠️  Could not determine whisper.cpp binary location"
        return 1
    fi

    # Create .env from example if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        if [ "$VERBOSE" = true ]; then
            echo "✅ Created .env from .env.example"
        fi
    fi

    # Update paths in .env file
    if command -v sed >/dev/null 2>&1; then
        # Update whisper.cpp path
        sed -i.bak "s|^WHISPER_CPP_PATH=.*|WHISPER_CPP_PATH=$WHISPER_EXEC|" "$ENV_FILE" 2>/dev/null || {
            # Fallback for systems where sed -i behaves differently
            sed "s|^WHISPER_CPP_PATH=.*|WHISPER_CPP_PATH=$WHISPER_EXEC|" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        }

        # Update model path
        sed -i.bak "s|^WHISPER_CPP_MODEL=.*|WHISPER_CPP_MODEL=$WHISPER_DIR/models/ggml-small.bin|" "$ENV_FILE" 2>/dev/null || {
            sed "s|^WHISPER_CPP_MODEL=.*|WHISPER_CPP_MODEL=$WHISPER_DIR/models/ggml-small.bin|" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        }

        # Clean up backup files
        rm -f "$ENV_FILE.bak" "$ENV_FILE.tmp" 2>/dev/null

        if [ "$VERBOSE" = true ]; then
            echo "✅ Updated .env configuration"
        fi
    else
        echo "⚠️  Please manually update .env with:"
        echo "   WHISPER_CPP_PATH=$WHISPER_EXEC"
        echo "   WHISPER_CPP_MODEL=$WHISPER_DIR/models/ggml-small.bin"
    fi
}

# Print setup summary
print_summary() {
    echo ""
    echo "🎉 whisper.cpp Setup Complete!"
    echo "=================================================="
    echo ""
    echo "📁 Installation directory: $WHISPER_DIR"
    echo "🔧 Binary location: $(ls "$WHISPER_DIR"/build/bin/whisper* "$WHISPER_DIR"/build/bin/main 2>/dev/null | head -1)"
    echo "🤖 Available models:"
    ls -1 "$WHISPER_DIR/models/ggml-"*.bin 2>/dev/null | sed 's/.*ggml-/   - /' | sed 's/.bin//' || echo "   - No models found"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Edit .env file with your Google Cloud settings"
    echo "   2. Run: make build"
    echo "   3. Run: make run"
    echo ""
    echo "🧪 Test whisper.cpp:"
    echo "   ./$(ls "$WHISPER_DIR"/build/bin/whisper* "$WHISPER_DIR"/build/bin/main 2>/dev/null | head -1) -m $WHISPER_DIR/models/ggml-small.bin -f your_audio.wav"
    echo ""
}

# Main execution
main() {
    # Show header only in verbose mode
    if [ "$VERBOSE" = true ]; then
        echo "🤖 Bobo - whisper.cpp Setup Script"
        echo "==========================================="
        echo ""
    fi

    # Check if we're in the right directory
    if [ ! -f "$PROJECT_DIR/go.mod" ]; then
        echo "❌ Error: This script must be run from the desk_pet_go directory"
        echo "   Current directory: $(pwd)"
        echo "   Expected go.mod at: $PROJECT_DIR/go.mod"
        exit 1
    fi

    # Parse command line arguments
    INCLUDE_BASE=false
    VERBOSE=false
    for arg in "$@"; do
        case $arg in
            --include-base)
                INCLUDE_BASE=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --include-base    Also download the base model (74 MB)"
                echo "  --verbose, -v     Show detailed output (build logs, downloads, etc.)"
                echo "  --help, -h        Show this help message"
                echo ""
                echo "This script will:"
                echo "  1. Install system dependencies"
                echo "  2. Clone whisper.cpp repository"
                echo "  3. Build whisper.cpp from source"
                echo "  4. Download speech recognition models"
                echo "  5. Update .env configuration"
                echo ""
                exit 0
                ;;
        esac
    done

    # Show detailed info only in verbose mode
    if [ "$VERBOSE" = true ]; then
        echo "🔄 Setting up whisper.cpp for Bobo..."
        echo "📁 Project directory: $PROJECT_DIR"
        echo "📁 Work directory: $WORK_DIR"
        echo "📁 whisper.cpp will be installed to: $WHISPER_DIR"
        echo ""
    fi

    # Show simple message in non-verbose mode
    if [ "$VERBOSE" != true ]; then
        echo "📝 Step 2: Setting up whisper.cpp..."
    fi

    # Run setup steps
    install_dependencies
    clone_whisper_cpp
    build_whisper_cpp

    if [ "$INCLUDE_BASE" = true ]; then
        download_models --include-base
    else
        download_models
    fi

    update_env_config

    # Show completion message in non-verbose mode
    if [ "$VERBOSE" != true ]; then
        echo "✅ whisper.cpp ready"
    fi
}

# Run main function with all arguments
main "$@"