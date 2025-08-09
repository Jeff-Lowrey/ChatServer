# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Model Preferences

```json
{
  "model": "latest"
}
```

Always use the latest available Claude model when working with this codebase.

## Project Overview

This is an asynchronous chat server implementation in Python using asyncio and FastAPI. The system supports multiple chat rooms, client connections, and message broadcasting with both raw TCP socket connections and HTTP REST API endpoints.

## Core Architecture

### Main Components

- **src/stream.py**: Core `ChatServer` class implementing async TCP socket server with client management, chat room functionality, and message routing
- **src/api.py**: `ChatAPI` class providing FastAPI REST endpoints that wrap ChatServer functionality
- **src/main.py**: Entry point that imports api and stream modules
- **src/asgi.py**: ASGI configuration (currently empty)

### Key Classes

- `ChatServer`: Manages async TCP connections, client registration, chat rooms, and message broadcasting
- `ChatAPI`: FastAPI wrapper exposing ChatServer operations via HTTP endpoints with Pydantic request models

## Development Commands

### Environment Setup
```bash
# Create virtual environment (optional but recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Code Quality
```bash
# Linting
ruff check .

# Formatting 
ruff format .

# Import sorting
isort .

# Run all code quality checks
./run-tests.sh --lint --format  # On Windows: .\Run-Tests.ps1 -Lint -Format
```

### Running the Server
The server can be run in multiple ways:
- As an async TCP socket server using `ChatServer.run_server()`
- As a FastAPI HTTP server using `ChatAPI` with uvicorn
- Both can run simultaneously for dual protocol support

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

## Data Structures

- `client_list`: Nested dict structure `{chat_room: {client_id: {writer, status}}}`
- Client statuses: NEW, CONNECTED, ACTIVE, SUSPENDED, ERROR, CLOSING, CLOSED
- Default limits: 100 max clients, 255 max message length

## Important Notes

- SSL support is fully implemented and can be enabled via configuration
- Some REST endpoints return "not_implemented" status as they require WebSocket connections
- Client-to-client messaging defined but not implemented in protocol
- The codebase mixes async socket operations with REST API patterns

## Testing Scripts

The project includes several testing scripts:

- `run-tests.sh` / `Run-Tests.ps1`: Docker-based testing scripts for Bash and PowerShell
- `run-tests-archive.sh` / `Run-Tests-Archive.ps1`: Scripts for testing from archive files

### Docker Testing
```bash
# Run all tests in Docker
./run-tests.sh

# Run specific tests
./run-tests.sh --unit
./run-tests.sh --integration
./run-tests.sh --specific tests/test_api.py
```

### Archive Testing
```bash
# Run tests from an archive
./run-tests-archive.sh chat-server.tar.gz
```

## Docker Deployment

The project includes a Dockerfile and docker-compose.yml for containerized deployment.
See `DOCKER.md` and `docker-environments.md` for detailed deployment instructions.
