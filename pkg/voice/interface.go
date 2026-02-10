// Package voice provides voice recognition and text-to-speech functionality
// This is the Go port of voice_interface.py
package voice

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/chzyer/readline"
	"github.com/jparrill/bobo-desk-pet/pkg/claude"
	"github.com/jparrill/bobo-desk-pet/pkg/config"
)

// Interface represents the main voice interface
type Interface struct {
	config       *config.Config
	claudeClient *claude.SmartClient
	recorder     *AudioRecorder
	transcriber  Transcriber
	tts          TextToSpeech
	logger       *slog.Logger
	rl           *readline.Instance
}

// New creates a new voice interface
func New(cfg *config.Config) (*Interface, error) {
	return &Interface{
		config: cfg,
		logger: slog.Default(),
	}, nil
}

// Initialize initializes all voice interface components
func (v *Interface) Initialize(ctx context.Context) error {
	v.logger.Info("🔄 Initializing voice interface...")

	// Initialize speech recognition
	var err error
	if v.config.Voice.UseWhisperCpp {
		v.logger.Info("🔄 Setting up whisper.cpp (fast & lightweight)...")
		v.transcriber, err = NewWhisperCppTranscriber(v.config.Voice)
		if err != nil {
			return fmt.Errorf("failed to initialize whisper.cpp: %w", err)
		}
		v.logger.Info("✅ whisper.cpp ready")
	} else {
		// TODO: Implement Python Whisper fallback
		return fmt.Errorf("Python Whisper not implemented yet, use whisper.cpp")
	}

	// Initialize Claude client
	v.logger.Info("🔄 Connecting to Claude...")
	v.claudeClient = claude.NewSmartClient(v.config.VertexAI)
	if err := v.claudeClient.Initialize(ctx); err != nil {
		return fmt.Errorf("failed to initialize Claude client: %w", err)
	}
	v.logger.Info("✅ Claude connected")

	// Initialize audio recorder
	v.logger.Info("🔄 Setting up audio recorder...")
	v.recorder, err = NewAudioRecorder(v.config.Voice)
	if err != nil {
		return fmt.Errorf("failed to initialize audio recorder: %w", err)
	}
	v.logger.Info("✅ Audio recorder ready")

	// Initialize TTS
	if v.config.TTS.Enabled {
		v.logger.Info("🔄 Setting up text-to-speech...")
		v.tts, err = NewTextToSpeech(v.config.TTS)
		if err != nil {
			v.logger.Warn("Failed to initialize TTS", "error", err)
			v.config.TTS.Enabled = false
		} else {
			v.logger.Info("✅ TTS ready")
		}
	}

	// Initialize readline for proper terminal input handling
	v.rl, err = readline.New("🎤 Command (r/l/t/x/s/q): ")
	if err != nil {
		return fmt.Errorf("failed to initialize readline: %w", err)
	}

	v.logger.Info("🎉 Voice interface ready!")
	return nil
}

// Run starts the main interaction loop
func (v *Interface) Run(ctx context.Context) error {
	v.logger.Info("🎯 Commands:")
	v.logger.Info("  • 'r' + ENTER: Record and process voice (7 seconds)")
	v.logger.Info("  • 'l' + ENTER: Long recording (12 seconds)")
	v.logger.Info("  • 't' + ENTER: Test microphone levels")
	v.logger.Info("  • 'x' + ENTER: Test TTS voice")
	v.logger.Info("  • 's' + ENTER: Toggle speech", "currently", map[bool]string{true: "ON", false: "OFF"}[v.config.TTS.Enabled])
	v.logger.Info("  • 'q' + ENTER: Quit")

	statusMsg := "Disabled"
	if v.config.TTS.Enabled {
		statusMsg = "Enabled"
	}
	v.logger.Info("🔊 TTS", "status", statusMsg)

	recognition := "Python Whisper"
	if v.config.Voice.UseWhisperCpp {
		recognition = "whisper.cpp"
	}
	v.logger.Info("🎤 Speech Recognition", "engine", recognition)

	// Create context that cancels on interrupt
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// Handle interrupt signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		v.logger.Info("👋 Interrupt signal received")
		cancel()
	}()

	// Note: Using readline for proper terminal input handling

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			// Read command using readline (PROPER terminal handling)
			line, err := v.rl.Readline()
			if err != nil {
				if err == readline.ErrInterrupt {
					v.logger.Info("👋 Interrupt received")
					return nil
				}
				if err == io.EOF {
					v.logger.Info("👋 EOF received")
					return nil
				}
				return fmt.Errorf("error reading input: %w", err)
			}

			// Clean and validate command
			command := strings.TrimSpace(strings.ToLower(line))

			switch command {
			case "r":
				if err := v.processVoiceCommand(ctx, 7); err != nil {
					v.logger.Error("Voice command failed", "error", err)
				}

			case "l":
				v.logger.Info("🎤 Long recording mode...")
				if err := v.processVoiceCommand(ctx, 12); err != nil {
					v.logger.Error("Long voice command failed", "error", err)
				}

			case "t":
				v.logger.Info("🎤 Testing microphone...")
				if err := v.testMicrophone(ctx, 3); err != nil {
					v.logger.Error("Microphone test failed", "error", err)
				}

			case "x":
				v.logger.Info("🔊 Testing TTS...")
				if err := v.testTTS(ctx); err != nil {
					v.logger.Error("TTS test failed", "error", err)
				}

			case "s":
				v.config.TTS.Enabled = !v.config.TTS.Enabled
				status := map[bool]string{true: "ON", false: "OFF"}[v.config.TTS.Enabled]
				v.logger.Info("🔊 TTS toggled", "status", status)

			case "q":
				v.logger.Info("👋 Goodbye!")
				return nil

			case "":
				continue

			default:
				v.logger.Warn("❓ Unknown command", "command", command, "available", "r/l/t/x/s/q")
			}
		}
	}
}

// processVoiceCommand handles voice recording, transcription, and Claude interaction
func (v *Interface) processVoiceCommand(ctx context.Context, durationSeconds int) error {
	// Record audio
	success, err := v.recorder.RecordAudio(ctx, durationSeconds)
	if err != nil {
		return fmt.Errorf("recording failed: %w", err)
	}
	if !success {
		v.logger.Warn("Recording was not successful")
		return nil
	}

	// Process the recorded audio
	return v.processAudio(ctx)
}

// processAudio transcribes audio and gets Claude's response
func (v *Interface) processAudio(ctx context.Context) error {
	if v.recorder.AudioFilePath == "" {
		return fmt.Errorf("no audio file to process")
	}

	v.logger.Info("🔄 Processing audio...")

	// Transcribe audio
	v.logger.Info("🔄 Transcribing...")
	transcription, err := v.transcriber.Transcribe(ctx, v.recorder.AudioFilePath, "es")
	if err != nil {
		return fmt.Errorf("transcription failed: %w", err)
	}

	transcription = strings.TrimSpace(transcription)
	if transcription == "" {
		v.logger.Warn("❌ No speech detected")
		return nil
	}

	v.logger.Info("👤 You said", "transcription", transcription)

	// Send to Claude
	v.logger.Info("🤖 Claude is thinking...")
	messages := []claude.Message{
		{Role: "user", Content: transcription},
	}

	response, err := v.claudeClient.SendMessage(ctx, messages)
	if err != nil {
		return fmt.Errorf("Claude request failed: %w", err)
	}

	if response == "" {
		v.logger.Warn("❌ Claude didn't respond")
		return nil
	}

	v.logger.Info("🎯 Claude", "response", response)

	// Speak response if TTS is enabled
	if v.config.TTS.Enabled && v.tts != nil {
		if err := v.tts.Speak(ctx, response); err != nil {
			v.logger.Warn("TTS failed", "error", err)
		}
	}

	return nil
}

// testMicrophone tests microphone recording
func (v *Interface) testMicrophone(ctx context.Context, durationSeconds int) error {
	_, err := v.recorder.RecordAudio(ctx, durationSeconds)
	if err != nil {
		return err
	}
	v.logger.Info("✅ Microphone test complete!")
	return nil
}

// testTTS tests text-to-speech
func (v *Interface) testTTS(ctx context.Context) error {
	if !v.config.TTS.Enabled || v.tts == nil {
		v.logger.Info("⚠️ TTS is disabled or not available")
		return nil
	}

	testText := "Hello, this is a voice test. Everything is working correctly."
	if err := v.tts.Speak(ctx, testText); err != nil {
		return fmt.Errorf("TTS test failed: %w", err)
	}

	v.logger.Info("✅ TTS test complete!")
	return nil
}

// Shutdown cleans up resources
func (v *Interface) Shutdown() error {
	v.logger.Info("Shutting down voice interface")

	var errs []error

	if v.rl != nil {
		if err := v.rl.Close(); err != nil {
			errs = append(errs, fmt.Errorf("readline shutdown: %w", err))
		}
	}

	if v.claudeClient != nil {
		if err := v.claudeClient.Shutdown(); err != nil {
			errs = append(errs, fmt.Errorf("Claude client shutdown: %w", err))
		}
	}

	if v.recorder != nil {
		if err := v.recorder.Cleanup(); err != nil {
			errs = append(errs, fmt.Errorf("recorder cleanup: %w", err))
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("shutdown errors: %v", errs)
	}

	return nil
}

