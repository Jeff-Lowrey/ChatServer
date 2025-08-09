# Docker Deployment Guide

This guide explains how to run the Chat Server application using Docker. The application is containerized using Docker to provide isolation, easy deployment, and consistent environment across different systems.

## Prerequisites

- Docker installed on your system
- Docker Compose installed on your system (optional, for easier deployment)

## Quick Start

The simplest way to run the application is using Docker Compose:

```bash
docker-compose up -d
```

This will:
1. Build the Docker image
2. Start the container
3. Expose the socket server on port 10010
4. Expose the HTTP server on port 8000

## Configuration

### Using a Custom Configuration File

1. Create a `config.properties` file based on the example:

```bash
cp config.example.properties config.properties
```

2. Edit the file with your desired settings:

```properties
[chatserver]
mode = both
socket_host = 0.0.0.0
socket_port = 10010
http_host = 0.0.0.0
http_port = 8000
max_clients = 200
max_message_length = 1024
use_ssl = false
cert_path = 
```

3. The container will use this file through the volume mount defined in `docker-compose.yml`.

### Using Environment Variables

You can override any configuration setting using environment variables in the `docker-compose.yml` file:

```yaml
environment:
  - CHAT_SERVER_MODE=both
  - CHAT_SERVER_MAX_CLIENTS=200
  - CHAT_SERVER_MAX_MESSAGE_LENGTH=1024
```

## SSL Configuration

To enable SSL:

1. Place your certificate in the `certs` directory:

```bash
mkdir -p certs
cp your-certificate.pem certs/
```

2. Update your configuration to enable SSL:

```properties
[chatserver]
use_ssl = true
cert_path = /app/certs/your-certificate.pem
```

Or using environment variables in `docker-compose.yml`:

```yaml
environment:
  - CHAT_SERVER_USE_SSL=true
  - CHAT_SERVER_CERT_PATH=/app/certs/your-certificate.pem
```

## Accessing the Servers

- Socket Server: Available on `localhost:10010`
- HTTP Server: Available on `http://localhost:8000`

## Logs

Logs are stored in the `logs` directory, which is mounted as a volume in the container.

## Building the Image Manually

If you prefer to build and run the Docker image manually:

```bash
# Build the image
docker build -t chatserver .

# Run the container
docker run -d --name chatserver \
  -p 10010:10010 -p 8000:8000 \
  -v $(pwd)/config.properties:/etc/chatserver/config.properties:ro \
  -v $(pwd)/certs:/app/certs:ro \
  -v $(pwd)/logs:/app/logs \
  chatserver
```

## Security Considerations

The application implements several security best practices:

- Runs as non-privileged user `chatuser` inside the container
- Uses the principle of least privilege to minimize security risks
- Implements proper permission settings for mounted volumes
- Includes health checks to ensure container availability
- Uses read-only mounts for sensitive configuration files
- Supports SSL/TLS encryption for secure communication

For production deployments, consider the following additional security measures:

- Use Docker secrets or environment variables for sensitive information
- Implement network segmentation with Docker networks
- Regularly update the base image to get security patches
- Scan the container image for vulnerabilities
- Set resource limits to prevent DoS attacks
- Implement proper logging and monitoring

## Troubleshooting

If you encounter issues:

1. Check the logs:
```bash
docker-compose logs
```

2. Verify the container is running:
```bash
docker-compose ps
```

3. Check if the servers are accessible:
```bash
curl http://localhost:8000/
```

4. If SSL is enabled, ensure your certificate is correctly mounted in the container.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
