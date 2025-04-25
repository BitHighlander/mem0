#!/bin/bash

set -e  # Exit on any error

CONTAINER_NAME="mem0-mem0-1"
API_URL="http://localhost:8000"
BACKUP_DIR="./backups"
LOG_FILE="./mem0-startup.log"

# Function to log messages
log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  log "ERROR: Docker is not running. Please start Docker first."
  exit 1
fi

# Check if the container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
  log "Mem0 container is already running."
  CONTAINER_RUNNING=true
else
  # Check if the container exists but is stopped
  if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    log "Mem0 container exists but is stopped. Starting it..."
    docker start $CONTAINER_NAME
  else
    log "Mem0 container does not exist. Starting with docker-compose..."
    docker-compose up -d
  fi
  
  # Wait for container to be fully up
  log "Waiting for Mem0 API to be ready..."
  MAX_RETRIES=10
  RETRY_COUNT=0
  
  while ! curl -s "$API_URL/docs" > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
      log "ERROR: Mem0 API failed to start after $MAX_RETRIES attempts."
      docker-compose logs
      exit 1
    fi
    log "Waiting for Mem0 API to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
  done
  
  CONTAINER_RUNNING=true
  log "Mem0 API is ready!"
fi

# Test the API connection
if [ "$CONTAINER_RUNNING" = true ]; then
  log "Testing API connection..."
  if curl -s "$API_URL/docs" > /dev/null; then
    log "API connection successful!"
    
    # Create a backup
    log "Creating backup of SQLite database..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Check if history.db exists
    if [ -f "./data/history.db" ]; then
      cp "./data/history.db" "$BACKUP_DIR/history_$TIMESTAMP.db"
      log "Backup created at: $BACKUP_DIR/history_$TIMESTAMP.db"
      
      # Keep only the 5 most recent backups
      log "Cleaning up old backups, keeping only the 5 most recent..."
      ls -t "$BACKUP_DIR"/history_*.db | tail -n +6 | xargs -I {} rm {} 2>/dev/null || true
    else
      log "WARNING: history.db not found in ./data/ directory."
      log "Available files in ./data/:"
      ls -la ./data/
    fi
    
    log "Mem0 is running and accessible at $API_URL"
    log "API documentation available at $API_URL/docs"
  else
    log "ERROR: API connection test failed."
    docker-compose logs
  fi
else
  log "ERROR: Container is not running."
fi

# Print connection information
echo ""
echo "===== Mem0 Connection Information ====="
echo "API URL: $API_URL"
echo "API Documentation: $API_URL/docs"
echo "========================================"
echo ""
echo "To stop the container, run: docker-compose down"
echo "To view logs, run: docker-compose logs"
echo "To create a new backup, run this script again."
