# Asynchronous Chat Server

A flexible, multi-protocol chat server implementation featuring both TCP socket connections and HTTP/REST API endpoints.

## Author Information

**Author:** Jeff Lowrey <jeff@jaral.org>

This project was developed as part of a coding exercise for ClosedLoop in August 2025.

### Claude's Contributions

Claude, Anthropic's AI assistant, contributed to this project in the following ways:

1. **Code Implementation**:
   - Added exception handling and logging throughout the codebase
   - Implemented the configuration system with multiple sources (config file, environment variables, CLI)
   - Created the properties file format configuration parser
   - Added SSL/TLS support to the ChatServer
   - Refactored the configuration system into a separate module

2. **Architecture Improvements**:
   - Enhanced client list data structure consistency
   - Improved chat room management functionality
   - Added client status tracking with proper state transitions
   - Implemented proper resource cleanup and connection handling
   - Created a ServerConfig class for better configuration organization

3. **Documentation**:
   - Added detailed docstrings to all classes and methods
   - Created comprehensive README and configuration guides
   - Documented the client protocol and REST API endpoints
   - Added comments explaining complex operations and architecture decisions

4. **Testing**:
   - Implemented unit tests for all components
   - Created integration tests for the full system
   - Added specific SSL configuration tests
   - Wrote test fixtures and helpers for easier testing
   - Created Docker-based testing scripts for cross-platform consistency
   - Developed archive-based testing scripts for testing released versions

5. **DevOps**:
   - Created Docker and Docker Compose configuration
   - Implemented proper non-privileged user for Docker containers
   - Set up proper volume mounts for configuration and certificates
   - Developed cross-platform testing scripts (Bash and PowerShell)
   - Created specialized Docker testing environment

## Project Overview

This asynchronous chat server provides a robust platform for real-time communication through multiple interfaces. It supports:

- Raw TCP socket connections for direct client communication
- HTTP REST API endpoints for web application integration
- WebSocket connections for real-time web applications
- Multiple chat rooms with isolated message broadcasting
- Client status management and administrative operations
- Flexible configuration through multiple sources

The server can operate in three modes:
1. **Socket mode**: Only the TCP socket server runs
2. **HTTP mode**: Only the HTTP/ASGI server runs
3. **Both mode**: Both servers run simultaneously with shared state

## Core Architecture

### Key Classes

#### ChatServer (stream.py)
The central component that manages client connections, chat rooms, and message routing. Features:
- Asynchronous TCP socket server using `asyncio`
- Client registration and authentication
- Chat room creation and management
- Message broadcasting to room participants
- Client status tracking (ACTIVE, SUSPENDED, CLOSED, etc.)
- Support for SSL/TLS encryption

#### ChatAPI (api.py)
Provides FastAPI REST endpoints that wrap ChatServer functionality:
- Client registration and management
- Message sending and receiving
- Chat room operations
- Server status monitoring
- Pydantic request models for validation

#### ConnectionManager (asgi.py)
Handles WebSocket connections and integrates with the chat system:
- WebSocket connection management
- Message processing and routing
- Broadcast functionality
- Client tracking

#### ServerConfig (config.py)
Manages configuration from multiple sources with proper priority:
- Command line arguments
- Environment variables
- Configuration files (properties format)
- Default values

## Configuration Options

### Available Configuration Methods

The server can be configured through three methods (in order of precedence):

1. **Command Line Arguments**:
   ```bash
   python -m src.main --mode both --socket-port 10010 --http-port 8000 --use-ssl --cert-path /path/to/cert.pem
   ```

2. **Environment Variables**:
   ```bash
   CHAT_SERVER_MODE=both CHAT_SERVER_SOCKET_PORT=10010 CHAT_SERVER_HTTP_PORT=8000 python -m src.main
   ```

3. **Configuration File** (properties format):
   ```bash
   python -m src.main --config /path/to/config.properties
   ```

### Configuration Parameters

| Parameter           | CLI Argument           | Environment Variable             | Config File         | Default      |
|---------------------|------------------------|----------------------------------|---------------------|--------------|
| Mode                | `--mode`               | `CHAT_SERVER_MODE`               | `mode`              | `both`       |
| Socket Host         | `--socket-host`        | `CHAT_SERVER_SOCKET_HOST`        | `socket_host`       | `127.0.0.1`  |
| Socket Port         | `--socket-port`        | `CHAT_SERVER_SOCKET_PORT`        | `socket_port`       | `10010`      |
| HTTP Host           | `--http-host`          | `CHAT_SERVER_HTTP_HOST`          | `http_host`         | `127.0.0.1`  |
| HTTP Port           | `--http-port`          | `CHAT_SERVER_HTTP_PORT`          | `http_port`         | `8000`       |
| Max Clients         | `--max-clients`        | `CHAT_SERVER_MAX_CLIENTS`        | `max_clients`       | `100`        |
| Max Message Length  | `--max-message-length` | `CHAT_SERVER_MAX_MESSAGE_LENGTH` | `max_message_length`| `255`        |
| SSL Enabled         | `--use-ssl`            | `CHAT_SERVER_USE_SSL`            | `use_ssl`           | `False`      |
| SSL Certificate     | `--cert-path`          | `CHAT_SERVER_CERT_PATH`          | `cert_path`         | `None`       |
| Config File Path    | `--config`             | `CHAT_SERVER_CONFIG_FILE`        | *(not applicable)*  | `None`       |

## Running the Server

### Using Python Directly

#### Prerequisites
- Python 3.9+
- Required packages installed (see requirements.txt)
- pip package manager (23.0.0+ recommended)

#### Installation

##### From Git Repository
```bash
# Clone the repository
git clone https://github.com/yourusername/chat-server.git
cd chat-server

# Install dependencies
pip install -r requirements.txt
```

##### From Archive File
```bash
# Extract the archive file
tar -xzf chat-server.tar.gz   # For .tar.gz file
# OR
unzip chat-server.zip         # For .zip file

# Navigate to the extracted directory
cd chat-server

# Install dependencies
pip install -r requirements.txt

# Optional: Create a virtual environment first
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### Running the Server
```bash
# Run with default settings (both socket and HTTP servers)
python -m src.main

# Run only the socket server
python -m src.main --mode socket

# Run only the HTTP server
python -m src.main --mode http

# Run with custom ports
python -m src.main --socket-port 10010 --http-port 8000

# Run with a configuration file
python -m src.main --config config.properties

# Run with SSL enabled
python -m src.main --use-ssl --cert-path /path/to/certificate.pem
```

### Using Docker

#### Prerequisites
- Docker installed
- Docker Compose (optional, for easier deployment)

#### Running with Docker Compose
```bash
# Start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

#### Running with Docker directly
```bash
# Build the image
docker build -t chatserver .

# Run the container with default settings
docker run -d -p 10010:10010 -p 8000:8000 --name chatserver chatserver

# Run with custom configuration
docker run -d -p 10010:10010 -p 8000:8000 \
  -v $(pwd)/config.properties:/etc/chatserver/config.properties:ro \
  -e CHAT_SERVER_MAX_CLIENTS=200 \
  --name chatserver chatserver

# Run with SSL
docker run -d -p 10010:10010 -p 8000:8000 \
  -v $(pwd)/certs:/app/certs:ro \
  -e CHAT_SERVER_USE_SSL=true \
  -e CHAT_SERVER_CERT_PATH=/app/certs/certificate.pem \
  --name chatserver chatserver
```

## Client Protocol

The raw socket protocol uses space-separated commands:

- `HELLO chat_room:client_id` - Register client
- `SEND chat_room:client_id message` - Send message to room
- `JOIN chat_room:client_id` - Join existing room
- `NEW chat_room:client_id` - Create new room
- `LIST type` - List rooms/clients
- `PAUSE client_id` - Pause client
- `QUIT client_id` - Disconnect client

## REST API Endpoints

Key endpoints provided by `ChatAPI`:

- `POST /clients/register` - Register new client (WebSocket required)
- `POST /messages/send` - Send message to chat room
- `GET /chatrooms/list` - List chat rooms and clients
- `POST /clients/pause` - Pause client activity
- `POST /clients/close` - Disconnect client
- `GET /server/status` - Server status and statistics

## Testing

The Chat Server comes with comprehensive testing scripts that allow you to run tests in different environments: locally, with Docker, or from an archive file. These scripts provide consistent testing across platforms and ensure your code meets quality standards.

### Local Testing

Run tests directly on your local machine:

```bash
# Run all tests
python -m unittest discover tests

# Run a specific test file
python -m unittest tests/test_stream.py

# Run with pytest
pytest tests/

# Run with coverage
pytest --cov=src tests/
```

### Docker-based Testing

Run tests in an isolated Docker container using the provided scripts. This ensures a consistent testing environment regardless of your local setup.

See [RUN_SCRIPTS.md](RUN_SCRIPTS.md) for detailed information on running tests with Docker.

### Archive-based Testing

Run tests directly from an archive file (tar.gz, tgz, or zip) without unpacking it manually. This is useful for testing released versions of the Chat Server or verifying the integrity of distribution packages.

See [RUN_SCRIPTS.md](RUN_SCRIPTS.md) for detailed information on the archive testing scripts.

## License

This project is open-source software available under the [MIT license](LICENSE).

## Additional Documentation

- **CLAUDE.md**: Project overview and guidelines for Anthropic's Claude when working with this codebase
- **DOCKER.md**: Detailed Docker deployment guide with configuration examples and security best practices
- **docker-environments.md**: Example configurations for running Chat Server in different Docker environments
- **RUN_SCRIPTS.md**: Detailed guide to all run and test scripts for different environments
- **tests/README.md**: Comprehensive information about the test suite structure and testing strategies

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
