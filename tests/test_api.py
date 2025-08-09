"""
Unit tests for the ChatAPI class in api.py.

Tests the FastAPI REST endpoints and request handling.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
"""

import os
import sys
import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

# Add parent directory to path to allow imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.api import ChatAPI, create_app
from src.stream import ChatServer


class TestChatAPI(unittest.TestCase):
    """
    Test suite for the ChatAPI class.

    Tests the FastAPI endpoints, request validation, and error handling.

    Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
    """

    def setUp(self):
        """
        Set up test environment before each test.

        Creates a ChatAPI instance with a real ChatServer and initializes
        a FastAPI TestClient for making test requests.
        """
        # Create a real ChatServer
        self.chat_server = ChatServer(
            host="127.0.0.1", port="10010", max_clients=100, max_message_length=255
        )

        # Create ChatAPI with the server
        self.chat_api = ChatAPI(self.chat_server)

        # Create TestClient for the FastAPI app
        self.client = TestClient(self.chat_api.app)

    def test_init(self):
        """
        Test ChatAPI initialization.

        Verifies that the ChatAPI is properly initialized with the correct
        attributes and that the routes are set up correctly.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Test with provided ChatServer
        self.assertEqual(self.chat_api.chat_server, self.chat_server)
        self.assertIsInstance(self.chat_api.app, FastAPI)
        self.assertIsNotNone(self.chat_api._endpoint_registry)

        # Test with default ChatServer (created automatically)
        api = ChatAPI()
        self.assertIsInstance(api.chat_server, ChatServer)

    def test_root_endpoint(self):
        """
        Test the root endpoint (GET /).

        Verifies that the root endpoint returns the correct API information.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(), {"message": "Chat Server API", "version": "1.0.0"}
        )

    def test_register_client(self):
        """
        Test the client registration endpoint (POST /clients/register).

        Verifies that client registration requests are handled correctly and
        that the appropriate response is returned.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Test with default values
        response = self.client.post("/clients/register", json={})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "not_implemented")
        self.assertEqual(data["requested_client_name"], "client")
        self.assertEqual(data["requested_chat_room"], "main")

        # Test with custom values
        response = self.client.post(
            "/clients/register",
            json={
                "client_name": "test_client",
                "chat_room": "test_room",
                "client_id": "custom_id",
            },
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "not_implemented")
        self.assertEqual(data["requested_client_id"], "custom_id")
        self.assertEqual(data["requested_client_name"], "test_client")
        self.assertEqual(data["requested_chat_room"], "test_room")

    def test_client_to_client_message(self):
        """
        Test the client-to-client messaging endpoint (POST /messages/client-to-client).

        Verifies that client-to-client messaging requests are handled correctly
        and that the appropriate response is returned.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        response = self.client.post(
            "/messages/client-to-client",
            json={
                "message_data": "Hello client2",
                "chat_room": "main",
                "source_client_id": "client1",
                "target_client_id": "client2",
            },
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "not_implemented")
        self.assertEqual(data["requested_source"], "client1")
        self.assertEqual(data["requested_target"], "client2")
        self.assertEqual(data["requested_room"], "main")

    def test_create_chatroom(self):
        """
        Test the chat room creation endpoint (POST /chatrooms).

        Verifies that chat room creation requests are handled correctly
        and that the appropriate response is returned.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        response = self.client.post(
            "/chatrooms", json={"chat_room": "new_room", "client_id": "client1"}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "not_implemented")
        self.assertEqual(data["requested_room"], "new_room")
        self.assertEqual(data["requested_by"], "client1")

    def test_join_chatroom(self):
        """
        Test the chat room joining endpoint (POST /chatrooms/join).

        Verifies that chat room joining requests are handled correctly
        and that the appropriate response is returned.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        response = self.client.post(
            "/chatrooms/join", json={"chat_room": "main", "client_id": "client1"}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "not_implemented")
        self.assertEqual(data["requested_room"], "main")
        self.assertEqual(data["requested_by"], "client1")


class TestAppFactory(unittest.TestCase):
    """
    Test suite for the create_app factory function.
    """

    def test_create_app(self):
        """
        Test the create_app factory function.

        Verifies that the create_app function correctly creates a FastAPI
        application with the proper configuration.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Test with provided ChatServer
        chat_server = ChatServer()
        app = create_app(chat_server)
        self.assertIsInstance(app, FastAPI)

        # Test with default ChatServer (None)
        app = create_app()
        self.assertIsInstance(app, FastAPI)


if __name__ == "__main__":
    unittest.main()
