#!/bin/bash

# Default logging configuration
LOG_FILE="run-archive.log"
LOG_MODE="both" # Options: file, console, both, none

log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_message="[$timestamp] $1"
    
    case "$LOG_MODE" in
        "file")
            echo "$log_message" >> "$LOG_FILE"
            ;;
        "console")
            echo "$log_message"
            ;;
        "both")
            echo "$log_message" | tee -a "$LOG_FILE"
            ;;
        "none")
            # Do nothing
            ;;
        *)
            # Default to both if invalid mode specified
            echo "$log_message" | tee -a "$LOG_FILE"
            ;;
    esac
}

log "Starting run-archive.sh script"
# run-archive.sh - Script to extract and run the archived Chat Server
# Author: Jeff Lowrey <jeff@jaral.org>
# Date: 2025-08-09
# 
# This script was created with assistance from Anthropic's Claude AI

# Set default configuration
SOCKET_PORT=10010
HTTP_PORT=8000
CONFIG_FILE="config.properties"
USE_SSL=false
CERT_PATH=""
MODE="both"
VENV_PATH="venv"
EXTRACT_DIR="chat-server-extract"
ARCHIVE_FILE=""
CLEAN=false
NO_EXTRACT=false
REPO_OWNER="Jeff-Lowrey"
REPO_NAME="ChatServer"
USE_LATEST_RELEASE=true
RELEASE_TAG=""

# Print usage information
show_help() {
    log "Displaying help information"
    echo "Usage: $0 [options]"
    echo "Extract and run the Chat Server from an archive file (tar.gz or zip)."
    echo "By default, the latest release will be downloaded automatically."
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -s, --socket-port PORT  Set socket server port (default: 10010)"
    echo "  -w, --http-port PORT    Set HTTP server port (default: 8000)"
    echo "  -c, --config FILE       Use custom config file (default: config.properties)"
    echo "  --log-mode MODE        Set logging mode: file, console, both, none (default: both)"
    echo "  --log-file FILE        Set log file path (default: run-archive.log)"
    echo "  --ssl                   Enable SSL"
    echo "  --cert PATH             Path to SSL certificate (required if SSL enabled)"
    echo "  -m, --mode MODE         Set server mode: socket, http, both (default: both)"
    echo "  -e, --extract-dir DIR   Set extraction directory (default: chat-server-extract)"
    echo "  -v, --venv PATH         Set virtual environment path (default: venv)"
    echo "  --clean                 Clean extraction directory before extracting"
    echo "  --no-extract            Skip extraction if directory already exists"
    echo "  --release TAG           Specify a specific release tag to download (instead of latest)"
    echo "  --archive FILE          Specify a local archive file to use instead of downloading"
    echo ""
    echo "Examples:"
    echo "  $0 --archive chat-server.tar.gz       Extract and run with local archive file"
    echo "  $0 --socket-port 9000 --archive chat-server.zip    Run with custom socket port"
    echo "  $0 --ssl --cert ./certs/mycert.pem --archive chat-server.tar.gz    Run with SSL enabled"
    echo "  $0 --mode http --archive chat-server.tar.gz        Run only the HTTP server"
    echo "  $0 --clean --archive chat-server.tar.gz            Clean directory before extraction"
    echo "  $0                                Download and run the latest release"
    echo "  $0 --release v1.0.0              Download and run a specific release by tag"
    echo "  $0 --log-mode file --log-file custom.log   Use custom logging settings"
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--socket-port)
            SOCKET_PORT="$2"
            shift 2
            ;;
        -w|--http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --ssl)
            USE_SSL=true
            shift
            ;;
        --cert)
            CERT_PATH="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -e|--extract-dir)
            EXTRACT_DIR="$2"
            shift 2
            ;;
        -v|--venv)
            VENV_PATH="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --no-extract)
            NO_EXTRACT=true
            shift
            ;;
        --release)
            RELEASE_TAG="$2"
            USE_LATEST_RELEASE=true
            shift 2
            ;;
        --archive)
            ARCHIVE_FILE="$2"
            USE_LATEST_RELEASE=false
            shift 2
            ;;
        --log-mode)
            LOG_MODE="$2"
            if [[ ! "$LOG_MODE" =~ ^(file|console|both|none)$ ]]; then
                echo "Error: Invalid log mode. Use file, console, both, or none."
                exit 1
            fi
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option or argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check for required tools
if [ "$USE_LATEST_RELEASE" = true ]; then
    log "Checking for required tools for downloading releases"
    if ! command -v curl &>/dev/null; then
        log "ERROR: curl is not installed"
        echo "Error: curl is required to download releases. Please install curl and try again."
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        log "ERROR: jq is not installed"
        echo "Error: jq is required to parse release data. Please install jq and try again."
        exit 1
    fi
fi

# Archive file is handled by the --archive flag now

# Download the release if requested
if [ "$USE_LATEST_RELEASE" = true ]; then
    if [ -z "$RELEASE_TAG" ]; then
        log "Downloading latest release from GitHub repository: $REPO_OWNER/$REPO_NAME"
        echo "Downloading latest release from GitHub repository: $REPO_OWNER/$REPO_NAME"
        
        # Get the latest release information
        log "Fetching latest release information from GitHub API"
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
        
        if [ -z "$RELEASE_INFO" ] || echo "$RELEASE_INFO" | grep -q "Not Found"; then
            log "ERROR: Could not find latest release"
            echo "Error: Could not find latest release. Check repository name and access permissions."
            exit 1
        fi
        
        # Extract the tag name
        TAG_NAME=$(echo "$RELEASE_INFO" | jq -r .tag_name)
        log "Found latest release: $TAG_NAME"
        echo "Latest release: $TAG_NAME"
    else
        log "Downloading release with tag '$RELEASE_TAG' from GitHub repository: $REPO_OWNER/$REPO_NAME"
        echo "Downloading release with tag '$RELEASE_TAG' from GitHub repository: $REPO_OWNER/$REPO_NAME"
        
        # Get the specific release information
        log "Fetching release information for tag: $RELEASE_TAG"
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$RELEASE_TAG")
        
        if [ -z "$RELEASE_INFO" ] || echo "$RELEASE_INFO" | grep -q "Not Found"; then
            log "ERROR: Could not find release with tag '$RELEASE_TAG'"
            echo "Error: Could not find release with tag '$RELEASE_TAG'. Check that the tag exists."
            exit 1
        fi
        
        # Use the specified tag name
        TAG_NAME=$RELEASE_TAG
        log "Using release: $TAG_NAME"
        echo "Using release: $TAG_NAME"
    fi
    
    # Find the archive asset (prefer tar.gz but fall back to zip)
    log "Searching for tar.gz asset in release"
    ASSET_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url')
    
    if [ -z "$ASSET_URL" ]; then
        log "No tar.gz asset found, looking for zip file"
        # Try to find zip file if no tar.gz
        ASSET_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url')
    fi
    
    if [ -z "$ASSET_URL" ]; then
        log "ERROR: No valid release asset found"
        echo "Error: Could not find a valid release asset (tar.gz or zip)."
        exit 1
    fi
    
    # Extract the filename from the URL
    ARCHIVE_FILENAME=$(basename "$ASSET_URL")
    log "Downloading asset: $ARCHIVE_FILENAME from $ASSET_URL"
    echo "Downloading: $ARCHIVE_FILENAME"
    
    # Download the asset
    curl -L -o "$ARCHIVE_FILENAME" "$ASSET_URL"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to download release asset"
        echo "Error: Failed to download release asset."
        exit 1
    fi
    
    ARCHIVE_FILE="$ARCHIVE_FILENAME"
    log "Download complete: $ARCHIVE_FILE"
    echo "Download complete: $ARCHIVE_FILE"
fi

# Check if archive file exists
log "Checking if archive file exists: $ARCHIVE_FILE"
if [ ! -f "$ARCHIVE_FILE" ]; then
    log "ERROR: Archive file not found"
    echo "Error: Archive file '$ARCHIVE_FILE' not found."
    exit 1
fi

# Validate arguments
log "Validating arguments"
if [ "$USE_SSL" = true ] && [ -z "$CERT_PATH" ]; then
    log "ERROR: SSL enabled but no certificate path provided"
    echo "Error: SSL certificate path is required when SSL is enabled."
    echo "Use --cert PATH to specify the certificate path."
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &>/dev/null; then
    echo "Error: Python 3 is not installed. Please install Python 3 and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
    echo "Error: pip is not installed. Please install pip and try again."
    exit 1
fi

# Determine pip command
PIP_CMD="pip3"
if ! command -v pip3 &>/dev/null; then
    PIP_CMD="pip"
fi

# Determine venv creation command
VENV_CMD="python3 -m venv"
if ! python3 -c "import venv" &>/dev/null; then
    if ! command -v virtualenv &>/dev/null; then
        echo "Error: Neither venv nor virtualenv is available."
        echo "Please install virtualenv with: pip install virtualenv"
        exit 1
    else
        VENV_CMD="virtualenv"
    fi
fi

# Clean extraction directory if requested
if [ "$CLEAN" = true ] && [ -d "$EXTRACT_DIR" ]; then
    log "Cleaning extraction directory: $EXTRACT_DIR"
    echo "Cleaning extraction directory..."
    rm -rf "$EXTRACT_DIR"
fi

# Extract archive if needed
if [ ! -d "$EXTRACT_DIR" ] || [ "$NO_EXTRACT" = false ]; then
    log "Extracting archive to $EXTRACT_DIR"
    echo "Extracting archive..."
    mkdir -p "$EXTRACT_DIR"
    
    # Extract based on file extension
    if [[ "$ARCHIVE_FILE" == *.tar.gz || "$ARCHIVE_FILE" == *.tgz ]]; then
        tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR" --strip-components=1
    elif [[ "$ARCHIVE_FILE" == *.zip ]]; then
        unzip -q "$ARCHIVE_FILE" -d "$EXTRACT_DIR"
        
        # If the zip has a single directory at the root, move its contents up
        FIRST_DIR=$(ls -d "$EXTRACT_DIR"/*/ 2>/dev/null | head -1)
        if [ -d "$FIRST_DIR" ] && [ $(ls -la "$EXTRACT_DIR" | wc -l) -eq 3 ]; then
            TMP_DIR=$(mktemp -d)
            mv "$FIRST_DIR"/* "$TMP_DIR"/
            rm -rf "$FIRST_DIR"
            mv "$TMP_DIR"/* "$EXTRACT_DIR"/
            rmdir "$TMP_DIR"
        fi
    else
        echo "Error: Unsupported archive format. Use .tar.gz, .tgz, or .zip."
        exit 1
    fi
fi

# Change to extraction directory
log "Changing to extraction directory: $EXTRACT_DIR"
cd "$EXTRACT_DIR" || { log "ERROR: Failed to change to extraction directory"; echo "Error: Could not change to extraction directory."; exit 1; }

# Create and activate virtual environment (always use a virtual environment)
if [ ! -d "$VENV_PATH" ]; then
    log "Creating virtual environment at $VENV_PATH"
    echo "Creating virtual environment..."
    $VENV_CMD "$VENV_PATH"
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to create virtual environment"
        echo "Error: Failed to create virtual environment."
        exit 1
    fi
fi

# Determine activation script based on shell
if [ -f "$VENV_PATH/bin/activate" ]; then
    ACTIVATE_SCRIPT="$VENV_PATH/bin/activate"
else
    ACTIVATE_SCRIPT="$VENV_PATH/Scripts/activate"
fi

log "Activating virtual environment from $ACTIVATE_SCRIPT"
echo "Activating virtual environment..."
# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"

# Check if requirements.txt exists
log "Checking for requirements.txt"
if [ ! -f "requirements.txt" ]; then
    log "WARNING: requirements.txt not found"
    echo "Warning: requirements.txt not found. The application may not work properly."
else
    log "Installing dependencies from requirements.txt"
    echo "Installing dependencies..."
    $PIP_CMD install -r requirements.txt
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to install dependencies"
        echo "Error: Failed to install dependencies."
        exit 1
    fi
fi

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "config.example.properties" ]; then
        echo "Config file not found, creating one from example..."
        cp config.example.properties "$CONFIG_FILE"
    else
        echo "Warning: Neither config file nor example config found."
        echo "Using default configuration."
    fi
fi

# Prepare environment variables
export CHAT_SERVER_MODE="$MODE"
export CHAT_SERVER_SOCKET_PORT="$SOCKET_PORT"
export CHAT_SERVER_HTTP_PORT="$HTTP_PORT"

if [ "$USE_SSL" = true ]; then
    export CHAT_SERVER_USE_SSL="true"
    export CHAT_SERVER_CERT_PATH="$CERT_PATH"
    
    # Make sure the certificate directory exists
    CERT_DIR=$(dirname "$CERT_PATH")
    mkdir -p "$CERT_DIR"
    
    if [ ! -f "$CERT_PATH" ]; then
        echo "Warning: Certificate file not found at $CERT_PATH"
        echo "You need to place your SSL certificate at this location."
    fi
fi

# Run the server
log "Starting Chat Server with socket port $SOCKET_PORT and HTTP port $HTTP_PORT"
echo "Starting Chat Server..."
echo "Socket server will be available at: localhost:${SOCKET_PORT}"
echo "HTTP server will be available at: http://localhost:${HTTP_PORT}"

if [ -f "src/main.py" ]; then
    log "Executing main.py with config $CONFIG_FILE"
    python -m src.main --config "$CONFIG_FILE"
    log "Server execution completed with exit code $?"
else
    log "ERROR: main.py not found in src directory"
    echo "Error: Could not find the main.py file in the src directory."
    echo "Make sure the archive has the correct structure."
    exit 1
fi

