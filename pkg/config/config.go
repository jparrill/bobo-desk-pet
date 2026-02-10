// Package config handles environment variable loading and configuration management
// Equivalent to the Python config_manager.py
package config

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds all configuration for the desk pet application
type Config struct {
	VertexAI *VertexAIConfig
	Voice    *VoiceConfig
	TTS      *TTSConfig
}

// VertexAIConfig contains Google Cloud Vertex AI configuration
type VertexAIConfig struct {
	ProjectID         string
	Location          string
	Model             string
	MaxTokens         int
	Temperature       float64
	SystemPrompt      string
	EnableAutoSearch  bool
}

// VoiceConfig contains voice recognition configuration
type VoiceConfig struct {
	UseWhisperCpp     bool
	WhisperCppPath    string
	WhisperModelPath  string
	SampleRate        int
	Channels          int
	ChunkSize         int
}

// TTSConfig contains text-to-speech configuration
type TTSConfig struct {
	Enabled    bool
	Rate       int
	Volume     float64
	VoiceID    string
}

// Load reads configuration from environment file and environment variables
func Load(envFile string) (*Config, error) {
	// Load .env file if it exists
	if err := loadEnvFile(envFile); err != nil {
		return nil, fmt.Errorf("failed to load env file: %w", err)
	}

	config := &Config{
		VertexAI: &VertexAIConfig{
			ProjectID:         getEnvString("ANTHROPIC_VERTEX_PROJECT_ID", "your-gcp-project-id"),
			Location:          getEnvString("CLOUD_ML_REGION", "us-east5"),
			Model:             getEnvString("ANTHROPIC_MODEL", "claude-sonnet-4@20250514"),
			MaxTokens:         getEnvInt("MAX_TOKENS", 1000),
			Temperature:       getEnvFloat("TEMPERATURE", 0.7),
			SystemPrompt:      getEnvString("SYSTEM_PROMPT", ""),
			EnableAutoSearch:  getEnvBool("ENABLE_AUTO_SEARCH", true),
		},
		Voice: &VoiceConfig{
			UseWhisperCpp:     getEnvBool("USE_WHISPER_CPP", true),
			WhisperCppPath:    getEnvString("WHISPER_CPP_PATH", "./work/repos/whisper.cpp/build/bin/whisper-cli"),
			WhisperModelPath:  getEnvString("WHISPER_CPP_MODEL", "./work/repos/whisper.cpp/models/ggml-small.bin"),
			SampleRate:        getEnvInt("SAMPLE_RATE", 22050),
			Channels:          getEnvInt("CHANNELS", 1),
			ChunkSize:         getEnvInt("CHUNK_SIZE", 2048),
		},
		TTS: &TTSConfig{
			Enabled:    !getEnvBool("TTS_DISABLED", false),
			Rate:       getEnvInt("TTS_RATE", 160),
			Volume:     getEnvFloat("TTS_VOLUME", 0.9),
			VoiceID:    getEnvString("TTS_VOICE_ID", ""),
		},
	}

	return config, nil
}

// loadEnvFile loads environment variables from a .env file
func loadEnvFile(filename string) error {
	file, err := os.Open(filename)
	if os.IsNotExist(err) {
		// .env file is optional
		return nil
	}
	if err != nil {
		return fmt.Errorf("error opening %s: %w", filename, err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	lineNum := 0

	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())

		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Parse key=value pairs
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			return fmt.Errorf("invalid format in %s at line %d: %s", filename, lineNum, line)
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Remove quotes if present
		if len(value) >= 2 {
			if (strings.HasPrefix(value, `"`) && strings.HasSuffix(value, `"`)) ||
			   (strings.HasPrefix(value, `'`) && strings.HasSuffix(value, `'`)) {
				value = value[1 : len(value)-1]
			}
		}

		// Set environment variable if not already set
		if os.Getenv(key) == "" {
			os.Setenv(key, value)
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading %s: %w", filename, err)
	}

	return nil
}

// Helper functions for environment variable parsing

func getEnvString(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatValue, err := strconv.ParseFloat(value, 64); err == nil {
			return floatValue
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		switch strings.ToLower(value) {
		case "true", "1", "yes", "on":
			return true
		case "false", "0", "no", "off":
			return false
		}
	}
	return defaultValue
}