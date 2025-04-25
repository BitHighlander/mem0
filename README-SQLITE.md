# Mem0 with SQLite Vector Store

This is a fork of [Mem0](https://github.com/mem0ai/mem0) configured to use SQLite as the vector store, making it easy to deploy in containerized environments like DigitalOcean Kubernetes.

## Features

- **SQLite Vector Store**: Lightweight, file-based vector database that lives in the same container
- **Docker Deployment**: Ready-to-use Docker configuration for easy deployment
- **API Key Authentication**: Secure your Mem0 instance with API key authentication
- **Kubernetes Support**: Deployment manifests for DigitalOcean Kubernetes
- **Backup & Restore**: Tools for backing up and restoring your memory database

## Quick Start

### Local Development

1. Clone this repository:
   ```bash
   git clone https://github.com/BitHighlander/mem0.git
   cd mem0
   ```

2. Create a `.env` file with your OpenAI API key:
   ```
   OPENAI_API_KEY=your_openai_api_key
   API_KEY=your_custom_api_key_for_authentication
   ```

3. Start the Mem0 server:
   ```bash
   ./mem0-startup.sh
   ```

4. Access the API at http://localhost:8000 and the documentation at http://localhost:8000/docs

### Docker

Build and run with Docker:
```bash
npm run docker:build
npm run docker:run
```

## Deployment

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## API Usage

When using the API with authentication enabled, include your API key in the `X-API-Key` header:

```bash
curl -X POST http://localhost:8000/memories \
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

## GitHub Actions

This repository includes a GitHub Actions workflow for building and pushing the Docker image to DigitalOcean Container Registry. To use it:

1. Add the `DIGITALOCEAN_ACCESS_TOKEN` secret to your GitHub repository
2. Manually trigger the workflow from the Actions tab

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
