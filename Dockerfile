FROM mem0/mem0-api-server:latest

# Set working directory
WORKDIR /app

# Copy custom configuration files if needed
COPY ./config /app/config

# Create volume mount points
RUN mkdir -p /root/.mem0

# Environment variables will be provided at runtime via .env file
ENV API_KEY=""

# Expose the port
EXPOSE 8000

# Add a healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/docs || exit 1

# Command to run the server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
