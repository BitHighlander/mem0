# Mem0 with SQLite Deployment Guide

This guide explains how to deploy Mem0 with SQLite vector storage to DigitalOcean Kubernetes.

## Local Development

### Prerequisites
- Docker
- Node.js
- npm

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/BitHighlander/mem0.git
   cd mem0
   ```

2. Create a `.env` file with your OpenAI API key:
   ```
   OPENAI_API_KEY=your_openai_api_key
   API_KEY=your_custom_api_key_for_authentication
   ```

3. Start the local development environment:
   ```bash
   npm start
   ```

4. Access the API at http://localhost:8000 and the documentation at http://localhost:8000/docs

### Docker Commands

Build and run locally:
```bash
npm run docker:build
npm run docker:run
```

Push to DigitalOcean Container Registry:
```bash
npm run docker:push:all
```

## DigitalOcean Kubernetes Deployment

### Prerequisites
- DigitalOcean account with Kubernetes cluster
- `kubectl` configured to access your cluster
- DigitalOcean Container Registry access

### Deployment Steps

1. Create Kubernetes secrets:
   ```bash
   export OPENAI_API_KEY=your_openai_api_key
   export API_KEY=your_custom_api_key
   npm run k8s:create-secrets
   ```

2. Deploy to Kubernetes:
   ```bash
   npm run k8s:deploy
   ```

3. Check the deployment status:
   ```bash
   kubectl get pods
   kubectl get services
   ```

## GitHub Actions CI/CD

This repository includes GitHub Actions workflows for CI/CD:

1. Add the following secrets to your GitHub repository:
   - `DIGITALOCEAN_ACCESS_TOKEN`: Your DigitalOcean API token

2. The workflow will automatically build and push the Docker image to DigitalOcean Container Registry when you push to the main branch.

## API Authentication

When deployed with an API key, all requests must include the API key in the `X-API-Key` header:

```bash
curl -X POST http://your-mem0-api-url/memories \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{
    "user_id": "test_user",
    "messages": [
      {"role": "user", "content": "Remember that my favorite color is blue"},
      {"role": "assistant", "content": "I will remember that your favorite color is blue"}
    ]
  }'
```

## Backup and Restore

The SQLite database is stored in a Kubernetes persistent volume. To create a backup:

1. Get the pod name:
   ```bash
   kubectl get pods
   ```

2. Copy the database file from the pod:
   ```bash
   kubectl cp mem0-sqlite-pod-name:/root/.mem0/history.db ./backup/history_$(date +%Y%m%d_%H%M%S).db
   ```

3. To restore, copy the database file back to the pod:
   ```bash
   kubectl cp ./backup/history_file.db mem0-sqlite-pod-name:/root/.mem0/history.db
   ```

## Troubleshooting

- Check pod logs:
  ```bash
  kubectl logs -f deployment/mem0-sqlite
  ```

- Check pod status:
  ```bash
  kubectl describe pod mem0-sqlite-pod-name
  ```

- Test API connectivity:
  ```bash
  kubectl port-forward service/mem0-sqlite 8000:8000
  curl http://localhost:8000/docs
  ```
