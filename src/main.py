"""
Main entry point for the chat server application.

Provides functionality to run the chat server in different modes:
- TCP socket server only
- HTTP/ASGI server only
- Both servers simultaneously

Configuration can be provided from multiple sources with the following precedence:
1. Command line arguments (highest priority)
2. Environment variables (with CHAT_SERVER_ prefix)
3. Configuration file (properties format)
4. Default values (lowest priority)

Command Line Arguments:
  --config            Path to config file (properties format)
  --mode              Server mode: socket, http, or both (default: both)
  --socket-host       Socket server hostname (default: 127.0.0.1)
  --socket-port       Socket server port (default: 10010)
  --http-host         HTTP server hostname (default: 127.0.0.1)
  --http-port         HTTP server port (default: 8000)
  --max-clients       Maximum client connections (default: 100)
  --max-message-length Maximum message length (default: 255)
  --use-ssl           Enable SSL/TLS encryption
  --cert-path         Path to SSL certificate (required if use-ssl is enabled)

Environment Variables:
  CHAT_SERVER_MODE              Server mode
  CHAT_SERVER_SOCKET_HOST       Socket server hostname
  CHAT_SERVER_SOCKET_PORT       Socket server port
  CHAT_SERVER_HTTP_HOST         HTTP server hostname
  CHAT_SERVER_HTTP_PORT         HTTP server port
  CHAT_SERVER_MAX_CLIENTS       Maximum client connections
  CHAT_SERVER_MAX_MESSAGE_LENGTH Maximum message length
  CHAT_SERVER_CONFIG_FILE       Path to config file
  CHAT_SERVER_USE_SSL           Enable SSL (true/1/yes)
  CHAT_SERVER_CERT_PATH         Path to SSL certificate

Configuration File Format (properties):
  [chatserver]
  mode = both
  socket_host = 127.0.0.1
  socket_port = 10010
  http_host = 127.0.0.1
  http_port = 8000
  max_clients = 100
  max_message_length = 255
  use_ssl = false
  cert_path =

Written by Claude.
"""

import asyncio
import logging
import sys
from typing import Optional

import uvicorn

# Add the current directory to the Python path
sys.path.insert(0, ".")
try:
    from src.api import create_app
    from src.asgi import app as asgi_app
    from src.config import ServerConfig
    from src.stream import ChatServer
except ImportError:
    # For local development when run directly
    from api import create_app
    from config import ServerConfig
    from stream import ChatServer

    try:
        from asgi import app as asgi_app
    except ImportError:
        asgi_app = None


async def run_socket_server(
    host: str = "127.0.0.1",
    port: int = 10010,
    max_clients: int = 100,
    max_message_length: int = 255,
    use_ssl: Optional[bool] = None,
    cert_path: Optional[str] = None,
) -> None:
    """
    Run the TCP socket server.

    Initializes and starts the async TCP socket server for raw client connections.
    This server handles client registration, chat room operations, and message
    broadcasting through direct socket connections.

    Args:
        host: Hostname to bind to (default: 127.0.0.1)
        port: Port to bind to (default: 10010)
        max_clients: Maximum client connections (default: 100)
        max_message_length: Maximum message length (default: 255)
        use_ssl: Enable SSL/TLS encryption (default: None)
        cert_path: Path to SSL certificate (required if use_ssl=True)

    Written by Claude.
    """
    logging.basicConfig(level=logging.INFO)
    chat_server = ChatServer(
        host=host,
        port=str(port),  # Convert to string as required by ChatServer
        max_clients=max_clients,
        max_message_length=max_message_length,
        use_ssl=use_ssl,
        cert_path=cert_path,
    )
    server = await chat_server.run_server()
    async with server:
        await server.serve_forever()


def run_asgi_server(
    host: str = "127.0.0.1",
    port: int = 8000,
    chat_server: Optional[ChatServer] = None,
) -> None:
    """
    Run the ASGI FastAPI server.

    Initializes and starts the FastAPI HTTP server with ASGI. This server provides
    REST API endpoints for interacting with the chat server functionality, including
    client registration, message sending, and chat room operations.

    Args:
        host: Hostname to bind to (default: 127.0.0.1)
        port: Port to bind to (default: 8000)
        chat_server: Optional ChatServer instance to use. If None, a new one is created.

    Written by Claude.
    """
    if asgi_app is not None:
        # Use existing ASGI app
        app = asgi_app
    else:
        # Create new FastAPI app
        app = create_app(chat_server)

    uvicorn.run(app, host=host, port=port)


async def run_both_servers(
    http_host: str = "127.0.0.1",
    http_port: int = 8000,
    socket_host: str = "127.0.0.1",
    socket_port: int = 10010,
    max_clients: int = 100,
    max_message_length: int = 255,
    use_ssl: Optional[bool] = None,
    cert_path: Optional[str] = None,
) -> None:
    """
    Run both ASGI (HTTP) and socket servers simultaneously.

    Creates a shared ChatServer instance and runs both the TCP socket server
    and FastAPI HTTP server concurrently. This allows clients to connect and
    interact with the chat system using either raw socket connections or
    REST API calls, with all operations affecting the same shared state.

    Args:
        http_host: Hostname for HTTP server (default: 127.0.0.1)
        http_port: Port for HTTP server (default: 8000)
        socket_host: Hostname for socket server (default: 127.0.0.1)
        socket_port: Port for socket server (default: 10010)
        max_clients: Maximum client connections (default: 100)
        max_message_length: Maximum message length (default: 255)
        use_ssl: Enable SSL/TLS encryption (default: None)
        cert_path: Path to SSL certificate (required if use_ssl=True)

    Written by Claude.
    """
    logging.basicConfig(level=logging.INFO)

    # Create shared ChatServer instance
    chat_server = ChatServer(
        host=socket_host,
        port=str(socket_port),
        max_clients=max_clients,
        max_message_length=max_message_length,
        use_ssl=use_ssl,
        cert_path=cert_path,
    )

    # Create FastAPI app with the shared ChatServer
    app = create_app(chat_server)

    # Start socket server in background
    socket_server = await chat_server.run_server()

    # Configure ASGI/HTTP server
    config = uvicorn.Config(app, host=http_host, port=http_port)
    server = uvicorn.Server(config)

    # Run both servers
    async with socket_server:
        await asyncio.gather(socket_server.serve_forever(), server.serve())


if __name__ == "__main__":
    # Load configuration from all sources
    config = ServerConfig()

    # Check for invalid SSL configuration
    if config.use_ssl and not config.cert_path:
        logging.error("SSL is enabled but no certificate path provided.")
        sys.exit(1)

    # Run the appropriate server mode
    if config.mode == "socket":
        asyncio.run(
            run_socket_server(
                host=config.socket_host,
                port=config.socket_port,
                max_clients=config.max_clients,
                max_message_length=config.max_message_length,
                use_ssl=config.use_ssl,
                cert_path=config.cert_path,
            )
        )
    elif config.mode == "http":
        run_asgi_server(
            host=config.http_host,
            port=config.http_port,
        )
    elif config.mode == "both":
        asyncio.run(
            run_both_servers(
                http_host=config.http_host,
                http_port=config.http_port,
                socket_host=config.socket_host,
                socket_port=config.socket_port,
                max_clients=config.max_clients,
                max_message_length=config.max_message_length,
                use_ssl=config.use_ssl,
                cert_path=config.cert_path,
            )
        )
