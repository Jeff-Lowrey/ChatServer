#!/bin/bash

# Default logging configuration
LOG_FILE="run-tests-archive.log"
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

log "Starting run-tests-archive.sh script"
# run-tests-archive.sh - Script to run tests for the Chat Server using an archive
# Author: Jeff Lowrey <jeff@jaral.org>
# Date: 2025-08-09
# 
# This script was created with assistance from Anthropic's Claude AI

# Set default configuration
TEST_MODE="all"
COVERAGE=false
VERBOSE=false
SPECIFIC_TEST=""
ARCHIVE_FILE=""
EXTRACT_DIR="chat-server-test"
CLEAN=false
REPO_OWNER="Jeff-Lowrey"
REPO_NAME="ChatServer"
USE_LATEST_RELEASE=true
RELEASE_TAG=""

# Print usage information
show_help() {
    log "Displaying help information"
    echo "Usage: $0 [options]"
    echo "Run tests for the Chat Server using an archive file (tar.gz, tgz, or zip)."
    echo "By default, the latest release will be downloaded automatically."
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -a, --all               Run all tests (default)"
    echo "  -u, --unit              Run only unit tests"
    echo "  -i, --integration       Run only integration tests"
    echo "  -s, --specific TEST     Run a specific test file or test case"
    echo "                          Example: -s tests/test_api.py"
    echo "                          Example: -s tests/test_api.py::TestChatAPI::test_init"
    echo "  -c, --coverage          Run tests with coverage report"
    echo "  -v, --verbose           Run tests with verbose output"
    echo "  -e, --extract-dir DIR   Set extraction directory (default: chat-server-test)"
    echo "  --clean                 Clean extraction directory before extracting"
    echo "  --release TAG           Specify a specific release tag to download (instead of latest)"
    echo "  --archive FILE          Specify a local archive file to use instead of downloading"
    echo "  --log-mode MODE         Set logging mode: file, console, both, none (default: both)"
    echo "  --log-file FILE         Set log file path (default: run-tests-archive.log)"
    echo ""
    echo "Examples:"
    echo "  $0 --archive chat-server.tar.gz       Run all tests from local archive file"
    echo "  $0 --unit --coverage --archive chat-server.zip  Run unit tests with coverage"
    echo "  $0 --specific tests/test_api.py --archive chat-server.tar.gz  Run specific test"
    echo "  $0 --clean --archive chat-server.zip    Clean directory before extracting"
    echo "  $0                                Download and run tests on the latest release"
    echo "  $0 --unit                        Download and run unit tests on the latest release"
    echo "  $0 --release v1.0.0              Download and run tests on a specific release by tag"
    echo "  $0 --log-mode file --log-file test.log   Use custom logging settings"
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            TEST_MODE="all"
            shift
            ;;
        -u|--unit)
            TEST_MODE="unit"
            shift
            ;;
        -i|--integration)
            TEST_MODE="integration"
            shift
            ;;
        -s|--specific)
            TEST_MODE="specific"
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -e|--extract-dir)
            EXTRACT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
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
            echo "Unknown option: $1"
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
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$RELEASE_TAG")
        
        if [ -z "$RELEASE_INFO" ] || echo "$RELEASE_INFO" | grep -q "Not Found"; then
            echo "Error: Could not find release with tag '$RELEASE_TAG'. Check that the tag exists."
            exit 1
        fi
        
        # Use the specified tag name
        TAG_NAME=$RELEASE_TAG
        log "Using release: $TAG_NAME"
        echo "Using release: $TAG_NAME"
    fi
    
    # Find the archive asset (prefer tar.gz but fall back to zip)
    ASSET_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url')
    
    if [ -z "$ASSET_URL" ]; then
        # Try to find zip file if no tar.gz
        ASSET_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url')
    fi
    
    if [ -z "$ASSET_URL" ]; then
        echo "Error: Could not find a valid release asset (tar.gz or zip)."
        exit 1
    fi
    
    # Extract the filename from the URL
    ARCHIVE_FILENAME=$(basename "$ASSET_URL")
    echo "Downloading: $ARCHIVE_FILENAME"
    
    # Download the asset
    log "Downloading asset from $ASSET_URL"
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

# Check if Python is installed
if ! command -v python3 &>/dev/null; then
    if ! command -v python &>/dev/null; then
        echo "Error: Python is not installed. Please install Python and try again."
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

# Check for required tools
log "Checking for required extraction tools based on archive type"
if [[ "$ARCHIVE_FILE" == *.tar.gz || "$ARCHIVE_FILE" == *.tgz ]]; then
    log "Archive is tar.gz format, checking for tar"
    if ! command -v tar &>/dev/null; then
        log "ERROR: tar is not installed"
        echo "Error: tar is required to extract .tar.gz files. Please install tar and try again."
        exit 1
    fi
elif [[ "$ARCHIVE_FILE" == *.zip ]]; then
    log "Archive is zip format, checking for unzip"
    if ! command -v unzip &>/dev/null; then
        log "ERROR: unzip is not installed"
        echo "Error: unzip is required to extract .zip files. Please install unzip and try again."
        exit 1
    fi
fi

# Clean extraction directory if requested
if [ "$CLEAN" = true ] && [ -d "$EXTRACT_DIR" ]; then
    log "Cleaning extraction directory: $EXTRACT_DIR"
    echo "Cleaning extraction directory..."
    rm -rf "$EXTRACT_DIR"
fi

# Extract archive
log "Extracting archive to $EXTRACT_DIR"
echo "Extracting archive to $EXTRACT_DIR..."
mkdir -p "$EXTRACT_DIR"

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
fi

# Change to extraction directory
log "Changing to extraction directory: $EXTRACT_DIR"
cd "$EXTRACT_DIR" || { log "ERROR: Failed to change to extraction directory"; echo "Error: Could not change to extraction directory."; exit 1; }

# Check if test directory exists
log "Checking for tests directory"
if [ ! -d "tests" ]; then
    log "ERROR: No tests directory found"
    echo "Error: No tests directory found in the extracted archive."
    exit 1
fi

# Create and activate virtual environment
VENV_DIR="venv"
if [ ! -d "$VENV_DIR" ]; then
    log "Creating virtual environment at $VENV_DIR"
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to create virtual environment"
        echo "Error: Failed to create virtual environment."
        exit 1
    fi
fi

# Determine activation script based on shell
if [ -f "$VENV_DIR/bin/activate" ]; then
    ACTIVATE_SCRIPT="$VENV_DIR/bin/activate"
else
    ACTIVATE_SCRIPT="$VENV_DIR/Scripts/activate"
fi

log "Activating virtual environment from $ACTIVATE_SCRIPT"
echo "Activating virtual environment..."
# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"

# Install dependencies
log "Installing dependencies from requirements.txt"
echo "Installing dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to install dependencies"
        echo "Error: Failed to install dependencies."
        exit 1
    fi
else
    log "ERROR: requirements.txt not found"
    echo "Error: No requirements.txt found in the extracted archive."
    exit 1
fi

# Install test dependencies
log "Installing test dependencies (pytest, pytest-cov)"
pip install pytest pytest-cov
if [ $? -ne 0 ]; then
    log "ERROR: Failed to install test dependencies"
    echo "Error: Failed to install test dependencies."
    exit 1
fi


# Linting is removed from this script

# Prepare the test command
log "Preparing test command based on test mode: $TEST_MODE"
TEST_CMD=""

case $TEST_MODE in
    "all")
        log "Selected test mode: all"
        echo "Running all tests..."
        TEST_CMD="python -m pytest tests/"
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="python -m pytest --cov=src tests/"
        fi
        ;;
        
    "unit")
        log "Selected test mode: unit"
        echo "Running unit tests..."
        # Exclude integration tests
        UNIT_TESTS=$(find tests -name "test_*.py" -not -name "test_integration.py")
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="python -m pytest --cov=src $UNIT_TESTS"
        else
            TEST_CMD="python -m pytest $UNIT_TESTS"
        fi
        ;;
        
    "integration")
        log "Selected test mode: integration"
        echo "Running integration tests..."
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="python -m pytest --cov=src tests/test_integration.py"
        else
            TEST_CMD="python -m pytest tests/test_integration.py"
        fi
        ;;
        
    "specific")
        if [ -z "$SPECIFIC_TEST" ]; then
            log "ERROR: No specific test provided"
            echo "Error: No specific test provided."
            exit 1
        fi
        
        log "Selected test mode: specific - $SPECIFIC_TEST"
        echo "Running specific test: $SPECIFIC_TEST"
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="python -m pytest --cov=src $SPECIFIC_TEST"
        else
            TEST_CMD="python -m pytest $SPECIFIC_TEST"
        fi
        ;;
esac

# Add verbose flag if requested
if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -v"
fi

# Run the tests
log "Executing test command: $TEST_CMD"
eval "$TEST_CMD"

# Display test results
RESULT=$?
if [ $RESULT -eq 0 ]; then
    log "Tests completed successfully"
    echo "All tests passed!"
else
    log "Tests failed with exit code $RESULT"
    echo "Tests failed with exit code $RESULT"
    exit $RESULT
fi

