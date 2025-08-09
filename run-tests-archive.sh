#!/bin/bash
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
FORMAT=false
LINT=false
ARCHIVE_FILE=""
EXTRACT_DIR="chat-server-test"
CLEAN=false
REPO_OWNER="Jeff-Lowrey"
REPO_NAME="ChatServer"
USE_LATEST_RELEASE=true
RELEASE_TAG=""

# Print usage information
show_help() {
    echo "Usage: $0 [options] [<archive-file>]"
    echo "Run tests for the Chat Server using an archive file (tar.gz, tgz, or zip)."
    echo "If no archive file is provided, the latest release will be downloaded automatically."
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
    echo "  -f, --format            Run code formatter (ruff format)"
    echo "  -l, --lint              Run linter (ruff check)"
    echo "  -e, --extract-dir DIR   Set extraction directory (default: chat-server-test)"
    echo "  --clean                 Clean extraction directory before extracting"
    echo "  --release TAG           Specify a specific release tag to download (instead of latest)"
    echo ""
    echo "Examples:"
    echo "  $0 chat-server.tar.gz                 Run all tests from archive"
    echo "  $0 --unit --coverage chat-server.zip  Run unit tests with coverage from archive"
    echo "  $0 --specific tests/test_api.py chat-server.tar.gz  Run specific test from archive"
    echo "  $0 --lint --format chat-server.tgz    Run linter and formatter on extracted archive"
    echo "  $0 --clean chat-server.zip            Clean directory before extracting"
    echo "  $0                                Download and run tests on the latest release"
    echo "  $0 --unit                        Download and run unit tests on the latest release"
    echo "  $0 --release v1.0.0              Download and run tests on a specific release by tag"
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
        -f|--format)
            FORMAT=true
            shift
            ;;
        -l|--lint)
            LINT=true
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
        *.tar.gz|*.tgz|*.zip)
            ARCHIVE_FILE="$1"
            shift
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
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is required to download releases. Please install curl and try again."
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required to parse release data. Please install jq and try again."
        exit 1
    fi
fi

# If archive file is provided, use it instead of downloading
if [ -n "$ARCHIVE_FILE" ]; then
    USE_LATEST_RELEASE=false
fi

# Download the release if requested
if [ "$USE_LATEST_RELEASE" = true ]; then
    if [ -z "$RELEASE_TAG" ]; then
        echo "Downloading latest release from GitHub repository: $REPO_OWNER/$REPO_NAME"
        
        # Get the latest release information
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
        
        if [ -z "$RELEASE_INFO" ] || echo "$RELEASE_INFO" | grep -q "Not Found"; then
            echo "Error: Could not find latest release. Check repository name and access permissions."
            exit 1
        fi
        
        # Extract the tag name
        TAG_NAME=$(echo "$RELEASE_INFO" | jq -r .tag_name)
        echo "Latest release: $TAG_NAME"
    else
        echo "Downloading release with tag '$RELEASE_TAG' from GitHub repository: $REPO_OWNER/$REPO_NAME"
        
        # Get the specific release information
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$RELEASE_TAG")
        
        if [ -z "$RELEASE_INFO" ] || echo "$RELEASE_INFO" | grep -q "Not Found"; then
            echo "Error: Could not find release with tag '$RELEASE_TAG'. Check that the tag exists."
            exit 1
        fi
        
        # Use the specified tag name
        TAG_NAME=$RELEASE_TAG
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
    curl -L -o "$ARCHIVE_FILENAME" "$ASSET_URL"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download release asset."
        exit 1
    fi
    
    ARCHIVE_FILE="$ARCHIVE_FILENAME"
    echo "Download complete: $ARCHIVE_FILE"
fi

# Check if archive file exists
if [ ! -f "$ARCHIVE_FILE" ]; then
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
if [[ "$ARCHIVE_FILE" == *.tar.gz || "$ARCHIVE_FILE" == *.tgz ]]; then
    if ! command -v tar &>/dev/null; then
        echo "Error: tar is required to extract .tar.gz files. Please install tar and try again."
        exit 1
    fi
elif [[ "$ARCHIVE_FILE" == *.zip ]]; then
    if ! command -v unzip &>/dev/null; then
        echo "Error: unzip is required to extract .zip files. Please install unzip and try again."
        exit 1
    fi
fi

# Clean extraction directory if requested
if [ "$CLEAN" = true ] && [ -d "$EXTRACT_DIR" ]; then
    echo "Cleaning extraction directory..."
    rm -rf "$EXTRACT_DIR"
fi

# Extract archive
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
cd "$EXTRACT_DIR" || { echo "Error: Could not change to extraction directory."; exit 1; }

# Check if test directory exists
if [ ! -d "tests" ]; then
    echo "Error: No tests directory found in the extracted archive."
    exit 1
fi

# Create and activate virtual environment
VENV_DIR="venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
fi

# Determine activation script based on shell
if [ -f "$VENV_DIR/bin/activate" ]; then
    ACTIVATE_SCRIPT="$VENV_DIR/bin/activate"
else
    ACTIVATE_SCRIPT="$VENV_DIR/Scripts/activate"
fi

echo "Activating virtual environment..."
# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"

# Install dependencies
echo "Installing dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "Error: No requirements.txt found in the extracted archive."
    exit 1
fi

# Install test dependencies
pip install pytest pytest-cov ruff

# Run formatter if requested
if [ "$FORMAT" = true ]; then
    echo "Running code formatter..."
    ruff format .
fi

# Run linter if requested
if [ "$LINT" = true ]; then
    echo "Running linter..."
    ruff check .
fi

# Prepare the test command
TEST_CMD=""

case $TEST_MODE in
    "all")
        echo "Running all tests..."
        TEST_CMD="pytest tests/"
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="pytest --cov=src tests/"
        fi
        ;;
        
    "unit")
        echo "Running unit tests..."
        # Exclude integration tests
        UNIT_TESTS=$(find tests -name "test_*.py" -not -name "test_integration.py")
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="pytest --cov=src $UNIT_TESTS"
        else
            TEST_CMD="pytest $UNIT_TESTS"
        fi
        ;;
        
    "integration")
        echo "Running integration tests..."
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="pytest --cov=src tests/test_integration.py"
        else
            TEST_CMD="pytest tests/test_integration.py"
        fi
        ;;
        
    "specific")
        if [ -z "$SPECIFIC_TEST" ]; then
            echo "Error: No specific test provided."
            exit 1
        fi
        
        echo "Running specific test: $SPECIFIC_TEST"
        
        if [ "$COVERAGE" = true ]; then
            TEST_CMD="pytest --cov=src $SPECIFIC_TEST"
        else
            TEST_CMD="pytest $SPECIFIC_TEST"
        fi
        ;;
esac

# Add verbose flag if requested
if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -v"
fi

# Run the tests
eval "$TEST_CMD"

# Display test results
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Tests failed with exit code $RESULT"
    exit $RESULT
fi

