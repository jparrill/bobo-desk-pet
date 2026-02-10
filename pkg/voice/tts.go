// Package voice provides text-to-speech functionality
package voice

import (
	"context"
	"fmt"
	"log/slog"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/jparrill/bobo-desk-pet/pkg/config"
)

// TextToSpeech interface for text-to-speech conversion
type TextToSpeech interface {
	Speak(ctx context.Context, text string) error
}

// SystemTTS implements TTS using system commands (espeak, say, etc.)
type SystemTTS struct {
	config  *config.TTSConfig
	command string
	args    []string
	logger  *slog.Logger
}

// NewTextToSpeech creates a new text-to-speech engine
func NewTextToSpeech(cfg *config.TTSConfig) (TextToSpeech, error) {
	tts := &SystemTTS{
		config: cfg,
		logger: slog.Default(),
	}

	// Detect available TTS system
	if err := tts.detectTTSSystem(); err != nil {
		return nil, fmt.Errorf("no TTS system found: %w", err)
	}

	return tts, nil
}

// detectTTSSystem detects available TTS system on the platform
func (s *SystemTTS) detectTTSSystem() error {
	// Try different TTS systems in order of preference
	systems := []struct {
		command string
		args    []string
		test    []string
	}{
		{
			// espeak-ng (Linux - preferred)
			command: "espeak-ng",
			args:    []string{"-v", "es", "-s", fmt.Sprintf("%d", s.config.Rate)},
			test:    []string{"--help"},
		},
		{
			// espeak (Linux - fallback)
			command: "espeak",
			args:    []string{"-v", "es", "-s", fmt.Sprintf("%d", s.config.Rate)},
			test:    []string{"--help"},
		},
		{
			// festival (Linux - alternative)
			command: "festival",
			args:    []string{"--tts"},
			test:    []string{"--help"},
		},
	}

	var triedCommands []string

	for _, system := range systems {
		triedCommands = append(triedCommands, system.command)
		if s.testCommand(system.command, system.test) {
			s.command = system.command
			s.args = system.args
			s.logger.Info("🔊 TTS system detected", "command", system.command)
			return nil
		}
	}

	return fmt.Errorf("no supported TTS system found (tried: %s)", strings.Join(triedCommands, ", "))
}

// testCommand tests if a command is available
func (s *SystemTTS) testCommand(command string, args []string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, command, args...)
	err := cmd.Run()
	return err == nil
}

// Speak converts text to speech
func (s *SystemTTS) Speak(ctx context.Context, text string) error {
	if text == "" {
		return nil
	}

	s.logger.Info("🔊 Speaking response...")

	// Clean text for speech
	cleanText := s.cleanTextForSpeech(text)
	if cleanText == "" {
		s.logger.Warn("⚠️ No speakable text after cleaning")
		return nil
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// Build command
	args := make([]string, len(s.args))
	copy(args, s.args)
	args = append(args, cleanText)

	cmd := exec.CommandContext(ctx, s.command, args...)

	// Execute TTS
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("TTS command failed: %w", err)
	}

	s.logger.Info("✅ TTS completed")
	return nil
}

// cleanTextForSpeech cleans text for speech synthesis
func (s *SystemTTS) cleanTextForSpeech(text string) string {
	// Remove emojis and special characters (keep accented characters)
	emojiRegex := regexp.MustCompile(`[^\w\s\.\,\!\?\:\;\-\(\)\'\"áéíóúñÁÉÍÓÚÑüÜ]`)
	cleanText := emojiRegex.ReplaceAllString(text, " ")

	// Remove markdown formatting
	markdownPatterns := []*regexp.Regexp{
		regexp.MustCompile(`\*+`),     // Bold/italic asterisks
		regexp.MustCompile(`#+`),      // Headers
		regexp.MustCompile("`+"),      // Code blocks
		regexp.MustCompile(`_+`),      // Underscores
	}

	for _, pattern := range markdownPatterns {
		cleanText = pattern.ReplaceAllString(cleanText, "")
	}

	// Replace newlines with periods
	cleanText = regexp.MustCompile(`\n+`).ReplaceAllString(cleanText, ". ")

	// Clean up spaces and punctuation
	cleanText = regexp.MustCompile(`\s+`).ReplaceAllString(cleanText, " ")
	cleanText = regexp.MustCompile(`[\.]{2,}`).ReplaceAllString(cleanText, ".")

	return strings.TrimSpace(cleanText)
}

// TODO: Implement more advanced TTS with:
// 1. pyttsx3 Go bindings or similar
// 2. Cloud TTS APIs (Google Cloud TTS, Azure Speech, etc.)
// 3. Neural TTS models
// 4. Voice selection and customization
//
// Example with Google Cloud TTS (when dependencies are added):
/*
import "cloud.google.com/go/texttospeech/apiv1"

type CloudTTS struct {
	client *texttospeech.Client
	config *config.TTSConfig
}

func (c *CloudTTS) Speak(ctx context.Context, text string) error {
	req := &texttospeechpb.SynthesizeSpeechRequest{
		Input: &texttospeechpb.SynthesisInput{
			InputSource: &texttospeechpb.SynthesisInput_Text{
				Text: text,
			},
		},
		Voice: &texttospeechpb.VoiceSelectionParams{
			LanguageCode: "es-ES",
			Name:         "es-ES-Wavenet-B",
		},
		AudioConfig: &texttospeechpb.AudioConfig{
			AudioEncoding: texttospeechpb.AudioEncoding_MP3,
			SpeakingRate:  float64(c.config.Rate) / 160.0,
		},
	}

	resp, err := c.client.SynthesizeSpeech(ctx, req)
	if err != nil {
		return err
	}

	// Play the audio (would need audio playback library)
	return playAudio(resp.AudioContent)
}
*/