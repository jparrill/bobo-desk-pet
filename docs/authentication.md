# Google Cloud Authentication Setup

## 1. Install gcloud CLI

### Linux/macOS
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Using Package Managers
```bash
# macOS
brew install google-cloud-sdk

# Ubuntu
sudo apt-get install google-cloud-sdk
```

## 2. Authenticate

```bash
# Login and set up Application Default Credentials
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable aiplatform.googleapis.com
```

## 3. Test Authentication

```bash
# Using Make
make test-auth

# Or manually
gcloud auth application-default print-access-token
```

## 4. Project Setup

1. **Create or select a Google Cloud project**
2. **Enable the Vertex AI API**:
   ```bash
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   ```

3. **Set up IAM permissions**:
   Your account needs these roles:
   - AI Platform User
   - Vertex AI User

## Troubleshooting Authentication

### "gcloud auth errors"
```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### "Vertex AI permission denied"
- Verify project ID in .env
- Check IAM roles in GCP Console
- Ensure Vertex AI API is enabled

### Test authentication manually
```bash
gcloud auth application-default print-access-token
```

If this works, authentication is correctly configured.