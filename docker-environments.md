# Docker Environment Configurations

This document provides example configurations for running the Chat Server in different Docker environments. Each configuration shows how to set environment variables, mount volumes, and configure networking for specific deployment scenarios.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.

## Basic Configuration

The most basic configuration runs the Chat Server with default settings.

```bash
docker run -d \
  -p 10010:10010 \
  -p 8000:8000 \
  --name chatserver \
  chatserver
```

## Development Environment

Configuration optimized for local development with mounted source code for live changes.

```bash
docker run -d \
  -p 10010:10010 \
  -p 8000:8000 \
  -v $(pwd)/src:/app/src \
  -v $(pwd)/config.properties:/etc/chatserver/config.properties \
  -v $(pwd)/logs:/app/logs \
  -e CHAT_SERVER_MODE=both \
  -e CHAT_SERVER_MAX_CLIENTS=50 \
  -e CHAT_SERVER_MAX_MESSAGE_LENGTH=2048 \
  --name chatserver-dev \
  chatserver
```

## Testing Environment

Configuration for running tests in an isolated environment.

```bash
docker run --rm \
  -v $(pwd):/app \
  -e PYTHONDONTWRITEBYTECODE=1 \
  -e PYTHONUNBUFFERED=1 \
  chatserver \
  pytest tests/ -v
```

## Production Environment

Secure configuration for production deployment with SSL enabled.

```bash
docker run -d \
  -p 10010:10010 \
  -p 8000:8000 \
  -v /path/to/certs:/app/certs:ro \
  -v /path/to/config.properties:/etc/chatserver/config.properties:ro \
  -v /path/to/logs:/app/logs \
  -e CHAT_SERVER_MODE=both \
  -e CHAT_SERVER_MAX_CLIENTS=500 \
  -e CHAT_SERVER_MAX_MESSAGE_LENGTH=1024 \
  -e CHAT_SERVER_USE_SSL=true \
  -e CHAT_SERVER_CERT_PATH=/app/certs/certificate.pem \
  --restart unless-stopped \
  --name chatserver-prod \
  chatserver
```

## High-Performance Environment

Configuration optimized for high-performance with increased resource limits.

```bash
docker run -d \
  -p 10010:10010 \
  -p 8000:8000 \
  -v /path/to/config.properties:/etc/chatserver/config.properties:ro \
  -v /path/to/logs:/app/logs \
  -e CHAT_SERVER_MODE=both \
  -e CHAT_SERVER_MAX_CLIENTS=1000 \
  -e CHAT_SERVER_MAX_MESSAGE_LENGTH=4096 \
  --cpus=2 \
  --memory=2g \
  --restart unless-stopped \
  --name chatserver-high-perf \
  chatserver
```

## Socket-Only Environment

Configuration for deployments that only need the TCP socket server.

```bash
docker run -d \
  -p 10010:10010 \
  -v /path/to/config.properties:/etc/chatserver/config.properties:ro \
  -v /path/to/logs:/app/logs \
  -e CHAT_SERVER_MODE=socket \
  --name chatserver-socket \
  chatserver
```

## HTTP-Only Environment

Configuration for deployments that only need the HTTP/REST API server.

```bash
docker run -d \
  -p 8000:8000 \
  -v /path/to/config.properties:/etc/chatserver/config.properties:ro \
  -v /path/to/logs:/app/logs \
  -e CHAT_SERVER_MODE=http \
  --name chatserver-http \
  chatserver
```

## Docker Compose Environment

For orchestrating multiple containers with Docker Compose:

```yaml
# docker-compose.yaml
version: '3.8'

services:
  chatserver:
    build:
      context: .
      dockerfile: Dockerfile
    image: chatserver:latest
    container_name: chatserver
    restart: unless-stopped
    ports:
      - "10010:10010"
      - "8000:8000"
    volumes:
      - ./config.properties:/etc/chatserver/config.properties:ro
      - ./certs:/app/certs:ro
      - ./logs:/app/logs
    environment:
      - CHAT_SERVER_MODE=both
      - CHAT_SERVER_MAX_CLIENTS=200
      - CHAT_SERVER_MAX_MESSAGE_LENGTH=1024
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s
    networks:
      - chatnet

networks:
  chatnet:
    driver: bridge
```

## Kubernetes Environment

Example Kubernetes Deployment:

```yaml
# kubernetes-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chatserver
  labels:
    app: chatserver
spec:
  replicas: 3
  selector:
    matchLabels:
      app: chatserver
  template:
    metadata:
      labels:
        app: chatserver
    spec:
      containers:
      - name: chatserver
        image: chatserver:latest
        ports:
        - containerPort: 10010
          name: socket
        - containerPort: 8000
          name: http
        env:
        - name: CHAT_SERVER_MODE
          value: "both"
        - name: CHAT_SERVER_MAX_CLIENTS
          value: "200"
        - name: CHAT_SERVER_MAX_MESSAGE_LENGTH
          value: "1024"
        - name: CHAT_SERVER_SOCKET_HOST
          value: "0.0.0.0"
        - name: CHAT_SERVER_HTTP_HOST
          value: "0.0.0.0"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/chatserver
          readOnly: true
        - name: logs-volume
          mountPath: /app/logs
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
          requests:
            cpu: "0.5"
            memory: "256Mi"
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: config-volume
        configMap:
          name: chatserver-config
      - name: logs-volume
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: chatserver
spec:
  selector:
    app: chatserver
  ports:
  - port: 10010
    targetPort: socket
    name: socket
  - port: 8000
    targetPort: http
    name: http
  type: LoadBalancer
```

## Environment Variables Reference

Here's a complete reference of environment variables that can be used to configure the Chat Server in Docker:

| Environment Variable | Description | Default Value | Security Notes |
|---------------------|-------------|---------------|---------------|
| `CHAT_SERVER_MODE` | Server mode: socket, http, or both | both | Consider using socket-only mode in sensitive environments |
| `CHAT_SERVER_SOCKET_HOST` | Host for socket server | 0.0.0.0 | Use internal network address for private deployments |
| `CHAT_SERVER_SOCKET_PORT` | Port for socket server | 10010 | Non-standard ports reduce automated scanning risks |
| `CHAT_SERVER_HTTP_HOST` | Host for HTTP server | 0.0.0.0 | Use internal network address for private deployments |
| `CHAT_SERVER_HTTP_PORT` | Port for HTTP server | 8000 | Ensure proper firewall rules are in place |
| `CHAT_SERVER_MAX_CLIENTS` | Maximum number of clients | 100 | Adjust based on available resources to prevent DoS |
| `CHAT_SERVER_MAX_MESSAGE_LENGTH` | Maximum message length | 255 | Limit to prevent message flooding attacks |
| `CHAT_SERVER_USE_SSL` | Enable SSL (true/false) | false | Always enable in production environments |
| `CHAT_SERVER_CERT_PATH` | Path to SSL certificate | None | Mount certificates as read-only volumes |
| `CHAT_SERVER_CONFIG_FILE` | Path to config file | /etc/chatserver/config.properties | Use read-only mounts for configuration |

## Testing Environments

For testing and CI/CD integration, use the included testing scripts. These provide consistent environments for testing across different platforms and scenarios.

See the [tests/README.md](tests/README.md) file for more detailed information about testing approaches and scripts.

### Continuous Integration Example

```yaml
# Example GitHub Actions workflow for Chat Server
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Docker
        uses: docker/setup-buildx-action@v2
      - name: Run tests
        run: ./run-tests.sh --coverage
      - name: Run linting
        run: ./run-tests.sh --lint
  docker:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: chatserver:latest
```

## Security Best Practices

When deploying the Chat Server Docker container in production, follow these security best practices:

1. **Use read-only volumes** for configuration and certificates (`ro` flag)
2. **Never run as root** (the Dockerfile already uses a non-privileged `chatuser`)
3. **Set resource limits** to prevent container resource exhaustion
4. **Enable SSL** in production environments
5. **Use Docker Secrets** or Kubernetes Secrets for sensitive data
6. **Enable health checks** to ensure container availability
7. **Set container restart policies** for automatic recovery
8. **Use a private container registry** for production deployments
9. **Scan container images** for vulnerabilities before deployment
10. **Keep the Docker image updated** with security patches
11. **Implement proper logging and monitoring** for security events
12. **Apply the principle of least privilege** to all container components
13. **Use multi-stage builds** to minimize attack surface
14. **Never embed secrets in Docker images** or environment variables
15. **Implement network segmentation** with Docker networks

See the [DOCKER.md](DOCKER.md) file for more detailed security guidance.
