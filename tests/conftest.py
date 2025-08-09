"""
Pytest configuration and shared fixtures.

Provides fixtures for testing the chat server components.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
"""

import asyncio
import os
import sys

import pytest

# Add parent directory to path to allow imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.api import ChatAPI
from src.stream import ChatServer


@pytest.fixture
def chat_server():
    """
    Fixture providing a ChatServer instance.

    Returns a ChatServer with standard test configuration.

    Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
    """
    server = ChatServer(
        host="127.0.0.1", port="10010", max_clients=100, max_message_length=255
    )
    return server


@pytest.fixture
def chat_api(chat_server):
    """
    Fixture providing a ChatAPI instance.

    Returns a ChatAPI with a real ChatServer.

    Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
    """
    api = ChatAPI(chat_server)
    return api


@pytest.fixture
def event_loop():
    """
    Fixture providing an event loop for testing async code.

    Returns a new event loop for each test.

    Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
    """
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()
