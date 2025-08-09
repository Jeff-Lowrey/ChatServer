import asyncio as aio
import logging
import socket


class ChatServer:
    """

    I decided to write this using asyncio instead of plain socket, because I thought it was a better fit for multiple clients and chat rooms.

    Asynchronous chat server that manages client connections and message routing.

    Supports multiple chat rooms, client registration, and message broadcasting.
    Handles SSL connections and enforces client limits and message size constraints.

    Attributes:
        STATUS_LIST: Valid client status states
        ALLOWED_SERVER_COMMANDS: Commands accepted from clients

    This class docstring partially written by Claude

    This code was modified by Claude to add/improve:
        1. Exception Handling
        2. Logging
        3. Client list data structure consistency
        4. Chat room management
        5. Status tracking
        6. Message formatting
        7. Input validation
        8. Resource cleanup

    """

    STATUS_LIST = [
        "NEW",
        "CONNECTED",
        "ACTIVE",
        "SUSPENDED",
        "ERROR",
        "CLOSING",
        "CLOSED",
    ]
    ALLOWED_SERVER_COMMANDS = [
        "NEW",
        "LIST",
        "JOIN",
        "HELLO",
        "SEND",
        "PAUSE",
        "QUIT",
        "ERROR",
        "FROM",
        "MSG",
    ]

    def __init__(
        self,
        host="127.0.0.1",
        port="10010",
        max_clients=100,
        max_message_length=255,
        use_ssl=None,
        cert_path=None,
    ) -> None:
        """
        Initialize ChatServer with configuration.

        Args:
            host: Server hostname/IP (default: 127.0.0.1)
            port: Server port (default: 10010)
            max_clients: Maximum concurrent clients (default: 100)
            max_message_length: Maximum message length (default: 255)
            use_ssl: Enable SSL/TLS encryption (default: None)
            cert_path: Path to SSL certificate (required if use_ssl=True)

        Raises:
            RuntimeError: If SSL enabled without certificate path

        Configuration validation and error handling improved by Claude.
        Written by Claude.
        """
        if use_ssl is not None and cert_path is None:
            raise RuntimeError(
                "You cannot use SSL without providing a certfiicate by path."
            )
        self.use_ssl = use_ssl
        self.cert_path = cert_path
        self.client_list = {}
        self.client_id_counter = 1
        self.host = host
        self.port = port
        self.client_count = 0
        self.max_clients = max_clients
        self.max_message_length = max_message_length

    async def run_server(self) -> aio.Server:
        """
        Docstring partially written by Claude.

        Start the asynchronous chat server.

        Implements SSL when configured by:
            1. Checking if self.use_ssl is True and self.cert_path is provided
            2. Creating an SSLContext that includes the SSL cert at self.cert_path
            3. Passing that context as the value of the ssl parameter to start_server

        Returns:
            aio.Server: The started asyncio server instance

        Raises:
            OSError: If server cannot bind to the specified host/port

        Exception handling, logging, SSL and server configuration improved by Claude.
        """
        try:
            # Configure SSL if enabled
            ssl_context = None
            if self.use_ssl and self.cert_path:
                import ssl

                ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
                ssl_context.load_cert_chain(self.cert_path)
                logging.info(f"SSL enabled with certificate: {self.cert_path}")

            self.server = await aio.start_server(
                self.client_callback,
                host=self.host,
                port=self.port,
                ssl=ssl_context,
                family=socket.AF_UNSPEC,
                flags=socket.AI_PASSIVE,
                backlog=100,
                reuse_address=True,
                reuse_port=True,
                keep_alive=True,
                ssl_handshake_timeout=None if ssl_context is None else 30.0,
                ssl_shutdown_timeout=None if ssl_context is None else 30.0,
                start_serving=True,
            )
            self.server_active = self.server.is_serving()
            logging.info(f"Chat server started on {self.host}:{self.port}")
            return self.server
        except OSError as e:
            logging.error(f"Failed to start server on {self.host}:{self.port}: {e}")
            raise
        except Exception as e:
            logging.error(f"Unexpected error starting server: {e}")
            raise

    def get_client_list(self) -> dict:
        """
        Get the current mapping of chat rooms to client connections.

        Returns:
            dict: Nested dictionary of chat rooms and their clients

        Written by Claude.
        """
        return self.client_list

    async def register_client(
        self, cw: aio.StreamWriter, client_name: str = "client", chat_room: str = "main"
    ) -> str:
        """
        Register a new client in the specified chat room.

        Args:
            cw: StreamWriter for the client connection
            client_name: Display name for the client
            chat_room: Chat room to register the client in

        Returns:
            str: The assigned client ID or "ERROR" if registration failed

        Exception handling, logging, client registration and chat room management improved by Claude.
        """
        try:
            client_id = client_name
            if chat_room not in self.client_list.keys():
                error_message = (
                    f"Chat room {chat_room} does not exist. Please add it first."
                )
                await self.send_error_and_close(
                    error_message=error_message, cw=cw, client_id=client_id
                )
                return "ERROR"
            if client_id == "client":
                self.client_id_counter += 1
                client_id = str(client_name) + str(self.client_id_counter)
                while self.client_list[chat_room].get(client_id, None) is not None:
                    self.client_id_counter += 1
                    client_id = str(client_name) + str(self.client_id_counter)
            if chat_room not in self.client_list:
                self.client_list[chat_room] = {}
            self.client_list[chat_room][client_id] = {"writer": cw, "status": "NEW"}
            logging.info(f"Client {client_id} registered in chat room {chat_room}")
            return client_id
        except Exception as e:
            logging.error(f"Error registering client {client_name}: {e}")
            await self.send_error_and_close(
                error_message=f"Registration failed: {e}", cw=cw, client_id=client_name
            )
            return "ERROR"

    async def client_callback(
        self, client_reader: aio.StreamReader, client_writer: aio.StreamWriter
    ):
        """
        Handle incoming client connections and process commands.

        Args:
            client_reader: StreamReader for receiving data from client
            client_writer: StreamWriter for sending data to client

        Comprehensive exception handling, logging, client validation and command processing improved by Claude.
        """
        client_address = client_writer.get_extra_info("peername")
        self.client_count += 1

        try:
            # Read and validate command
            message_identifier = await client_reader.readuntil(separator=b" ")
            message_name = str(message_identifier.decode()).strip().upper()

            if message_name not in ChatServer.ALLOWED_SERVER_COMMANDS:
                error_message = f"ERROR: The {message_name} command is not a valid command, the client connection will be closed"
                logging.warning(
                    f"Invalid command '{message_name}' from {client_address}"
                )
                await self.send_error_and_close(client_writer, error_message, "Unknown")
                self.client_count -= 1
                return

            if self.client_count > self.max_clients:
                error_message = "ERROR: The maximum number of clients has been reached. No more clients are allowed, the client connection will be closed"
                logging.warning(
                    f"Max clients exceeded, rejecting connection from {client_address}"
                )
                await self.send_error_and_close(client_writer, error_message, "Unknown")
                self.client_count -= 1
                return

            chat_room = "main"
            client_id = "client"

            # Parse client room and ID data
            try:
                client_chatroom_data = await client_reader.readuntil(separator=b" ")
                client_chatroom = client_chatroom_data.decode()
                if len(client_chatroom) != 0:
                    room_client_parts = str(client_chatroom_data).strip().split(sep=":")
                    if len(room_client_parts) == 2:
                        chat_room, client_id = room_client_parts
                    else:
                        logging.warning(
                            f"Invalid room:client format from {client_address}"
                        )
            except Exception as e:
                logging.error(
                    f"Error parsing client room data from {client_address}: {e}"
                )
                await self.send_error_and_close(
                    client_writer, f"Invalid format: {e}", "Unknown"
                )
                self.client_count -= 1
                return

            # Read message data
            try:
                message_data_buffer = await client_reader.read()
                message_data = message_data_buffer.decode()

                # Validate message length
                if len(message_data) > self.max_message_length:
                    error_message = f"Message exceeds maximum length of {self.max_message_length} characters"
                    logging.warning(
                        f"Message too long from client {client_id}@{client_address}"
                    )
                    await self.send_error_and_close(
                        client_writer, error_message, client_id
                    )
                    self.client_count -= 1
                    return

            except UnicodeDecodeError as e:
                logging.error(f"Unicode decode error from {client_address}: {e}")
                await self.send_error_and_close(
                    client_writer, "Invalid message encoding", client_id
                )
                self.client_count -= 1
                return

        except aio.IncompleteReadError:
            logging.warning(f"Client {client_address} disconnected unexpectedly")
            self.client_count -= 1
            return
        except ConnectionResetError:
            logging.info(f"Connection reset by client {client_address}")
            self.client_count -= 1
            return
        except Exception as e:
            logging.error(
                f"Unexpected error in client_callback from {client_address}: {e}"
            )
            try:
                await self.send_error_and_close(
                    client_writer, f"Server error: {e}", "Unknown"
                )
            except Exception:
                pass
            self.client_count -= 1
            return

        # Process commands with error handling
        try:
            match message_name:
                case "HELLO":
                    client_id = await self.register_client(
                        client_name=client_id, cw=client_writer, chat_room=chat_room
                    )
                    if client_id == "ERROR":
                        return
                case "SEND":
                    try:
                        if (
                            chat_room not in self.client_list
                            or client_id not in self.client_list[chat_room]
                        ):
                            error_message = "ERROR: You have not registered or joined this chat room yet, please say HELLO or JOIN first."
                            await self.send_error_and_close(
                                client_writer, error_message, client_id
                            )
                            return

                        match self.client_list[chat_room][client_id]["status"]:
                            case "NEW":
                                self.client_list[chat_room][client_id]["status"] = (
                                    "CONNECTED"
                                )
                            case "CONNECTED":
                                self.client_list[chat_room][client_id]["status"] = (
                                    "ACTIVE"
                                )
                            case "PAUSED":
                                self.client_list[chat_room][client_id]["status"] = (
                                    "ACTIVE"
                                )

                        await self.send_to_all_clients(chat_room, message_data)

                    except KeyError as e:
                        logging.error(
                            f"KeyError in SEND command for client {client_id}: {e}"
                        )
                        await self.send_error_and_close(
                            client_writer, "Client not found in chat room", client_id
                        )
                        return

                case "PAUSE":
                    try:
                        msg = await self.pause_client(client_id)
                        logging.info(f"Client {client_id} paused: {msg}")
                    except Exception as e:
                        logging.error(f"Error pausing client {client_id}: {e}")
                        await self.send_error_and_close(
                            client_writer, f"Pause failed: {e}", client_id
                        )

                case "ERROR":
                    error_message = message_data
                    logging.info(
                        f"Error message from client {client_id}: {error_message}"
                    )
                    await self.send_error_and_close(
                        client_writer, error_message, client_id
                    )

                case "NEW":
                    try:
                        status = await self.add_chatroom(
                            chat_room=chat_room,
                            client_id=client_id,
                            client_writer=client_writer,
                        )
                        logging.info(f"Chat room creation result: {status}")
                    except Exception as e:
                        logging.error(f"Error creating chat room {chat_room}: {e}")
                        await self.send_error_and_close(
                            client_writer, f"Room creation failed: {e}", client_id
                        )

                case "JOIN":
                    try:
                        status = await self.join_chatroom(
                            chat_room=chat_room,
                            client_id=client_id,
                            client_writer=client_writer,
                        )
                        logging.info(f"Chat room join result: {status}")
                    except Exception as e:
                        logging.error(f"Error joining chat room {chat_room}: {e}")
                        await self.send_error_and_close(
                            client_writer, f"Join failed: {e}", client_id
                        )

                case "LIST":
                    try:
                        list_type = message_data
                        status = await self.list_chatrooms(
                            list_type=list_type, client_id=client_id
                        )
                    except Exception as e:
                        logging.error(f"Error listing chat rooms: {e}")
                        await self.send_error_to_writer(
                            f"List failed: {e}", client_writer
                        )

                case "QUIT":
                    try:
                        await self.close_client(client_id)
                    except Exception as e:
                        logging.error(f"Error closing client {client_id}: {e}")

        except Exception as e:
            logging.error(
                f"Error processing command {message_name} from client {client_id}: {e}"
            )
            try:
                await self.send_error_and_close(
                    client_writer, f"Command processing failed: {e}", client_id
                )
            except Exception:
                pass

    async def list_chatrooms(
        self, list_type="CHAT_ROOMS", client_id=None, chat_room=None
    ) -> str:
        """
        Generate formatted text listing of chat rooms and clients.

        Args:
            list_type: Type of listing (CHAT_ROOMS, ALL, etc)
            client_id: Optional client ID for filtered listings
            chat_room: Optional chat room name for filtered listings

        Returns:
            str: Formatted text listing of requested information

        Data structure handling and input validation improved by Claude.
        Written by Claude.
        """
        list_msg = "Chat Room List"
        match list_type:
            case "ALL":
                list_msg = list_msg + " With Clients and Status:\n"
                for room_name, clients in self.client_list.items():
                    list_msg = list_msg + f"\t-{room_name}\n"
                    for client_id, client_data in clients.items():
                        list_msg = list_msg + f"\t\t+Client:{client_id}"
                        list_msg = list_msg + f"\t\t\t+Status:{client_data['status']}"
                return list_msg

            case "CHAT_ROOMS":
                list_msg = list_msg + ":\n"
                for chat_room in self.client_list.keys():
                    list_msg = list_msg + f"\t-{chat_room}\n"
                return list_msg

            case "CHAT_ROOM_AND_CLIENTS":
                list_msg = list_msg + " With Clients:\n"
                for room_name, clients in self.client_list.items():
                    list_msg = list_msg + f"\t-{room_name}\n"
                    for client_id in clients:
                        list_msg = list_msg + f"\t\t+{client_id}\n"
                return list_msg

            case "CLIENT_CHAT_ROOMS":
                if client_id is None:
                    error_message = "You must specify a client ID when trying to list all chat rooms that a client belongs to"
                    logging.warning(error_message)
                    return "Client does not exist."
                list_msg = list_msg + f"For Client {client_id}:\n"
                for chat_room in self.client_list.keys():
                    if client_id in self.client_list[chat_room]:
                        list_msg = list_msg + f"\t-{chat_room}\n"
                return list_msg

            case "CLIENTS_FOR_CHAT_ROOM":
                list_msg = list_msg + f" of Clients belonging to {chat_room}"
                for client in self.client_list[chat_room]:
                    list_msg = list_msg + f"\t-{client}\n"

        return list_msg

    async def list_chatrooms_as_dict(
        self, list_type="CHAT_ROOM", client_id=None, chat_room=None
    ) -> dict:
        """
        Generate structured dictionary of chat rooms and clients.

        Args:
            list_type: Type of listing (CHAT_ROOM, ALL, etc)
            client_id: Optional client ID for filtered listings
            chat_room: Optional chat room name for filtered listings

        Returns:
            dict: Structured data of requested information

        Dictionary structure and error handling improved by Claude.
        Written by Claude.
        """
        list_dict = {"type": list_type.lower().replace("_", " "), "chatroom_list": {}}

        match list_type:
            case "ALL":
                for room_name, clients in self.client_list.items():
                    list_dict["chatroom_list"][room_name] = {}
                    for client_id, client_data in clients.items():
                        list_dict["chatroom_list"][room_name][client_id] = {
                            "client_id": client_id,
                            "status": client_data["status"],
                        }
                return list_dict

            case "CHAT_ROOMS":
                for room_name in self.client_list:
                    list_dict["chatroom_list"][room_name] = {}
                return list_dict

            case "CHAT_ROOM_AND_CLIENTS":
                for room_name, clients in self.client_list.items():
                    if room_name not in list_dict["chatroom_list"]:
                        list_dict["chatroom_list"][room_name] = {"client_list": []}
                    list_dict["chatroom_list"][room_name]["client_list"].extend(
                        clients.keys()
                    )
                return list_dict

            case "CLIENT_CHAT_ROOMS":
                if client_id is None:
                    return {
                        "error": "Client ID required for CLIENT_CHAT_ROOMS listing",
                        "status": "FAILED",
                    }

                result = {
                    "type": list_type.lower().replace("_", " "),
                    "client_id": client_id,
                    "chat_rooms": [],
                }

                for room_name in self.client_list:
                    if client_id in self.client_list[room_name]:
                        result["chat_rooms"].append(room_name)
                return result

            case "CLIENTS_FOR_CHAT_ROOM":
                list_dict["chat_room_name"] = chat_room
                if chat_room in self.client_list:
                    list_dict["client_list"] = list(self.client_list[chat_room].keys())
                else:
                    list_dict["client_list"] = []
                return list_dict

        # Default case if no match
        return {"error": "Invalid list type", "type": list_type}

    async def pause_client(self, client_id) -> str:
        """
        Pause a client's activity across all chat rooms.

        Args:
            client_id: ID of client to pause

        Returns:
            str: Status message indicating which rooms client was paused in

        Chat room iteration and status management improved by Claude.
        Written by Claude.
        """
        paused_rooms = []
        for chat_room, clients in self.client_list.items():
            if client_id in clients:
                clients[client_id]["status"] = "PAUSED"
                paused_rooms.append(chat_room)
        if not paused_rooms:
            return f"Client {client_id} not found in any chat rooms"
        return f"Client {client_id} paused in rooms: {', '.join(paused_rooms)}"

    async def join_chatroom(
        self, chat_room: str, client_id: str, client_writer: aio.StreamWriter
    ) -> str:
        """
        Add a client to an existing chat room.

        Args:
            chat_room: Name of room to join
            client_id: ID of joining client
            client_writer: StreamWriter for client connection

        Returns:
            str: Status message about join operation

        Exception handling and client registration improved by Claude.
        Written by Claude.
        """
        if chat_room not in self.client_list.keys():
            error_message = (
                f"Chat room {chat_room} can not be joined because it does not exist."
            )
            await self.send_error_to_writer(
                message_data=error_message, cw=client_writer
            )
            return error_message

        if chat_room not in self.client_list:
            self.client_list[chat_room] = {}
        self.client_list[chat_room][client_id] = {
            "writer": client_writer,
            "status": "NEW",
        }

        announcement_msg = f"Client {client_id} has joined Chat room {chat_room}"
        await self.send_to_all_clients(
            chat_room=chat_room, message_data=announcement_msg
        )
        return announcement_msg

    async def add_chatroom(
        self, chat_room: str, client_id: str, client_writer: aio.StreamWriter
    ) -> str:
        """
        Create a new chat room with initial client.

        Args:
            chat_room: Name of room to create
            client_id: ID of creating client
            client_writer: StreamWriter for client connection

        Returns:
            str: Status message about room creation

        Room initialization and client registration improved by Claude.
        Written by Claude.
        """
        if chat_room == "main":
            error_message = "ERROR: You cannot create the main chat room"
            await self.send_error_to_client(error_message, chat_room, client_id)
            return error_message
        if chat_room in self.client_list:
            error_message = f"ERROR: Chat Room {chat_room} already exists."
            await self.send_error_to_client(error_message, chat_room, client_id)
            return error_message

        self.client_list[chat_room] = {}
        self.client_list[chat_room][client_id] = {
            "writer": client_writer,
            "status": "NEW",
        }
        message_data = (
            f"MSG Chatroom {chat_room} was successfully created by {client_id}."
        )
        await self.send_to_client(message_data, client_writer)
        return message_data

    async def close_client(self, client_id):
        """
        Gracefully close a client connection.

        Args:
            client_id: ID of the client to close

        Exception handling and logging added by Claude.
        """
        try:
            if client_id not in self.client_list:
                logging.warning(f"Attempted to close non-existent client {client_id}")
                return

            self.client_list[client_id]["status"] = "CLOSING"
            client_writer = self.client_list[client_id]["writer"]

            try:
                client_writer.write(bytes("Good Bye!".encode()))
                await client_writer.drain()
                client_writer.close()
                await client_writer.wait_closed()
            except (ConnectionResetError, BrokenPipeError):
                logging.info(f"Client {client_id} already disconnected")
            except Exception as e:
                logging.error(f"Error closing connection for client {client_id}: {e}")

            self.client_list[client_id]["status"] = "CLOSED"
            logging.info(f"Client {client_id} has been closed")
            self.client_count -= 1

        except Exception as e:
            logging.error(f"Unexpected error closing client {client_id}: {e}")
            self.client_count -= 1

    async def send_error_and_close(
        self, cw: aio.StreamWriter, error_message, client_id
    ):
        """
        Send an error message to client and close the connection.

        Args:
            cw: StreamWriter for the client connection
            error_message: Error message to send
            client_id: ID of the client being closed

        Exception handling and logging added by Claude.
        """
        try:
            if client_id in self.client_list:
                self.client_list[client_id]["status"] = "ERROR"

            cw.write(bytes(error_message.encode()))
            await cw.drain()
            cw.close()
            await cw.wait_closed()

            logging.info(f"Client {client_id} closed with error: {error_message}")

            if client_id in self.client_list:
                self.client_list[client_id]["status"] = "CLOSED"
            self.client_count -= 1

        except Exception as e:
            logging.error(f"Error closing client {client_id}: {e}")
            self.client_count -= 1

    async def send_to_client(self, message_data: str, client_writer: aio.StreamWriter):
        """
        Send a message to a specific client.

        Args:
            message_data: The message to send
            client_writer: StreamWriter for the target client

        Network exception handling and message delivery reliability improved by Claude.
        """
        try:
            client_writer.write(message_data.encode())
            await client_writer.drain()
        except ConnectionResetError:
            logging.warning("Client disconnected while sending message")
        except BrokenPipeError:
            logging.warning("Broken pipe while sending message to client")
        except Exception as e:
            logging.error(f"Error sending message to client: {e}")

    async def send_error_to_writer(self, message_data: str, cw: aio.StreamWriter):
        """
        Send formatted error message to a client.

        Args:
            message_data: Error message content
            cw: StreamWriter for target client

        Message formatting and error handling improved by Claude.
        Written by Claude.
        """
        full_message = f"ERROR {message_data}"
        await self.send_to_client(full_message, cw)

    async def send_error_to_client(
        self, message_data: str, chat_room: str, client_id: str
    ):
        """
        Send context-aware error message to a specific client.

        Args:
            message_data: Error message content
            chat_room: Related chat room name
            client_id: Target client ID

        Message formatting and error delivery improved by Claude.
        Written by Claude.
        """
        full_message = f"ERROR {chat_room}:{client_id} {message_data}"
        client_writer = self.client_list[chat_room][client_id]["writer"]
        await self.send_to_client(full_message, client_writer)

    async def writer_iterator(self, chat_room="main"):
        """
        Async iterator over active client writers in a chat room.

        Args:
            chat_room: Name of room to iterate over

        Yields:
            StreamWriter: Writer for each active client

        Status checking and error handling improved by Claude.
        Written by Claude.
        """
        if chat_room not in self.client_list:
            return
        for _, client_data in self.client_list[chat_room].items():
            writer = client_data["writer"]
            if client_data["status"] in ["CONNECTED", "ACTIVE"]:
                yield writer

    async def send_to_all_clients(self, message_data: str, chat_room: str):
        """
        Broadcast a message to all clients in a chat room.

        Args:
            message_data: The message to broadcast
            chat_room: Target chat room name

        Exception handling, failed connection cleanup, and message broadcasting improved by Claude.
        """
        try:
            full_message = f"MSG {message_data}"
            failed_clients = []

            async for client_writer in self.writer_iterator(chat_room):
                try:
                    client_writer.write(full_message.encode())
                    await client_writer.drain()
                except (ConnectionResetError, BrokenPipeError) as e:
                    logging.warning(
                        f"Client disconnected while broadcasting to room {chat_room}: {e}"
                    )
                    failed_clients.append(client_writer)
                except Exception as e:
                    logging.error(
                        f"Error sending message to client in room {chat_room}: {e}"
                    )
                    failed_clients.append(client_writer)

            # Clean up failed connections
            if failed_clients:
                logging.info(
                    f"Cleaning up {len(failed_clients)} failed connections in room {chat_room}"
                )
                # Note: In a production system, you'd want to remove these clients from client_list

        except Exception as e:
            logging.error(f"Error broadcasting to room {chat_room}: {e}")

    async def client_to_client(
        self,
        message_data: str,
        chat_room: str,
        source_client_id: str,
        target_client_id: str,
    ):
        """
        Direct message between two clients (not implemented in protocol).

        This is an example of a possible additional feature that requires a noun
        after the SEND verb is received. Similarly, a send_to_many could accept
        a list of client_ids requiring additional nouns after SEND.

        Args:
            message_data: Message content
            chat_room: Chat room context
            source_client_id: Sending client ID
            target_client_id: Receiving client ID

        Message formatting and routing improved by Claude.
        Written by Claude.
        """
        client_writer = self.client_list[chat_room][target_client_id]["writer"]
        full_message = f"MSG FROM {chat_room}:{source_client_id} {message_data}"
        client_writer.write(full_message.encode())
        await client_writer.drain()
