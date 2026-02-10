package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/jparrill/bobo-desk-pet/pkg/config"
	"github.com/jparrill/bobo-desk-pet/pkg/voice"
)

const version = "1.0.0"

func main() {
	var (
		configFile = flag.String("config", ".env", "Configuration file path")
		verbose    = flag.Bool("v", false, "Enable verbose logging")
		showVersion = flag.Bool("version", false, "Show version and exit")
	)
	flag.Parse()

	if *showVersion {
		fmt.Printf("Bobo v%s - Your AI Voice Assistant\n", version)
		os.Exit(0)
	}

	// Setup logging
	logLevel := slog.LevelInfo
	if *verbose {
		logLevel = slog.LevelDebug
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: logLevel,
	}))
	slog.SetDefault(logger)

	// Load configuration
	cfg, err := config.Load(*configFile)
	if err != nil {
		slog.Error("Failed to load configuration", "error", err)
		os.Exit(1)
	}

	slog.Info("🤖 Bobo - Your AI Voice Assistant", "version", version)
	slog.Info("Configuration loaded",
		"project", cfg.VertexAI.ProjectID,
		"model", cfg.VertexAI.Model,
		"use_whisper_cpp", cfg.Voice.UseWhisperCpp,
	)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Setup signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Initialize voice interface
	voiceInterface, err := voice.New(cfg)
	if err != nil {
		slog.Error("Failed to initialize voice interface", "error", err)
		os.Exit(1)
	}

	// Initialize the voice interface
	if err := voiceInterface.Initialize(ctx); err != nil {
		slog.Error("Failed to initialize voice interface", "error", err)
		os.Exit(1)
	}

	// Start the main interaction loop in a goroutine
	go func() {
		if err := voiceInterface.Run(ctx); err != nil {
			slog.Error("Voice interface error", "error", err)
		}
		// Always cancel context when Run() exits (error or quit)
		cancel()
	}()

	// Wait for shutdown signal
	select {
	case sig := <-sigChan:
		slog.Info("Received shutdown signal", "signal", sig)
	case <-ctx.Done():
		slog.Info("Context cancelled")
	}

	slog.Info("👋 Shutting down...")

	// Shutdown voice interface
	if err := voiceInterface.Shutdown(); err != nil {
		slog.Error("Error during shutdown", "error", err)
	}

	slog.Info("✅ Shutdown complete")
}