FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CHAT_SERVER_MODE=both \
    CHAT_SERVER_SOCKET_HOST=0.0.0.0 \
    CHAT_SERVER_HTTP_HOST=0.0.0.0

# Create non-privileged user
RUN groupadd -r chatuser && useradd -r -g chatuser chatuser

# Create necessary directories with proper permissions
RUN mkdir -p /app /app/logs /app/certs /etc/chatserver && \
    chown -R chatuser:chatuser /app /etc/chatserver

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ /app/src/
COPY config.example.properties /etc/chatserver/config.example.properties

# Install curl for health check
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Create a default config file
RUN cp /etc/chatserver/config.example.properties /etc/chatserver/config.properties && \
    chown chatuser:chatuser /etc/chatserver/config.properties

# Switch to non-privileged user
USER chatuser

# Expose ports (socket server and HTTP server)
EXPOSE 10010 8000

# Set health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Create and set permissions for log files and dirs
USER root
RUN mkdir -p /app/logs && \
    touch /app/logs/chat_server.log && \
    chown -R chatuser:chatuser /app/logs

# Switch back to non-privileged user
USER chatuser

# Run the application
CMD ["python", "-m", "src.main", "--config", "/etc/chatserver/config.properties"]
