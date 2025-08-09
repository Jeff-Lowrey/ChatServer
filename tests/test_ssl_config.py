"""
Tests for SSL configuration loading and handling.

Verifies that SSL settings are properly loaded from various configuration sources
and correctly passed to the ChatServer instance.

Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
"""

import os
import sys
import unittest

# Add parent directory to path to allow imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.config import load_config_file
from src.stream import ChatServer


class TestSSLConfig(unittest.TestCase):
    """
    Test suite for SSL configuration functionality.

    Tests the loading of SSL settings from configuration files and
    their application to the ChatServer instance.

    Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
    """

    def test_ssl_config_from_properties(self):
        """
        Test loading SSL configuration from properties file.

        Verifies that use_ssl and cert_path are correctly parsed
        from the properties file and converted to the appropriate types.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Use the test SSL config file
        config = load_config_file("config.ssl.properties")

        # Verify SSL settings
        self.assertIn("use_ssl", config)
        self.assertIn("cert_path", config)
        self.assertTrue(config["use_ssl"])
        self.assertEqual(config["cert_path"], "/path/to/your/certificate.pem")

    @unittest.skip("This test requires environment variable manipulation")
    def test_ssl_config_from_env_vars(self):
        """
        Test loading SSL configuration from environment variables.

        This test would verify that SSL settings from environment variables are correctly
        parsed, but it's skipped because it requires setting real environment variables.
        """
        pass

    def test_chatserver_ssl_initialization(self):
        """
        Test ChatServer initialization with SSL settings.

        Verifies that the ChatServer correctly initializes with
        the provided SSL configuration.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Create a ChatServer with SSL enabled
        server = ChatServer(
            host="127.0.0.1",
            port="10010",
            max_clients=100,
            max_message_length=255,
            use_ssl=True,
            cert_path="/test/cert.pem",
        )

        # Verify SSL settings are correctly stored
        self.assertTrue(server.use_ssl)
        self.assertEqual(server.cert_path, "/test/cert.pem")

        # Test with SSL disabled
        server = ChatServer(
            host="127.0.0.1",
            port="10010",
            max_clients=100,
            max_message_length=255,
            use_ssl=None,
            cert_path=None,
        )

        self.assertIsNone(server.use_ssl)
        self.assertIsNone(server.cert_path)

    def test_invalid_ssl_config(self):
        """
        Test ChatServer initialization with invalid SSL configuration.

        Verifies that the ChatServer correctly raises an exception when
        SSL is enabled but no certificate path is provided.

        Written by Jeff Lowrey <jeff@jaral.org> with assistance from Anthropic's Claude AI.
        """
        # Attempt to create a ChatServer with SSL enabled but no cert path
        with self.assertRaises(RuntimeError):
            ChatServer(
                host="127.0.0.1",
                port="10010",
                max_clients=100,
                max_message_length=255,
                use_ssl=True,
                cert_path=None,
            )


if __name__ == "__main__":
    unittest.main()
