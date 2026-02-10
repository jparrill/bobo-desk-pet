// Package voice provides transcription interfaces and implementations
package voice

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/jparrill/bobo-desk-pet/pkg/config"
)

// Transcriber interface for speech-to-text conversion
type Transcriber interface {
	Transcribe(ctx context.Context, audioFilePath, language string) (string, error)
}

// WhisperCppTranscriber implements transcription using whisper.cpp
type WhisperCppTranscriber struct {
	config         *config.VoiceConfig
	whisperCppPath string
	modelPath      string
}

// NewWhisperCppTranscriber creates a new whisper.cpp transcriber
func NewWhisperCppTranscriber(cfg *config.VoiceConfig) (*WhisperCppTranscriber, error) {
	transcriber := &WhisperCppTranscriber{
		config:    cfg,
		modelPath: cfg.WhisperModelPath,
	}

	// Find whisper.cpp binary
	if err := transcriber.findWhisperCpp(); err != nil {
		return nil, fmt.Errorf("whisper.cpp not found: %w", err)
	}

	return transcriber, nil
}

// findWhisperCpp locates the whisper.cpp binary
func (w *WhisperCppTranscriber) findWhisperCpp() error {
	// Try environment path first
	if w.config.WhisperCppPath != "" {
		if _, err := os.Stat(w.config.WhisperCppPath); err == nil {
			// Test if it's executable
			if err := w.testWhisperCpp(w.config.WhisperCppPath); err == nil {
				w.whisperCppPath = w.config.WhisperCppPath
				fmt.Printf("✅ Found whisper.cpp at: %s\n", w.whisperCppPath)
				return nil
			}
		}
	}

	// Search common locations
	searchPaths := []string{
		"./work/repos/whisper.cpp/build/bin/whisper-cli", // Preferred CLI binary (work dir)
		"./work/repos/whisper.cpp/build/bin/main",        // Legacy binary (work dir)
		"./whisper.cpp/build/bin/whisper-cli",            // Fallback: old location
		"./whisper.cpp/build/bin/main",                   // Fallback: old location
		"/usr/local/bin/whisper-cli",
		"/usr/local/bin/whisper",
		"whisper-cli",
		"whisper",
	}

	for _, path := range searchPaths {
		if err := w.testWhisperCpp(path); err == nil {
			w.whisperCppPath = path
			fmt.Printf("✅ Found whisper.cpp at: %s\n", path)
			return nil
		}
	}

	return fmt.Errorf("whisper.cpp binary not found. Run: bash scripts/setup_whisper_cpp.sh")
}

// testWhisperCpp tests if a whisper.cpp binary is working
func (w *WhisperCppTranscriber) testWhisperCpp(path string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, path, "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return err
	}

	outputStr := string(output)
	if strings.Contains(outputStr, "language LANG") || cmd.ProcessState.Success() {
		return nil
	}

	return fmt.Errorf("whisper.cpp test failed")
}

// Transcribe transcribes audio using whisper.cpp
func (w *WhisperCppTranscriber) Transcribe(ctx context.Context, audioFilePath, language string) (string, error) {
	if w.whisperCppPath == "" {
		return "", fmt.Errorf("whisper.cpp not initialized")
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// Make audio file path absolute
	absAudioPath, err := filepath.Abs(audioFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to get absolute path for audio file: %w", err)
	}

	// Check if file exists
	if _, err := os.Stat(absAudioPath); os.IsNotExist(err) {
		return "", fmt.Errorf("audio file does not exist: %s", absAudioPath)
	}

	// Build command arguments
	args := []string{
		"--language", language,
		"--threads", "4",
		"--file", absAudioPath,  // Use absolute path
		"--output-txt",
		"--no-timestamps",
		"--no-prints",
		"-m", w.modelPath,
	}

	// Execute whisper.cpp
	cmd := exec.CommandContext(ctx, w.whisperCppPath, args...)

	// Set working directory to whisper.cpp directory if needed
	if strings.Contains(w.whisperCppPath, "/") {
		cmd.Dir = filepath.Dir(w.whisperCppPath)
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("whisper.cpp failed: %w, output: %s", err, string(output))
	}

	// Parse output from stdout
	transcription := ""
	if len(output) > 0 {
		transcription = w.parseWhisperOutput(string(output))
	}

	// Fallback: check for .txt output file
	if transcription == "" {
		// whisper.cpp generates filename.wav.txt, not filename.txt
		txtFile := absAudioPath + ".txt"
		if data, err := os.ReadFile(txtFile); err == nil {
			transcription = string(data)
			// Clean up the txt file
			os.Remove(txtFile)
		}
	}

	return w.cleanTranscription(transcription), nil
}

// parseWhisperOutput parses whisper.cpp stdout output
func (w *WhisperCppTranscriber) parseWhisperOutput(output string) string {
	lines := strings.Split(strings.TrimSpace(output), "\n")
	var textLines []string

	for _, line := range lines {
		line = strings.TrimSpace(line)
		// Skip empty lines, timestamp lines, and whisper.cpp debug messages
		if line != "" && !w.isTimestampLine(line) && !w.isDebugLine(line) {
			textLines = append(textLines, line)
		}
	}

	return strings.Join(textLines, " ")
}

// isTimestampLine checks if a line contains timestamps
func (w *WhisperCppTranscriber) isTimestampLine(line string) bool {
	// Check for patterns like [00:00:00.000 --> 00:00:05.000]
	timestampPattern := regexp.MustCompile(`^\s*\[.*-->\s*.*\]\s*$`)
	return timestampPattern.MatchString(line)
}

// isDebugLine checks if a line is a whisper.cpp debug/status message
func (w *WhisperCppTranscriber) isDebugLine(line string) bool {
	debugPatterns := []string{
		"output_txt: saving output to",
		"output_vtt: saving output to",
		"output_srt: saving output to",
		"whisper_print_timings:",
		"load time =",
		"fallbacks =",
		"main:",
	}

	lineLower := strings.ToLower(line)
	for _, pattern := range debugPatterns {
		if strings.Contains(lineLower, pattern) {
			return true
		}
	}

	return false
}

// cleanTranscription cleans up whisper.cpp output
func (w *WhisperCppTranscriber) cleanTranscription(text string) string {
	// Remove common artifacts
	text = strings.ReplaceAll(text, "[BLANK_AUDIO]", "")
	text = strings.ReplaceAll(text, "(silence)", "")
	text = strings.ReplaceAll(text, "(music)", "")
	text = strings.ReplaceAll(text, "[música]", "")
	text = strings.ReplaceAll(text, "[MÚSICA]", "")

	// Remove multiple spaces
	spaceRegex := regexp.MustCompile(`\s+`)
	text = spaceRegex.ReplaceAllString(text, " ")

	return strings.TrimSpace(text)
}