import sys
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Add the current directory to the Python path
sys.path.insert(0, ".")
try:
    from src.stream import ChatServer
except ImportError:
    # For local development when run directly
    from stream import ChatServer


class RegisterClientRequest(BaseModel):
    """
    Request model for client registration.

    Attributes:
        client_name: Display name for the client (default: 'client')
        chat_room: Chat room to join (default: 'main')
        client_id: Unique client identifier (optional, auto-generated if not provided)

    Written by Claude.
    """

    client_name: str = "client"
    chat_room: str = "main"
    client_id: Optional[str] = None


class SendMessageRequest(BaseModel):
    """
    Request model for sending messages to chat rooms.

    Attributes:
        message_data: The message content to send
        chat_room: Target chat room name
        client_id: Unique identifier of the sending client

    Written by Claude.
    """

    message_data: str
    chat_room: str
    client_id: str


class ChatRoomRequest(BaseModel):
    """
    Request model for chat room operations (create/join).

    Attributes:
        chat_room: Name of the chat room to create or join
        client_id: Unique identifier of the requesting client

    Written by Claude.
    """

    chat_room: str
    client_id: str


class ListRequest(BaseModel):
    """
    Request model for listing chat rooms and clients.

    Attributes:
        list_type: Type of listing (CHAT_ROOMS, ALL, CHAT_ROOM_AND_CLIENTS, etc.)
        client_id: Optional client ID for client-specific listings
        chat_room: Optional chat room name for room-specific listings

    Written by Claude.
    """

    list_type: str = "CHAT_ROOMS"
    client_id: Optional[str] = None
    chat_room: Optional[str] = None


class ClientToClientRequest(BaseModel):
    """
    Request model for direct client-to-client messaging.

    Attributes:
        message_data: The message content to send
        chat_room: Chat room context for the message
        source_client_id: Unique identifier of the sending client
        target_client_id: Unique identifier of the receiving client

    Written by Claude.
    """

    message_data: str
    chat_room: str
    source_client_id: str
    target_client_id: str


class PauseClientRequest(BaseModel):
    """
    Request model for pausing a client's activity.

    Attributes:
        client_id: Unique identifier of the client to pause
        chat_room: Optional specific chat room (if not provided, affects all rooms)

    Written by Claude.
    """

    client_id: str
    chat_room: Optional[str] = None


class CloseClientRequest(BaseModel):
    """
    Request model for closing/disconnecting a client.

    Attributes:
        client_id: Unique identifier of the client to disconnect
        chat_room: Optional specific chat room (if not provided, affects all rooms)

    Written by Claude.
    """

    client_id: str
    chat_room: Optional[str] = None


class ChatAPI:
    """
    FastAPI wrapper for ChatServer providing REST endpoints.

    This class exposes ChatServer functionality through HTTP endpoints while maintaining
    the underlying async socket server functionality. Some endpoints require WebSocket
    connections and return 'not_implemented' status for pure REST operations.

    Attributes:
        app: FastAPI application instance
        chat_server: ChatServer instance for handling chat operations

    Written by Claude.
    """

    def __init__(self, chat_server: Optional[ChatServer] = None):
        """
        Initialize ChatAPI with optional ChatServer instance.

        Args:
            chat_server: Optional ChatServer instance. If None, creates a new one.

        Written by Claude.
        """
        self.app = FastAPI(title="Chat Server API", version="1.0.0")
        self.chat_server = chat_server if chat_server is not None else ChatServer()
        self.setup_routes()

    def setup_routes(self):
        """
        Configure all API endpoints and route handlers.

        Sets up REST endpoints for chat operations including client management,
        message sending, chat room operations, and server status.

        Written by Claude.
        """
        # Store function references to resolve diagnostic warnings
        endpoint_functions = []

        # Use endpoint_functions to satisfy linter
        self._endpoint_registry = endpoint_functions

        @self.app.get("/")
        async def root():
            """
            Root endpoint providing API information.

            Returns:
                dict: API name and version information

            Written by Claude.
            """
            return {"message": "Chat Server API", "version": "1.0.0"}

        endpoint_functions.append(root)

        @self.app.post("/clients/register")
        async def register_client(request: RegisterClientRequest):
            """
            Register a new client in a chat room.

            Args:
                request: RegisterClientRequest with client details

            Returns:
                dict: Registration status (requires WebSocket connection)

            Note: This endpoint requires WebSocket connection for full functionality.

            Written by Claude.
            """
            return {
                "error": "Client registration requires WebSocket connection",
                "status": "not_implemented",
                "requested_client_id": request.client_id or request.client_name,
                "requested_client_name": request.client_name,
                "requested_chat_room": request.chat_room,
            }

        endpoint_functions.append(register_client)

        @self.app.post("/messages/send")
        async def send_message(request: SendMessageRequest):
            """
            Send a message to all clients in a chat room.

            Args:
                request: SendMessageRequest with message data and target room

            Returns:
                dict: Message delivery status and client count

            Raises:
                HTTPException: If chat room not found or delivery fails

            Written by Claude.
            """
            try:
                client_list = self.chat_server.get_client_list()

                # Check if chat room exists
                if request.chat_room not in client_list:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Chat room '{request.chat_room}' not found",
                    )

                # Send message to all clients in the room
                await self.chat_server.send_to_all_clients(
                    message_data=request.message_data, chat_room=request.chat_room
                )

                # Get client count for response
                room_clients = client_list.get(request.chat_room, {})
                client_count = (
                    len(room_clients) if isinstance(room_clients, dict) else 0
                )

                return {
                    "status": "sent",
                    "message": request.message_data,
                    "chat_room": request.chat_room,
                    "clients_notified": client_count,
                }
            except HTTPException:
                # Re-raise HTTPException to preserve status code (especially 404)
                raise
            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(send_message)

        @self.app.post("/messages/client-to-client")
        async def client_to_client_message(request: ClientToClientRequest):
            """
            Send a direct message between clients.

            Args:
                request: ClientToClientRequest with message and client IDs

            Returns:
                dict: Not implemented status

            Note: This feature is not yet implemented in the protocol.

            Written by Claude.
            """
            return {
                "error": "Client-to-client messaging not implemented",
                "status": "not_implemented",
                "requested_source": request.source_client_id,
                "requested_target": request.target_client_id,
                "requested_room": request.chat_room,
            }

        endpoint_functions.append(client_to_client_message)

        @self.app.post("/chatrooms")
        async def create_chatroom(request: ChatRoomRequest):
            """
            Create a new chat room.

            Args:
                request: ChatRoomRequest with room name and client ID

            Returns:
                dict: Creation status (requires WebSocket connection)

            Note: This endpoint requires WebSocket connection for full functionality.

            Written by Claude.
            """
            return {
                "error": "Chat room creation requires WebSocket connection",
                "status": "not_implemented",
                "requested_room": request.chat_room,
                "requested_by": request.client_id,
            }

        endpoint_functions.append(create_chatroom)

        @self.app.post("/chatrooms/join")
        async def join_chatroom(request: ChatRoomRequest):
            """
            Join an existing chat room.

            Args:
                request: ChatRoomRequest with room name and client ID

            Returns:
                dict: Join status (requires WebSocket connection)

            Note: This endpoint requires WebSocket connection for full functionality.

            Written by Claude.
            """
            return {
                "error": "Joining chat room requires WebSocket connection",
                "status": "not_implemented",
                "requested_room": request.chat_room,
                "requested_by": request.client_id,
            }

        endpoint_functions.append(join_chatroom)

        @self.app.get("/chatrooms/list")
        async def list_chatrooms(
            list_type: str = "CHAT_ROOMS",
            client_id: Optional[str] = None,
            chat_room: Optional[str] = None,
        ):
            """
            List chat rooms based on specified type.

            Args:
                list_type: Type of listing (CHAT_ROOMS, ALL, etc.)
                client_id: Optional client ID for client-specific listings
                chat_room: Optional room name for room-specific listings

            Returns:
                dict: Chat room listings based on requested type

            Raises:
                HTTPException: If listing operation fails

            Written by Claude.
            """
            try:
                client_list = self.chat_server.get_client_list()

                if list_type == "CHAT_ROOMS":
                    return {"chat_rooms": list(client_list.keys())}
                elif list_type == "ALL":
                    result = {}
                    for room_name, clients in client_list.items():
                        result[room_name] = {
                            "clients": list(clients.keys())
                            if isinstance(clients, dict)
                            else [],
                            "client_count": len(clients)
                            if isinstance(clients, dict)
                            else 0,
                        }
                    return {"chat_rooms": result}
                elif list_type == "CHAT_ROOM_AND_CLIENTS":
                    result = {}
                    for room_name, clients in client_list.items():
                        result[room_name] = (
                            list(clients.keys()) if isinstance(clients, dict) else []
                        )
                    return {"chat_rooms": result}
                elif list_type == "CLIENT_CHAT_ROOMS" and client_id:
                    rooms = []
                    for room_name, clients in client_list.items():
                        if isinstance(clients, dict) and client_id in clients:
                            rooms.append(room_name)
                    return {"client_id": client_id, "chat_rooms": rooms}
                elif list_type == "CLIENTS_FOR_CHAT_ROOM" and chat_room:
                    if chat_room in client_list and isinstance(
                        client_list[chat_room], dict
                    ):
                        return {
                            "chat_room": chat_room,
                            "clients": list(client_list[chat_room].keys()),
                        }
                    else:
                        return {"chat_room": chat_room, "clients": []}
                else:
                    return {"error": "Invalid list_type or missing required parameters"}

            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(list_chatrooms)

        @self.app.get("/chatrooms/list-dict")
        async def list_chatrooms_dict(
            list_type: str = "CHAT_ROOMS",
            client_id: Optional[str] = None,
            chat_room: Optional[str] = None,
        ):
            """
            List chat rooms as structured dictionary.

            Args:
                list_type: Type of listing (CHAT_ROOMS, ALL, etc.)
                client_id: Optional client ID for client-specific listings
                chat_room: Optional room name for room-specific listings

            Returns:
                dict: Structured dictionary with chat room data

            Raises:
                HTTPException: If listing operation fails

            Written by Claude.
            """
            try:
                client_list = self.chat_server.get_client_list()

                result = {
                    "type": list_type.lower().replace("_", " "),
                    "chatroom_list": {},
                }

                if list_type == "CHAT_ROOMS":
                    result["chatroom_list"] = {room: {} for room in client_list.keys()}
                elif list_type == "ALL":
                    for room_name, clients in client_list.items():
                        result["chatroom_list"][room_name] = {}
                        if isinstance(clients, dict):
                            for client_id_key, client_info in clients.items():
                                result["chatroom_list"][room_name][client_id_key] = {
                                    "client_id": client_id_key,
                                    "status": client_info.get("status", "unknown")
                                    if isinstance(client_info, dict)
                                    else "unknown",
                                }
                elif list_type == "CHAT_ROOM_AND_CLIENTS":
                    for room_name, clients in client_list.items():
                        result["chatroom_list"][room_name] = {
                            "client_list": list(clients.keys())
                            if isinstance(clients, dict)
                            else []
                        }
                elif list_type == "CLIENT_CHAT_ROOMS" and client_id:
                    result["client_id"] = client_id
                    result["chat_rooms"] = []
                    for room_name, clients in client_list.items():
                        if isinstance(clients, dict) and client_id in clients:
                            result["chat_rooms"].append(room_name)
                elif list_type == "CLIENTS_FOR_CHAT_ROOM" and chat_room:
                    result["chat_room_name"] = chat_room
                    if chat_room in client_list and isinstance(
                        client_list[chat_room], dict
                    ):
                        result["client_list"] = list(client_list[chat_room].keys())
                    else:
                        result["client_list"] = []

                return result

            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(list_chatrooms_dict)

        @self.app.post("/clients/pause")
        async def pause_client(request: PauseClientRequest):
            """
            Pause a client's activity in chat rooms.

            Args:
                request: PauseClientRequest with client ID and optional room

            Returns:
                dict: Pause operation status and details

            Raises:
                HTTPException: If pause operation fails

            Written by Claude.
            """
            try:
                result = await self.chat_server.pause_client(request.client_id)
                return {
                    "status": "paused",
                    "client_id": request.client_id,
                    "chat_room": request.chat_room,
                    "message": result,
                }
            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(pause_client)

        @self.app.post("/clients/close")
        async def close_client(request: CloseClientRequest):
            """
            Close/disconnect a client from the server.

            Args:
                request: CloseClientRequest with client ID and optional room

            Returns:
                dict: Disconnection status and details

            Raises:
                HTTPException: If close operation fails

            Written by Claude.
            """
            try:
                await self.chat_server.close_client(request.client_id)
                return {
                    "status": "closed",
                    "client_id": request.client_id,
                    "chat_room": request.chat_room,
                }
            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(close_client)

        @self.app.get("/server/status")
        async def server_status():
            """
            Get comprehensive server status and statistics.

            Returns:
                dict: Server configuration, client counts, room details

            Written by Claude.
            """
            try:
                client_list = self.chat_server.get_client_list()
                total_clients = sum(
                    len(clients) if isinstance(clients, dict) else 0
                    for clients in client_list.values()
                )

                return {
                    "host": self.chat_server.host,
                    "port": self.chat_server.port,
                    "client_count": total_clients,
                    "max_clients": self.chat_server.max_clients,
                    "max_message_length": self.chat_server.max_message_length,
                    "use_ssl": self.chat_server.use_ssl,
                    "chat_rooms": [
                        {
                            "name": room,
                            "client_count": len(clients)
                            if isinstance(clients, dict)
                            else 0,
                            "clients": list(clients.keys())
                            if isinstance(clients, dict)
                            else [],
                        }
                        for room, clients in client_list.items()
                    ],
                }
            except Exception as e:
                raise HTTPException(status_code=400, detail={"error": str(e)})

        endpoint_functions.append(server_status)


def create_app(chat_server: Optional[ChatServer] = None) -> FastAPI:
    """
    Factory function to create FastAPI app with ChatServer.

    Args:
        chat_server: Optional ChatServer instance. If None, creates a new one.

    Returns:
        FastAPI: Configured FastAPI application instance with REST and WebSocket endpoints

    Written by Claude.
    """
    api = ChatAPI(chat_server)
    app = api.app

    # WebSocket endpoints are defined in asgi.py
    return app
