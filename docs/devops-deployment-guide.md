# Mem0 SQLite Deployment Guide for DevOps

This document provides detailed information for DevOps teams deploying the Mem0 SQLite image in production environments.

## Table of Contents

1. [Docker Image Overview](#docker-image-overview)
2. [Environment Variables](#environment-variables)
3. [Deployment Options](#deployment-options)
   - [Docker Deployment](#docker-deployment)
   - [Kubernetes Deployment](#kubernetes-deployment)
4. [Data Persistence](#data-persistence)
5. [Backup and Restore](#backup-and-restore)
6. [Security Considerations](#security-considerations)
7. [Monitoring and Logging](#monitoring-and-logging)
8. [Troubleshooting](#troubleshooting)

## Docker Image Overview

The Mem0 SQLite image is a containerized version of Mem0 configured to use SQLite as its vector store. This makes it lightweight and easy to deploy in various environments.

**Image Repository**: `registry.digitalocean.com/pioneer/pioneer/mem0-sqlite:latest`

**Architecture**: The container includes:
- Mem0 core library
- FastAPI-based REST server
- SQLite vector store for embeddings
- API key authentication middleware

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | None | OpenAI API key for generating embeddings |
| `API_KEY` | No | None | Custom API key for authenticating requests to the Mem0 API. If not set, the API will be unauthenticated |
| `VECTOR_STORE_TYPE` | No | "memory" | Type of vector store to use. Keep as "memory" for SQLite |
| `LOG_LEVEL` | No | "info" | Logging level (debug, info, warning, error) |
| `EMBEDDING_MODEL` | No | "text-embedding-3-small" | OpenAI embedding model to use |
| `MAX_TOKENS` | No | 8192 | Maximum tokens for context window |

## Deployment Options

### Docker Deployment

**Basic Docker Run Command**:

```bash
docker run -d \
  --name mem0-sqlite \
  -p 8000:8000 \
  -v /path/to/data:/root/.mem0 \
  -e OPENAI_API_KEY=your_openai_api_key \
  -e API_KEY=your_custom_api_key \
  registry.digitalocean.com/pioneer/pioneer/mem0-sqlite:latest
```

**Docker Compose Example**:

```yaml
version: '3'

services:
  mem0:
    image: registry.digitalocean.com/pioneer/pioneer/mem0-sqlite:latest
    ports:
      - "0.0.0.0:8000:8000"
    volumes:
      - ./data:/root/.mem0
    env_file:
      - .env
    environment:
      - VECTOR_STORE_TYPE=memory
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/docs"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
```

### Kubernetes Deployment

**Prerequisites**:
- Kubernetes cluster (e.g., DigitalOcean Kubernetes)
- kubectl configured to access your cluster
- Persistent volume provisioner

**Deployment Steps**:

1. Create Kubernetes secrets:
   ```bash
   export OPENAI_API_KEY=your_openai_api_key
   export API_KEY=your_custom_api_key
   
   kubectl create secret generic mem0-secrets \
     --from-literal=openai-api-key=$OPENAI_API_KEY \
     --from-literal=api-key=$API_KEY
   ```

2. Apply the Kubernetes manifests:
   ```bash
   kubectl apply -f kubernetes/mem0-deployment.yaml
   ```

**Kubernetes Manifest Example**:
See the full example in [kubernetes/mem0-deployment.yaml](../kubernetes/mem0-deployment.yaml)

## Data Persistence

The SQLite database is stored at `/root/.mem0/history.db` inside the container. To persist data:

1. **Docker**: Mount a volume to `/root/.mem0`
2. **Kubernetes**: Use a PersistentVolumeClaim mounted to `/root/.mem0`

## Backup and Restore

### Backup Process

**Docker Backup**:
```bash
# Create backup directory
mkdir -p backups

# Copy SQLite database from container
docker cp mem0-sqlite:/root/.mem0/history.db ./backups/history_$(date +%Y%m%d_%H%M%S).db
```

**Kubernetes Backup**:
```bash
# Get pod name
POD_NAME=$(kubectl get pods -l app=mem0-sqlite -o jsonpath="{.items[0].metadata.name}")

# Copy SQLite database from pod
kubectl cp $POD_NAME:/root/.mem0/history.db ./backups/history_$(date +%Y%m%d_%H%M%S).db
```

**Automated Backups to DigitalOcean Spaces**:

Create a CronJob in Kubernetes:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mem0-backup
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: amazon/aws-cli
            command:
            - /bin/sh
            - -c
            - |
              cp /data/history.db /backup/history_$(date +%Y%m%d_%H%M%S).db
              aws s3 cp /backup/history_$(date +%Y%m%d_%H%M%S).db s3://your-bucket/backups/ --endpoint=https://nyc3.digitaloceanspaces.com
            volumeMounts:
            - name: mem0-data
              mountPath: /data
            - name: backup-dir
              mountPath: /backup
            env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: spaces-credentials
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: spaces-credentials
                  key: secret-key
          volumes:
          - name: mem0-data
            persistentVolumeClaim:
              claimName: mem0-pvc
          - name: backup-dir
            emptyDir: {}
          restartPolicy: OnFailure
```

### Restore Process

**Docker Restore**:
```bash
# Stop the container
docker stop mem0-sqlite

# Copy backup file to container
docker cp ./backups/history_file.db mem0-sqlite:/root/.mem0/history.db

# Start the container
docker start mem0-sqlite
```

**Kubernetes Restore**:
```bash
# Scale down deployment
kubectl scale deployment mem0-sqlite --replicas=0

# Get pod name (after scaling back up to 1)
kubectl scale deployment mem0-sqlite --replicas=1
POD_NAME=$(kubectl get pods -l app=mem0-sqlite -o jsonpath="{.items[0].metadata.name}")

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/$POD_NAME

# Copy backup file to pod
kubectl cp ./backups/history_file.db $POD_NAME:/root/.mem0/history.db

# Restart the pod
kubectl delete pod $POD_NAME
```

## Security Considerations

1. **API Authentication**:
   - Always set the `API_KEY` environment variable in production
   - Use a strong, randomly generated key
   - Rotate the key periodically

2. **Network Security**:
   - Restrict access to the Mem0 API using network policies
   - Consider using an API Gateway or Ingress with TLS

3. **Secrets Management**:
   - Store API keys in Kubernetes secrets or environment variables
   - Never hardcode secrets in Dockerfiles or scripts
   - Consider using a secrets management solution like HashiCorp Vault

4. **Data Protection**:
   - Encrypt persistent volumes in Kubernetes
   - Encrypt backup files before storing in object storage

## Monitoring and Logging

### Logging

The container outputs logs to stdout/stderr, which can be collected by your logging infrastructure:

**Docker Logs**:
```bash
docker logs mem0-sqlite
```

**Kubernetes Logs**:
```bash
kubectl logs -f deployment/mem0-sqlite
```

### Monitoring

**Health Check Endpoint**:
- The container includes a health check at `http://localhost:8000/docs`
- Use this for readiness/liveness probes in Kubernetes

**Prometheus Metrics** (if enabled):
- Metrics are exposed at `/metrics` endpoint
- Configure Prometheus to scrape this endpoint

## Troubleshooting

### Common Issues

1. **Container fails to start**:
   - Check if OPENAI_API_KEY is set correctly
   - Verify volume permissions

2. **API returns 401 Unauthorized**:
   - Ensure API_KEY is set correctly
   - Check that requests include the X-API-Key header

3. **Memory search not working**:
   - Check if the SQLite database exists and is accessible
   - Verify that the volume is properly mounted

### Diagnostic Commands

**Check SQLite Database**:
```bash
# Docker
docker exec -it mem0-sqlite ls -la /root/.mem0

# Kubernetes
kubectl exec -it $(kubectl get pods -l app=mem0-sqlite -o jsonpath="{.items[0].metadata.name}") -- ls -la /root/.mem0
```

**Verify API Connection**:
```bash
# Test API connection
curl -v http://your-mem0-api-url/docs
```

**Test Memory Creation**:
```bash
# Create a test memory
curl -X POST http://your-mem0-api-url/memories \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{
    "user_id": "test_user",
    "messages": [
      {"role": "user", "content": "Test memory"},
      {"role": "assistant", "content": "This is a test memory"}
    ]
  }'
```
