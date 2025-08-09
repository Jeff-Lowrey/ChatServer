"""
Configuration management for the chat server application.

Provides functionality to load configuration from multiple sources:
1. Command line arguments (highest priority)
2. Environment variables (with CHAT_SERVER_ prefix)
3. Configuration file (properties format)
4. Default values (lowest priority)

Written by Claude.
"""

import argparse
import logging
import os
from configparser import ConfigParser
from pathlib import Path
from typing import Any, Dict, Optional


def load_config_file(config_file_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Load configuration from a properties file.

    Loads server configuration from a properties file if it exists. If no path is provided,
    checks for config.properties in the current directory and then in a system-appropriate
    config directory.

    Properties file format:
    [chatserver]
    mode = both
    socket_host = 127.0.0.1
    socket_port = 10010
    # etc.

    Args:
        config_file_path: Path to the config file (optional)

    Returns:
        dict: Configuration parameters from the file or empty dict if no file found

    Written by Claude.
    """
    # Default configuration
    config = {}

    # Create ConfigParser with case-sensitive keys
    parser = ConfigParser()

    # Define a function that preserves case of keys
    def preserve_case(optionstr: str) -> str:
        return optionstr

    parser.optionxform = preserve_case

    # Try user-specified config file first
    if config_file_path and Path(config_file_path).exists():
        try:
            parser.read(config_file_path)
            config = _extract_config_from_parser(parser)
            logging.info(f"Loaded configuration from {config_file_path}")
            return config
        except Exception as e:
            logging.warning(f"Error loading config file {config_file_path}: {e}")

    # Try default locations
    default_locations = [
        Path("config.properties"),  # Current directory
        Path.home() / ".config" / "chatserver" / "config.properties",  # User config dir
        Path("/etc/chatserver/config.properties"),  # System config dir
    ]

    for path in default_locations:
        if path.exists():
            try:
                parser.read(path)
                config = _extract_config_from_parser(parser)
                logging.info(f"Loaded configuration from {path}")
                return config
            except Exception as e:
                logging.warning(f"Error loading config file {path}: {e}")

    logging.info("No config file found, using defaults")
    return config


def _extract_config_from_parser(parser: ConfigParser) -> Dict[str, Any]:
    """
    Extract configuration from ConfigParser into a dictionary.

    Handles type conversion for various parameters.

    Args:
        parser: ConfigParser with loaded configuration

    Returns:
        dict: Configuration parameters with proper types

    Written by Claude.
    """
    config = {}
    section = "chatserver"

    if not parser.has_section(section):
        logging.warning(f"Config file does not have a '{section}' section")
        return config

    # Type conversion functions for config values
    type_converters = {
        "mode": lambda v: v if v in ["socket", "http", "both"] else "both",
        "socket_host": str,
        "http_host": str,
        "config_file": str,
        "cert_path": str,
        "socket_port": int,
        "http_port": int,
        "max_clients": int,
        "max_message_length": int,
        "use_ssl": lambda v: v.lower() in ("true", "yes", "1", "on") if v else None,
    }

    # Extract each option from the section
    for option in parser.options(section):
        value = parser.get(section, option)

        # Convert value to appropriate type
        if option in type_converters:
            try:
                value = type_converters[option](value)
                config[option] = value
            except (ValueError, TypeError) as e:
                logging.warning(f"Error converting config option {option}: {e}")
        else:
            config[option] = value

    return config


def load_env_vars() -> Dict[str, Any]:
    """
    Load configuration from environment variables.

    Loads server configuration from environment variables with the CHAT_SERVER_ prefix.

    Returns:
        dict: Configuration parameters from environment variables

    Written by Claude.
    """
    env_config = {}
    prefix = "CHAT_SERVER_"

    # Map of environment variable names to config keys
    env_map = {
        f"{prefix}MODE": "mode",
        f"{prefix}SOCKET_HOST": "socket_host",
        f"{prefix}SOCKET_PORT": "socket_port",
        f"{prefix}HTTP_HOST": "http_host",
        f"{prefix}HTTP_PORT": "http_port",
        f"{prefix}MAX_CLIENTS": "max_clients",
        f"{prefix}MAX_MESSAGE_LENGTH": "max_message_length",
        f"{prefix}CONFIG_FILE": "config_file",
        f"{prefix}USE_SSL": "use_ssl",
        f"{prefix}CERT_PATH": "cert_path",
    }

    # Type conversion functions for environment variables
    type_converters = {
        "mode": lambda v: v if v in ["socket", "http", "both"] else "both",
        "socket_host": str,
        "http_host": str,
        "config_file": str,
        "cert_path": str,
        "socket_port": int,
        "http_port": int,
        "max_clients": int,
        "max_message_length": int,
        "use_ssl": lambda v: v.lower() in ("true", "yes", "1", "on") if v else None,
    }

    # Extract values from environment
    for env_var, config_key in env_map.items():
        if env_var in os.environ:
            value = os.environ[env_var]
            # Convert value to appropriate type
            if config_key in type_converters:
                try:
                    value = type_converters[config_key](value)
                    env_config[config_key] = value
                except (ValueError, TypeError) as e:
                    logging.warning(
                        f"Error converting environment variable {env_var}: {e}"
                    )
            else:
                env_config[config_key] = value

    return env_config


def parse_args(defaults: Optional[Dict[str, Any]] = None) -> argparse.Namespace:
    """
    Parse command line arguments for server configuration.

    Defines and parses command line arguments for configuring the server mode,
    host addresses, ports, and other parameters. Uses provided defaults if available.

    Args:
        defaults: Default values to use for arguments not specified on command line

    Returns:
        argparse.Namespace: Parsed command line arguments

    Written by Claude.
    """
    if defaults is None:
        defaults = {}

    parser = argparse.ArgumentParser(
        description="Chat server with TCP socket and FastAPI HTTP interfaces"
    )
    parser.add_argument(
        "--config",
        type=str,
        help="Path to config file (properties format)",
        default=defaults.get("config_file"),
    )
    parser.add_argument(
        "--mode",
        type=str,
        choices=["socket", "http", "both"],
        default=defaults.get("mode", "both"),
        help=f"Server mode: socket, http, or both (default: {defaults.get('mode', 'both')})",
    )
    parser.add_argument(
        "--socket-host",
        type=str,
        default=defaults.get("socket_host", "127.0.0.1"),
        help=f"Socket server hostname (default: {defaults.get('socket_host', '127.0.0.1')})",
    )
    parser.add_argument(
        "--socket-port",
        type=int,
        default=defaults.get("socket_port", 10010),
        help=f"Socket server port (default: {defaults.get('socket_port', 10010)})",
    )
    parser.add_argument(
        "--http-host",
        type=str,
        default=defaults.get("http_host", "127.0.0.1"),
        help=f"HTTP server hostname (default: {defaults.get('http_host', '127.0.0.1')})",
    )
    parser.add_argument(
        "--http-port",
        type=int,
        default=defaults.get("http_port", 8000),
        help=f"HTTP server port (default: {defaults.get('http_port', 8000)})",
    )
    parser.add_argument(
        "--max-clients",
        type=int,
        default=defaults.get("max_clients", 100),
        help=f"Maximum client connections (default: {defaults.get('max_clients', 100)})",
    )
    parser.add_argument(
        "--max-message-length",
        type=int,
        default=defaults.get("max_message_length", 255),
        help=f"Maximum message length (default: {defaults.get('max_message_length', 255)})",
    )
    parser.add_argument(
        "--use-ssl",
        action="store_true",
        default=defaults.get("use_ssl"),
        help="Enable SSL/TLS encryption",
    )
    parser.add_argument(
        "--cert-path",
        type=str,
        default=defaults.get("cert_path"),
        help="Path to SSL certificate (required if use-ssl is enabled)",
    )

    # Parse only explicitly provided args to avoid overriding defaults
    parsed_args, _ = parser.parse_known_args()

    # Create a namespace with all defaults
    all_args = argparse.Namespace(**defaults)

    # Override with explicitly provided args
    for key, value in vars(parsed_args).items():
        if value is not None or key not in vars(all_args):
            setattr(all_args, key, value)

    return all_args


def get_merged_config() -> argparse.Namespace:
    """
    Get merged configuration from all sources with proper priority.

    Loads configuration in the following order of precedence:
    1. Default values
    2. Config file (if found)
    3. Environment variables
    4. Command line arguments

    Each level overrides the previous levels if the same setting is defined.

    Returns:
        argparse.Namespace: Merged configuration

    Written by Claude.
    """
    # Setup logging early
    logging.basicConfig(level=logging.INFO)

    # First, check if a config file is specified via environment variable
    env_vars = load_env_vars()
    config_file_path = env_vars.get("config_file")

    # Try to load the config file
    file_config = load_config_file(config_file_path)

    # Merge configs: file_config <- env_vars
    merged_config = {**file_config, **env_vars}

    # Parse command line args with merged config as defaults
    args = parse_args(merged_config)

    # If --config was specified on command line, try to load that file and merge again
    if args.config and args.config != config_file_path:
        additional_file_config = load_config_file(args.config)
        # Create a new namespace with the additional config
        for key, value in additional_file_config.items():
            if key not in vars(args) or getattr(args, key) is None:
                setattr(args, key, value)

    return args


# Define config properties
CONFIG_PROPERTIES = [
    "mode",
    "socket_host",
    "socket_port",
    "http_host",
    "http_port",
    "max_clients",
    "max_message_length",
    "use_ssl",
    "cert_path",
    "config_file",
]


class ServerConfig:
    """
    Configuration class for the chat server.

    Provides an object-oriented interface to the configuration settings
    with proper type hints and default values.

    Written by Claude.
    """

    def __init__(self, config: Optional[argparse.Namespace] = None):
        """
        Initialize server configuration.

        If no config is provided, loads configuration from all available sources.

        Args:
            config: Optional pre-loaded configuration
        """
        if config is None:
            config = get_merged_config()

        self.mode: str = getattr(config, "mode", "both")
        self.socket_host: str = getattr(config, "socket_host", "127.0.0.1")
        self.socket_port: int = getattr(config, "socket_port", 10010)
        self.http_host: str = getattr(config, "http_host", "127.0.0.1")
        self.http_port: int = getattr(config, "http_port", 8000)
        self.max_clients: int = getattr(config, "max_clients", 100)
        self.max_message_length: int = getattr(config, "max_message_length", 255)
        self.use_ssl: Optional[bool] = getattr(config, "use_ssl", None)
        self.cert_path: Optional[str] = getattr(config, "cert_path", None)
        self.config_file: Optional[str] = getattr(config, "config_file", None)

        self._validate()

    def _validate(self) -> None:
        """
        Validate the configuration.

        Checks for consistency and required values.
        """
        # Ensure mode is valid
        if self.mode not in ["socket", "http", "both"]:
            logging.warning(f"Invalid mode '{self.mode}', defaulting to 'both'")
            self.mode = "both"

        # Ensure SSL configuration is valid
        if self.use_ssl and not self.cert_path:
            logging.error("SSL is enabled but no certificate path provided.")
            raise ValueError("SSL is enabled but no certificate path provided.")

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert configuration to dictionary.

        Returns:
            dict: Dictionary representation of configuration
        """
        return {
            "mode": self.mode,
            "socket_host": self.socket_host,
            "socket_port": self.socket_port,
            "http_host": self.http_host,
            "http_port": self.http_port,
            "max_clients": self.max_clients,
            "max_message_length": self.max_message_length,
            "use_ssl": self.use_ssl,
            "cert_path": self.cert_path,
            "config_file": self.config_file,
        }

    def __str__(self) -> str:
        """
        String representation of configuration.

        Returns:
            str: String representation
        """
        return f"""ServerConfig(
    mode={self.mode},
    socket_host={self.socket_host},
    socket_port={self.socket_port},
    http_host={self.http_host},
    http_port={self.http_port},
    max_clients={self.max_clients},
    max_message_length={self.max_message_length},
    use_ssl={self.use_ssl},
    cert_path={self.cert_path},
    config_file={self.config_file}
)"""
