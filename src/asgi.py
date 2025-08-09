"""
ASGI configuration for chat server.

Provides WebSocket endpoints for client connections.
Written by Claude.
"""

import sys
from typing import Dict, Tuple

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

# Add the current directory to the Python path
sys.path.insert(0, ".")
try:
    from src.api import create_app
except ImportError:
    # For local development when run directly
    from api import create_app


class ConnectionManager:
    """
    WebSocket connection manager.

    Handles active WebSocket connections and maps them to FastAPI endpoints.

    Written by Claude.
    """

    def __init__(self, app: FastAPI):
        self.app = app
        self.active_connections: Dict[str, Tuple[WebSocket, str]] = {}

    async def connect(self, websocket: WebSocket, client_id: str, chat_room: str):
        """
        Connect a new WebSocket client.

        Args:
            websocket: WebSocket connection
            client_id: Client identifier
            chat_room: Chat room to join

        Written by Claude.
        """
        await websocket.accept()
        self.active_connections[client_id] = (websocket, chat_room)

    async def send_message(self, client_id: str, message: str):
        """
        Send a message to a specific client.

        Args:
            client_id: Target client ID
            message: Message to send

        Written by Claude.
        """
        if client_id in self.active_connections:
            websocket, _ = self.active_connections[client_id]
            if websocket.client_state == WebSocketState.CONNECTED:
                try:
                    await websocket.send_text(message)
                except WebSocketDisconnect:
                    await self.disconnect(client_id)

    async def disconnect(self, client_id: str):
        """
        Disconnect a WebSocket client.

        Args:
            client_id: Client identifier

        Written by Claude.
        """
        if client_id in self.active_connections:
            websocket, _ = self.active_connections[client_id]
            if websocket.client_state != WebSocketState.DISCONNECTED:
                await websocket.close()
            del self.active_connections[client_id]

    async def broadcast(self, message: str, chat_room: str):
        """
        Broadcast message to all clients in a room.

        Args:
            message: Message to broadcast
            chat_room: Target chat room

        Written by Claude.
        """
        for client_id, (websocket, room) in self.active_connections.items():
            if room == chat_room and websocket.client_state == WebSocketState.CONNECTED:
                try:
                    await websocket.send_text(message)
                except WebSocketDisconnect:
                    await self.disconnect(client_id)


# Create API app and WebSocket manager
app = create_app()
manager = ConnectionManager(app)


@app.websocket("/ws/{client_id}/{chat_room}")
async def websocket_endpoint(websocket: WebSocket, client_id: str, chat_room: str):
    """
    WebSocket endpoint for client connections.

    Args:
        websocket: WebSocket connection
        client_id: Client identifier
        chat_room: Chat room to join

    Written by Claude.
    """
    try:
        await manager.connect(websocket, client_id, chat_room)
        await websocket.send_text(str({"type": "register", "status": "registered"}))

        while True:
            message = await websocket.receive_text()
            if message.startswith("SEND "):
                message_data = message[5:]
                await manager.broadcast(message_data, chat_room)
                await websocket.send_text(str({"type": "send", "status": "sent"}))
            elif message == "QUIT":
                break

    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(client_id)
        await websocket.send_text(str({"type": "close", "status": "closed"}))
