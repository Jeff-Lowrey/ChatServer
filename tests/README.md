# Chat Server Test Suite

This directory contains comprehensive tests for the asynchronous chat server implementation. The test suite includes unit tests for individual components and integration tests for the complete system.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.

## Test Structure

The test suite is organized as follows:

- `test_stream.py`: Unit tests for the `ChatServer` class in `stream.py`
- `test_api.py`: Unit tests for the `ChatAPI` class in `api.py`
- `test_asgi.py`: Unit tests for WebSocket functionality in `asgi.py`
- `test_integration.py`: Integration tests for the complete system

## Test Coverage

The tests cover the following functionality:

### ChatServer Tests (`test_stream.py`)

- Server initialization and configuration
- Client registration and management
- Chat room creation and joining
- Message sending and broadcasting
- Client status management (pause, close)
- Error handling and edge cases

### ChatAPI Tests (`test_api.py`)

- API endpoint functionality
- Request validation and handling
- Response formatting
- Error handling
- HTTP status codes
- API factory function

### ASGI Tests (`test_asgi.py`)

- WebSocket connection management
- Message processing
- Broadcast functionality
- Client tracking
- Error handling

### Integration Tests (`test_integration.py`)

- TCP socket and HTTP server interoperability
- WebSocket connectivity
- Concurrent client handling
- Cross-protocol message routing
- System stability under load

## Running Tests

The Chat Server provides multiple ways to run tests: directly with Python, using Docker, or from an archive file.

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

Run tests in an isolated Docker container:

```bash
# Run all tests in Docker (Bash/Linux/macOS)
./run-tests.sh

# Run all tests in Docker (PowerShell/Windows)
.\Run-Tests.ps1

# Run only unit tests
./run-tests.sh --unit

# Run with coverage
./run-tests.sh --coverage

# Run specific test file
./run-tests.sh --specific tests/test_api.py
```

### Archive-based Testing

Run tests directly from an archive file:

```bash
# Run all tests from archive (Bash/Linux/macOS)
./run-tests-archive.sh chat-server.tar.gz

# Run all tests from archive (PowerShell/Windows)
.\Run-Tests-Archive.ps1 chat-server.zip

# Run unit tests with coverage
./run-tests-archive.sh --unit --coverage chat-server.zip
```

## Test Dependencies

The tests require the following dependencies:

- pytest
- pytest-asyncio
- pytest-cov
- websockets
- httpx
- requests

You can install them with:

```bash
pip install pytest pytest-asyncio pytest-cov websockets httpx requests
```

## Testing Strategy

The test suite uses real components where possible to ensure accurate behavior testing:

- Real `ChatServer` and `ChatAPI` instances for most tests
- Skip decorators for tests requiring external components (like `StreamWriter` and `WebSocket`)
- `IsolatedAsyncioTestCase` for testing asynchronous functions

Integration tests focus on testing the actual components working together, with skip decorators for tests requiring running servers.

## Notes

- Some integration tests use separate threads or processes to run server instances
- WebSocket tests may require additional setup for full coverage
- The TCP socket server tests use skip decorators for tests requiring socket I/O
- Docker-based tests ensure a consistent environment across platforms
- Archive-based tests are useful for verifying released versions

## Continuous Integration

The test suite is designed to work in CI/CD pipelines. You can use the Docker-based test scripts in your CI workflow:

```yaml
# Example GitHub Actions workflow
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
```
