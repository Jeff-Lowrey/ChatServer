#!/bin/bash
# Run-Docker.sh - Script to run the Chat Server in Docker
# Author: Jeff Lowrey <jeff@jaral.org>
# Date: 2025-08-09
# 
# This script was created with assistance from Anthropic's Claude AI

# Set default configuration
SOCKET_PORT=10010
HTTP_PORT=8000
CONFIG_FILE="config.properties"
USE_SSL=false
CERT_PATH=""
MODE="both"
DETACHED=false

# Print usage information
show_help() {
    echo "Usage: $0 [options]"
    echo "Run the Chat Server using Docker."
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -s, --socket-port PORT  Set socket server port (default: 10010)"
    echo "  -w, --http-port PORT    Set HTTP server port (default: 8000)"
    echo "  -c, --config FILE       Use custom config file (default: config.properties)"
    echo "  --ssl                   Enable SSL"
    echo "  --cert PATH             Path to SSL certificate (required if SSL enabled)"
    echo "  -m, --mode MODE         Set server mode: socket, http, both (default: both)"
    echo "  -d, --detached          Run in detached mode"
    echo "  --build                 Rebuild the Docker image"
    echo "  --stop                  Stop running containers"
    echo "  --logs                  View logs of running container"
    echo ""
    echo "Examples:"
    echo "  $0                      Run with default settings"
    echo "  $0 --socket-port 9000   Run with custom socket port"
    echo "  $0 --ssl --cert ./certs/mycert.pem   Run with SSL enabled"
    echo "  $0 --mode http          Run only the HTTP server"
    echo "  $0 --stop               Stop running containers"
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--socket-port)
            SOCKET_PORT="$2"
            shift 2
            ;;
        -w|--http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --ssl)
            USE_SSL=true
            shift
            ;;
        --cert)
            CERT_PATH="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -d|--detached)
            DETACHED=true
            shift
            ;;
        --build)
            echo "Building Docker image..."
            docker build -t chatserver .
            exit 0
            ;;
        --stop)
            echo "Stopping running containers..."
            docker-compose down
            exit 0
            ;;
        --logs)
            echo "Viewing logs..."
            docker-compose logs -f
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate arguments
if [ "$USE_SSL" = true ] && [ -z "$CERT_PATH" ]; then
    echo "Error: SSL certificate path is required when SSL is enabled."
    echo "Use --cert PATH to specify the certificate path."
    exit 1
fi

# Make sure the certificate directory exists if SSL is enabled
if [ "$USE_SSL" = true ]; then
    CERT_DIR=$(dirname "$CERT_PATH")
    mkdir -p "$CERT_DIR"
    
    if [ ! -f "$CERT_PATH" ]; then
        echo "Warning: Certificate file not found at $CERT_PATH"
        echo "You need to place your SSL certificate at this location."
    fi
fi

# Prepare environment variables
ENV_VARS="-e CHAT_SERVER_MODE=$MODE"
ENV_VARS="$ENV_VARS -e CHAT_SERVER_SOCKET_PORT=$SOCKET_PORT"
ENV_VARS="$ENV_VARS -e CHAT_SERVER_HTTP_PORT=$HTTP_PORT"

if [ "$USE_SSL" = true ]; then
    ENV_VARS="$ENV_VARS -e CHAT_SERVER_USE_SSL=true"
    ENV_VARS="$ENV_VARS -e CHAT_SERVER_CERT_PATH=/app/certs/$(basename "$CERT_PATH")"
fi

# Create config directory if it doesn't exist
CONFIG_DIR=$(dirname "$CONFIG_FILE")
mkdir -p "$CONFIG_DIR"

# Check if config file exists, if not create a sample one
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "config.example.properties" ]; then
        echo "Config file not found, creating one from example..."
        cp config.example.properties "$CONFIG_FILE"
    else
        echo "Warning: Neither config file nor example config found."
        echo "Using default configuration."
    fi
fi

# Run with docker-compose if available, otherwise use docker run
if command -v docker-compose &>/dev/null; then
    echo "Running with docker-compose..."
    
    # Create or update the docker-compose override file
    cat > docker-compose.override.yml << EOF
version: '3.8'
services:
  chatserver:
    ports:
      - "${SOCKET_PORT}:10010"
      - "${HTTP_PORT}:8000"
    environment:
      - CHAT_SERVER_MODE=${MODE}
EOF

    if [ "$USE_SSL" = true ]; then
        echo "      - CHAT_SERVER_USE_SSL=true" >> docker-compose.override.yml
        echo "      - CHAT_SERVER_CERT_PATH=/app/certs/$(basename "$CERT_PATH")" >> docker-compose.override.yml
        
        # Make sure certs directory exists
        mkdir -p certs
        
        # If certificate exists, copy it to the certs directory
        if [ -f "$CERT_PATH" ]; then
            cp "$CERT_PATH" "certs/$(basename "$CERT_PATH")"
        fi
    fi
    
    # Run docker-compose
    if [ "$DETACHED" = true ]; then
        docker-compose up -d
    else
        docker-compose up
    fi
else
    echo "Running with docker run..."
    
    # Prepare volumes
    VOLUMES="-v $(pwd)/$CONFIG_FILE:/etc/chatserver/config.properties:ro"
    
    if [ "$USE_SSL" = true ]; then
        VOLUMES="$VOLUMES -v $(pwd)/certs:/app/certs:ro"
        
        # Make sure certs directory exists
        mkdir -p certs
        
        # If certificate exists, copy it to the certs directory
        if [ -f "$CERT_PATH" ]; then
            cp "$CERT_PATH" "certs/$(basename "$CERT_PATH")"
        fi
    fi
    
    # Create logs directory
    mkdir -p logs
    VOLUMES="$VOLUMES -v $(pwd)/logs:/app/logs"
    
    # Run the container
    if [ "$DETACHED" = true ]; then
        docker run -d --name chatserver \
            -p "${SOCKET_PORT}:10010" -p "${HTTP_PORT}:8000" \
            $ENV_VARS \
            $VOLUMES \
            chatserver
        
        echo "Container started in detached mode. Use the following to view logs:"
        echo "docker logs -f chatserver"
    else
        docker run --rm --name chatserver \
            -p "${SOCKET_PORT}:10010" -p "${HTTP_PORT}:8000" \
            $ENV_VARS \
            $VOLUMES \
            chatserver
    fi
fi

echo "Chat Server is running!"
echo "Socket server available at: localhost:${SOCKET_PORT}"
echo "HTTP server available at: http://localhost:${HTTP_PORT}"

