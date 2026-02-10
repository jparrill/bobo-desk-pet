// Package claude provides Claude AI client implementations
// This is the Go port of claude_vertex_client.py
package claude

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"

	"golang.org/x/oauth2/google"

	"github.com/jparrill/bobo-desk-pet/pkg/config"
)

// VertexClient represents a Claude client using Google Cloud Vertex AI
type VertexClient struct {
	config      *config.VertexAIConfig
	httpClient  *http.Client
	credentials *google.Credentials
	initialized bool
	mu          sync.RWMutex
	logger      *slog.Logger
}

// Message represents a conversation message
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// VertexRequest represents the request structure for Vertex AI
type VertexRequest struct {
	AnthropicVersion string    `json:"anthropic_version"`
	Messages         []Message `json:"messages"`
	MaxTokens        int       `json:"max_tokens"`
	Temperature      float64   `json:"temperature"`
	System           string    `json:"system,omitempty"`
}

// VertexResponse represents the response from Vertex AI
type VertexResponse struct {
	Content []ContentBlock `json:"content"`
	Usage   *Usage         `json:"usage,omitempty"`
}

// ContentBlock represents a content block in the response
type ContentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// Usage represents token usage information
type Usage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

// NewVertexClient creates a new Claude Vertex AI client
func NewVertexClient(cfg *config.VertexAIConfig) *VertexClient {
	return &VertexClient{
		config: cfg,
		logger: slog.Default(),
	}
}

// Initialize sets up the Vertex AI client and authenticates
func (c *VertexClient) Initialize(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.initialized {
		return nil
	}

	c.logger.Info("🔐 Initializing Vertex AI authentication...")

	// Check authentication status first
	if err := c.checkAuthentication(ctx); err != nil {
		c.logAuthenticationHelp()
		return fmt.Errorf("authentication check failed: %w", err)
	}

	// Get default credentials from gcloud auth
	credentials, err := google.FindDefaultCredentials(ctx)
	if err != nil {
		return fmt.Errorf("failed to find default credentials: %w", err)
	}

	c.credentials = credentials

	// Log credential information
	c.logCredentialInfo(credentials)

	// Use project from credentials if not explicitly set
	if c.config.ProjectID == "" && credentials.ProjectID != "" {
		c.config.ProjectID = credentials.ProjectID
	}

	if c.config.ProjectID == "" {
		return fmt.Errorf("no project ID found. Please set ANTHROPIC_VERTEX_PROJECT_ID or run: gcloud config set project YOUR_PROJECT")
	}

	c.logger.Info("📋 Using project", "project", c.config.ProjectID)
	c.logger.Info("🌍 Using location", "location", c.config.Location)
	c.logger.Info("🤖 Using model", "model", c.config.Model)

	// Create HTTP client with credentials
	httpClient, err := google.DefaultClient(ctx, "https://www.googleapis.com/auth/cloud-platform")
	if err != nil {
		return fmt.Errorf("failed to create HTTP client: %w", err)
	}

	c.httpClient = httpClient
	c.initialized = true

	c.logger.Info("✅ Vertex AI client initialized successfully")
	return nil
}

// SendMessage sends messages to Claude via Vertex AI
func (c *VertexClient) SendMessage(ctx context.Context, messages []Message) (string, error) {
	c.mu.RLock()
	initialized := c.initialized
	c.mu.RUnlock()

	if !initialized {
		if err := c.Initialize(ctx); err != nil {
			return "", fmt.Errorf("failed to initialize client: %w", err)
		}
	}

	// Build the request
	request := VertexRequest{
		AnthropicVersion: "vertex-2023-10-16",
		Messages:         messages,
		MaxTokens:        c.config.MaxTokens,
		Temperature:      c.config.Temperature,
	}

	// Add system prompt if available
	if c.config.SystemPrompt != "" {
		request.System = c.config.SystemPrompt
	}

	// Marshal request to JSON
	requestBody, err := json.Marshal(request)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	// Build the URL
	url := fmt.Sprintf(
		"https://%s-aiplatform.googleapis.com/v1/projects/%s/locations/%s/publishers/anthropic/models/%s:streamRawPredict",
		c.config.Location,
		c.config.ProjectID,
		c.config.Location,
		c.config.Model,
	)

	c.logger.Debug("Making request to Vertex AI",
		"url", url,
		"request_size", len(requestBody),
	)

	// Create HTTP request
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(requestBody))
	if err != nil {
		return "", fmt.Errorf("failed to create HTTP request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	// Make the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	// Read response body
	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response body: %w", err)
	}

	c.logger.Debug("Received response",
		"status", resp.StatusCode,
		"response_size", len(responseBody),
	)

	// Check for HTTP errors
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API error %d: %s", resp.StatusCode, string(responseBody))
	}

	// Parse response
	var vertexResponse VertexResponse
	if err := json.Unmarshal(responseBody, &vertexResponse); err != nil {
		return "", fmt.Errorf("failed to parse response: %w", err)
	}

	// Extract text from response
	text := c.extractTextFromResponse(vertexResponse)
	if text == "" {
		return "", fmt.Errorf("no text found in response")
	}

	return text, nil
}

// extractTextFromResponse extracts text content from Vertex AI response
func (c *VertexClient) extractTextFromResponse(response VertexResponse) string {
	if len(response.Content) == 0 {
		return ""
	}

	// Find the first text content block
	for _, content := range response.Content {
		if content.Type == "text" && content.Text != "" {
			return content.Text
		}
	}

	return ""
}

// checkAuthentication checks if gcloud authentication is properly set up
func (c *VertexClient) checkAuthentication(ctx context.Context) error {
	// Check if gcloud is available and authenticated
	cmd := exec.CommandContext(ctx, "gcloud", "auth", "application-default", "print-access-token")
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("gcloud ADC not available: %w", err)
	}

	if strings.TrimSpace(string(output)) == "" {
		return fmt.Errorf("empty access token")
	}

	c.logger.Info("✅ gcloud Application Default Credentials available")
	return nil
}

// logCredentialInfo logs information about the credentials being used
func (c *VertexClient) logCredentialInfo(credentials *google.Credentials) {
	c.logger.Info("🔑 Credentials type", "type", fmt.Sprintf("%T", credentials))

	if credentials.ProjectID != "" {
		c.logger.Info("🏗️ Detected project", "project", credentials.ProjectID)
	}
}

// logAuthenticationHelp logs helpful authentication troubleshooting information
func (c *VertexClient) logAuthenticationHelp() {
	c.logger.Error("")
	c.logger.Error("🔧 Authentication Troubleshooting:")
	c.logger.Error("1. Run: gcloud auth application-default login")
	c.logger.Error("2. Run: gcloud config set project YOUR_PROJECT_ID")
	c.logger.Error("3. Ensure the project has Vertex AI API enabled")
	c.logger.Error("4. Ensure you have the necessary IAM permissions")
	c.logger.Error("")
}

// IsAvailable checks if the client is available and initialized
func (c *VertexClient) IsAvailable() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.initialized
}

// Shutdown cleans up resources
func (c *VertexClient) Shutdown() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.logger.Info("Shutting down Claude Vertex AI client")
	c.initialized = false
	return nil
}