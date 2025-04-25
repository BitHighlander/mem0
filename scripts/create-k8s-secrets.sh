#!/bin/bash

# This script creates the Kubernetes secrets for Mem0

set -e  # Exit on any error

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Check if required environment variables are set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "OPENAI_API_KEY environment variable is not set."
    echo "Please set it with: export OPENAI_API_KEY=your_openai_api_key"
    exit 1
fi

# Generate a random API key if not provided
if [ -z "$API_KEY" ]; then
    API_KEY=$(openssl rand -hex 16)
    echo "Generated random API_KEY: $API_KEY"
    echo "Please save this key for future reference."
fi

# Create base64 encoded values
OPENAI_API_KEY_BASE64=$(echo -n "$OPENAI_API_KEY" | base64)
API_KEY_BASE64=$(echo -n "$API_KEY" | base64)

# Apply the secret to Kubernetes
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mem0-secrets
type: Opaque
data:
  openai-api-key: $OPENAI_API_KEY_BASE64
  api-key: $API_KEY_BASE64
EOF

echo "Kubernetes secrets created successfully."
echo "To use these secrets in your deployment, reference them in your pod spec:"
echo
echo "env:"
echo "- name: OPENAI_API_KEY"
echo "  valueFrom:"
echo "    secretKeyRef:"
echo "      name: mem0-secrets"
echo "      key: openai-api-key"
echo "- name: API_KEY"
echo "  valueFrom:"
echo "    secretKeyRef:"
echo "      name: mem0-secrets"
echo "      key: api-key"
