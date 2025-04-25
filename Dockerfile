FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone the Mem0 repository
RUN git clone https://github.com/mem0ai/mem0.git .

# Install Python dependencies
RUN pip install --no-cache-dir -e .

# Install server dependencies
WORKDIR /app/server
RUN pip install --no-cache-dir -r requirements.txt

# Create volume mount points for SQLite database
RUN mkdir -p /root/.mem0

# Copy our custom authentication middleware
COPY ./src/middleware /app/server/middleware

# Add authentication to the server
RUN echo "\n# Import custom auth middleware\nfrom middleware.auth import apiKeyMiddleware\n\n# Add auth middleware\napp.middleware('http')(apiKeyMiddleware)" >> main.py

# Create a custom config file to ensure we use SQLite
RUN mkdir -p /app/config
COPY ./config/mem0_config.json /app/config/mem0_config.json

# Environment variables will be provided at runtime via .env file
ENV API_KEY=""
ENV VECTOR_STORE_TYPE="memory"
ENV MEM0_CONFIG_PATH="/app/config/mem0_config.json"

# Expose the port
EXPOSE 8000

# Add a healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/docs || exit 1

# Command to run the server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
