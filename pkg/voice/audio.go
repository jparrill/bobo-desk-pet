// Package voice provides audio recording functionality
package voice

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/jparrill/bobo-desk-pet/pkg/config"
)

// AudioRecorder interface for audio recording
type AudioRecorder struct {
	config        *config.VoiceConfig
	AudioFilePath string
	logger        *slog.Logger
}

// NewAudioRecorder creates a new audio recorder
func NewAudioRecorder(cfg *config.VoiceConfig) (*AudioRecorder, error) {
	return &AudioRecorder{
		config: cfg,
		logger: slog.Default(),
	}, nil
}

// RecordAudio records audio for the specified duration using ffmpeg
func (a *AudioRecorder) RecordAudio(ctx context.Context, durationSeconds int) (bool, error) {
	a.logger.Info("🎤 Recording audio with ffmpeg",
		"duration", durationSeconds,
		"sample_rate", a.config.SampleRate,
		"channels", a.config.Channels,
	)

	// Create audio file in work/temp directory with ABSOLUTE path
	workTempDir := "work/temp"
	if err := os.MkdirAll(workTempDir, 0755); err != nil {
		// Fallback to system temp if work dir fails
		workTempDir = os.TempDir()
	}

	// Make path absolute
	absWorkDir, err := filepath.Abs(workTempDir)
	if err != nil {
		a.logger.Warn("Failed to get absolute path, using relative", "error", err)
		absWorkDir = workTempDir
	}

	timestamp := time.Now().Format("20060102_150405")
	a.AudioFilePath = filepath.Join(absWorkDir, fmt.Sprintf("desk_pet_recording_%s.wav", timestamp))

	// Start recording in background
	recordingDone := make(chan error, 1)
	go func() {
		recordingDone <- a.recordWithFFmpeg(ctx, durationSeconds)
	}()

	// Show progress while recording
	progressTicker := time.NewTicker(1 * time.Second)
	defer progressTicker.Stop()

	startTime := time.Now()
	for {
		select {
		case err := <-recordingDone:
			a.logger.Info("⏹️ Recording complete", "file", a.AudioFilePath)
			if err != nil {
				return false, fmt.Errorf("recording failed: %w", err)
			}
			a.logger.Info("✅ Audio recording successful (real audio)")
			return true, nil

		case <-progressTicker.C:
			elapsed := time.Since(startTime).Seconds()
			progress := (elapsed / float64(durationSeconds)) * 100
			if progress <= 100 {
				a.logger.Info("🔴 Recording progress", "progress", fmt.Sprintf("%.0f%%", progress))
			}

		case <-ctx.Done():
			return false, ctx.Err()
		}
	}
}

// recordWithFFmpeg performs actual audio recording using ffmpeg
func (a *AudioRecorder) recordWithFFmpeg(ctx context.Context, durationSeconds int) error {
	// Create context with timeout slightly longer than recording duration
	recordCtx, cancel := context.WithTimeout(ctx, time.Duration(durationSeconds+2)*time.Second)
	defer cancel()

	// Build ffmpeg command based on platform
	args := a.buildFFmpegArgs(durationSeconds)
	if args == nil {
		return fmt.Errorf("unsupported platform for audio recording")
	}

	// Execute ffmpeg command
	cmd := exec.CommandContext(recordCtx, "ffmpeg", args...)

	// Capture stderr for debugging
	var stderr strings.Builder
	cmd.Stderr = &stderr

	a.logger.Info("🎙️ Starting ffmpeg recording", "command", "ffmpeg "+strings.Join(args, " "))

	if err := cmd.Run(); err != nil {
		stderrOutput := stderr.String()
		if stderrOutput != "" {
			a.logger.Warn("ffmpeg stderr output", "output", stderrOutput)
		}
		return fmt.Errorf("ffmpeg recording failed: %w", err)
	}

	// Verify file was created
	if _, err := os.Stat(a.AudioFilePath); os.IsNotExist(err) {
		return fmt.Errorf("audio file was not created: %s", a.AudioFilePath)
	}

	return nil
}

// buildFFmpegArgs builds platform-specific ffmpeg arguments for audio recording
func (a *AudioRecorder) buildFFmpegArgs(durationSeconds int) []string {
	platform := a.detectPlatform()
	a.logger.Info("🔍 Detecting audio recording setup", "platform", platform)

	// Common arguments
	args := []string{
		"-y", // Overwrite output files
		"-t", strconv.Itoa(durationSeconds), // Duration
		"-ac", strconv.Itoa(a.config.Channels), // Audio channels
		"-ar", strconv.Itoa(a.config.SampleRate), // Sample rate
	}

	// Platform-specific input arguments
	switch platform {
	case "darwin": // macOS
		a.logger.Info("🍎 Using macOS avfoundation audio input")
		args = append(args,
			"-f", "avfoundation",
			"-i", ":0", // Default audio input device
		)
	case "linux": // Linux
		if a.isAudioSystemAvailable("pulse") {
			a.logger.Info("🔊 Using PulseAudio input")
			args = append(args,
				"-f", "pulse",
				"-i", "default", // Default PulseAudio source
			)
		} else if a.isAudioSystemAvailable("alsa") {
			a.logger.Info("🔉 Using ALSA audio input")
			args = append(args,
				"-f", "alsa",
				"-i", "hw:0", // Hardware device 0
			)
		} else {
			a.logger.Warn("❌ No supported audio system found (pulse/alsa)")
			return nil
		}
	default:
		a.logger.Warn("Unsupported platform for audio recording")
		return nil
	}

	// Output arguments
	args = append(args, a.AudioFilePath)

	return args
}

// detectPlatform detects the current operating system
func (a *AudioRecorder) detectPlatform() string {
	cmd := exec.Command("uname", "-s")
	output, err := cmd.Output()
	if err != nil {
		a.logger.Warn("Failed to detect platform", "error", err)
		return "unknown"
	}
	return strings.ToLower(strings.TrimSpace(string(output)))
}

// isAudioSystemAvailable checks if a specific audio system is available
func (a *AudioRecorder) isAudioSystemAvailable(system string) bool {
	switch system {
	case "pulse":
		// Check if PulseAudio is running
		cmd := exec.Command("pulseaudio", "--check")
		return cmd.Run() == nil
	case "alsa":
		// Check if ALSA devices exist
		_, err := os.Stat("/proc/asound/devices")
		return err == nil
	default:
		return false
	}
}

// createDummyAudioFile creates a dummy audio file for testing purposes
func (a *AudioRecorder) createDummyAudioFile() error {
	// Create a minimal WAV file header for testing
	// This is just for testing - real implementation would have actual audio data
	file, err := os.Create(a.AudioFilePath)
	if err != nil {
		return err
	}
	defer file.Close()

	// Write minimal WAV header (44 bytes) + some dummy data
	wavHeader := []byte{
		// RIFF header
		'R', 'I', 'F', 'F',
		0x24, 0x08, 0x00, 0x00, // File size - 8
		'W', 'A', 'V', 'E',

		// fmt chunk
		'f', 'm', 't', ' ',
		0x10, 0x00, 0x00, 0x00, // Subchunk1Size (16 for PCM)
		0x01, 0x00,             // AudioFormat (1 for PCM)
		0x01, 0x00,             // NumChannels (1)
		0x22, 0x56, 0x00, 0x00, // SampleRate (22050)
		0x44, 0xAC, 0x00, 0x00, // ByteRate
		0x02, 0x00,             // BlockAlign
		0x10, 0x00,             // BitsPerSample (16)

		// data chunk
		'd', 'a', 't', 'a',
		0x00, 0x08, 0x00, 0x00, // Subchunk2Size
	}

	if _, err := file.Write(wavHeader); err != nil {
		return err
	}

	// Write some dummy audio data (silence)
	dummyData := make([]byte, 2048)
	if _, err := file.Write(dummyData); err != nil {
		return err
	}

	return nil
}

// Cleanup removes temporary audio files
func (a *AudioRecorder) Cleanup() error {
	if a.AudioFilePath != "" && strings.Contains(a.AudioFilePath, "desk_pet_recording_") {
		if err := os.Remove(a.AudioFilePath); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove audio file: %w", err)
		}
		a.AudioFilePath = ""
	}
	return nil
}

// TODO: Implement real audio recording with:
// 1. PortAudio Go bindings (https://github.com/gordonklaus/portaudio)
// 2. Or system-specific APIs (ALSA on Linux, Core Audio on macOS)
// 3. Real-time audio level monitoring
// 4. Proper WAV file generation with actual audio data
//
// Example with PortAudio (when dependencies are added):
/*
import "github.com/gordonklaus/portaudio"

func (a *AudioRecorder) recordWithPortAudio(ctx context.Context, duration int) error {
	portaudio.Initialize()
	defer portaudio.Terminate()

	// Configure audio parameters
	inputParameters := portaudio.LowLatencyParameters(nil, &portaudio.DeviceInfo{
		MaxInputChannels: a.config.Channels,
	})

	// Create audio stream
	stream, err := portaudio.OpenStream(inputParameters, func(in []float32) {
		// Process audio data
		// Convert to int16 and write to buffer
	})
	if err != nil {
		return err
	}
	defer stream.Close()

	// Start recording
	if err := stream.Start(); err != nil {
		return err
	}

	// Record for specified duration
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(time.Duration(duration) * time.Second):
	}

	return stream.Stop()
}
*/