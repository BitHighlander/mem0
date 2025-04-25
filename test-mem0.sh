#!/bin/bash

set -e  # Exit on any error

echo "=== Mem0 SQLite Test Script ==="

# Create data directory if it doesn't exist
mkdir -p data

# Check if .env file exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Please create it with your OPENAI_API_KEY."
  exit 1
fi

# Start the Mem0 container
echo "Starting Mem0 container..."
docker-compose up -d

# Wait for the service to be ready
echo "Waiting for Mem0 API to be ready..."
sleep 5
MAX_RETRIES=10
RETRY_COUNT=0

while ! curl -s http://localhost:8000/docs > /dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: Mem0 API failed to start after $MAX_RETRIES attempts."
    docker-compose logs
    docker-compose down
    exit 1
  fi
  echo "Waiting for Mem0 API to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 5
done

echo "Mem0 API is ready!"

# Create a test user
USER_ID="test_user_$(date +%s)"
echo "Creating test user: $USER_ID"

# Test 1: Add a memory
echo "Test 1: Adding a memory..."
MEMORY_RESPONSE=$(curl -s -X POST http://localhost:8000/memories \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"My favorite color is blue.\"},
      {\"role\": \"assistant\", \"content\": \"I'll remember that your favorite color is blue.\"}
    ]
  }")

echo "Memory creation response: $MEMORY_RESPONSE"

# Test 2: Search for the memory
echo "Test 2: Searching for the memory..."
SEARCH_RESPONSE=$(curl -s -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"query\": \"What is my favorite color?\"
  }")

echo "Search response: $SEARCH_RESPONSE"

# Check if the search found our memory
if echo "$SEARCH_RESPONSE" | grep -q "blue"; then
  echo "✅ Test PASSED: Memory was successfully retrieved!"
else
  echo "❌ Test FAILED: Memory was not found in search results."
  echo "Search response: $SEARCH_RESPONSE"
fi

# Create backup of the SQLite database
echo "Creating backup of the SQLite databases..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups"
mkdir -p $BACKUP_DIR

# Check what files are in the data directory
echo "Files in the data directory before backup:"
ls -la ./data/

# Copy the history.db file (main SQLite database)
cp ./data/history.db "$BACKUP_DIR/history_$TIMESTAMP.db"

echo "Backup created at:"
echo "- $BACKUP_DIR/vector_store_$TIMESTAMP.db"
echo "- $BACKUP_DIR/history_$TIMESTAMP.db"

# Stop the container
echo "Stopping Mem0 container..."
docker-compose down

# Simulate data loss by removing the data files
echo "Simulating data loss by removing data files..."
rm -f ./data/history.db

# Restore from backup
echo "Restoring from backup..."
cp "$BACKUP_DIR/history_$TIMESTAMP.db" ./data/history.db

# Restart the container with restored data
echo "Restarting Mem0 container with restored data..."
docker-compose up -d

# Wait for the service to be ready again
echo "Waiting for Mem0 API to be ready..."
sleep 5
RETRY_COUNT=0

while ! curl -s http://localhost:8000/docs > /dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: Mem0 API failed to restart after $MAX_RETRIES attempts."
    docker-compose logs
    docker-compose down
    exit 1
  fi
  echo "Waiting for Mem0 API to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 5
done

echo "Mem0 API is ready again!"

# Test 3: Verify memory still exists after restore
echo "Test 3: Verifying memory exists after restore..."
SEARCH_RESPONSE_AFTER_RESTORE=$(curl -s -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"query\": \"What is my favorite color?\"
  }")

echo "Search response after restore: $SEARCH_RESPONSE_AFTER_RESTORE"

# Check if the search found our memory after restore
if echo "$SEARCH_RESPONSE_AFTER_RESTORE" | grep -q "blue"; then
  echo "✅ Test PASSED: Memory was successfully retrieved after restore!"
else
  echo "❌ Test FAILED: Memory was not found after restore."
  echo "Search response: $SEARCH_RESPONSE_AFTER_RESTORE"
fi

echo "=== Test Summary ==="
echo "1. Started Mem0 with SQLite"
echo "2. Created and retrieved a memory"
echo "3. Backed up the SQLite databases"
echo "4. Simulated data loss"
echo "5. Restored from backup"
echo "6. Verified memory persistence"

# List the files in the data directory
echo "Files in the data directory:"
ls -la ./data/

echo "Do you want to keep the Mem0 container running? (y/n)"
read -r KEEP_RUNNING

if [ "$KEEP_RUNNING" != "y" ]; then
  echo "Stopping Mem0 container..."
  docker-compose down
  echo "Mem0 container stopped."
else
  echo "Mem0 container is still running. Stop it later with 'docker-compose down'"
fi

echo "Test completed!"
