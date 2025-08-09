# Chat Server Run Scripts

This document describes the utility scripts available for running, testing, and deploying the Chat Server from different sources.

## Overview

The Chat Server provides several utility scripts to make it easier to:
1. Run the server from an archive file (release archive)
2. Run tests on a local or downloaded archive
3. Deploy and run the server in Docker containers

These scripts are available for both Unix-like systems (Bash scripts) and Windows (PowerShell scripts).

## Archive Run Scripts

These scripts allow you to easily extract and run the Chat Server from a release archive (tar.gz, tgz, or zip file) without manually unpacking and configuring the environment.

### run-archive.sh (Bash)

This script extracts and runs the Chat Server from an archive file on Unix-like systems (Linux, macOS).

```bash
# Run from a local archive file
./run-archive.sh --archive chat-server.tar.gz

# Download and run the latest release
./run-archive.sh

# Download and run a specific release by tag
./run-archive.sh --release v1.0.0

# Run with custom ports
./run-archive.sh --socket-port 9000 --http-port 8080 --archive chat-server.tar.gz

# Run with SSL enabled
./run-archive.sh --ssl --cert ./certs/mycert.pem --archive chat-server.tar.gz

# Run only HTTP server
./run-archive.sh --mode http --archive chat-server.tar.gz

# Use custom config file
./run-archive.sh --config myconfig.properties --archive chat-server.tar.gz

# Control logging output
./run-archive.sh --log-mode file --log-file server.log
```

### Run-Archive.ps1 (PowerShell)

This script extracts and runs the Chat Server from an archive file on Windows systems.

```powershell
# Run from a local archive file
.\Run-Archive.ps1 -Archive chat-server.zip

# Download and run the latest release
.\Run-Archive.ps1

# Download and run a specific release by tag
.\Run-Archive.ps1 -Release v1.0.0

# Run with custom ports
.\Run-Archive.ps1 -SocketPort 9000 -HttpPort 8080 -Archive chat-server.zip

# Run with SSL enabled
.\Run-Archive.ps1 -SSL -Cert .\certs\mycert.pem -Archive chat-server.zip

# Run only HTTP server
.\Run-Archive.ps1 -Mode http -Archive chat-server.zip

# Use custom config file
.\Run-Archive.ps1 -ConfigFile myconfig.properties -Archive chat-server.zip

# Control logging output
.\Run-Archive.ps1 -LoggingMode file -LoggingFile server.log
```

## Archive Test Scripts

These scripts allow you to run tests on a Chat Server archive file without manually unpacking and configuring the test environment.

### run-tests-archive.sh (Bash)

This script runs tests on a Chat Server archive file on Unix-like systems.

```bash
# Run all tests from a local archive file
./run-tests-archive.sh --archive chat-server.tar.gz

# Download and run tests on the latest release
./run-tests-archive.sh

# Download and run tests on a specific release by tag
./run-tests-archive.sh --release v1.0.0

# Run only unit tests with coverage
./run-tests-archive.sh --unit --coverage --archive chat-server.tar.gz

# Run only integration tests
./run-tests-archive.sh --integration --archive chat-server.tar.gz

# Run a specific test file or case
./run-tests-archive.sh --specific tests/test_api.py --archive chat-server.tar.gz

# Clean extraction directory before testing
./run-tests-archive.sh --clean --archive chat-server.tar.gz

# Control logging output
./run-tests-archive.sh --log-mode file --log-file tests.log
```

### Run-Tests-Archive.ps1 (PowerShell)

This script runs tests on a Chat Server archive file on Windows systems.

```powershell
# Run all tests from a local archive file
.\Run-Tests-Archive.ps1 -Archive chat-server.zip

# Download and run tests on the latest release
.\Run-Tests-Archive.ps1

# Download and run tests on a specific release by tag
.\Run-Tests-Archive.ps1 -Release v1.0.0

# Run only unit tests with coverage
.\Run-Tests-Archive.ps1 -Unit -Coverage -Archive chat-server.zip

# Run only integration tests
.\Run-Tests-Archive.ps1 -Integration -Archive chat-server.zip

# Run a specific test file or case
.\Run-Tests-Archive.ps1 -Specific tests/test_api.py -Archive chat-server.zip

# Clean extraction directory before testing
.\Run-Tests-Archive.ps1 -Clean -Archive chat-server.zip

# Control logging output
.\Run-Tests-Archive.ps1 -LoggingMode file -LoggingFile tests.log
```

## Docker Run Scripts

These scripts simplify the process of building and running the Chat Server in Docker containers.

### run-docker.sh (Bash)

This script builds and runs the Chat Server in a Docker container on Unix-like systems.

```bash
# Build and run with default settings
./run-docker.sh

# Run with custom ports
./run-docker.sh --socket-port 9000 --http-port 8080

# Use Docker Compose instead of direct Docker commands
./run-docker.sh --compose

# Run with SSL enabled
./run-docker.sh --ssl --cert ./certs/mycert.pem

# Customize container name
./run-docker.sh --name my-chat-server

# Rebuild the Docker image
./run-docker.sh --build
```

### Run-Docker.ps1 (PowerShell)

This script builds and runs the Chat Server in a Docker container on Windows systems.

```powershell
# Build and run with default settings
.\Run-Docker.ps1

# Run with custom ports
.\Run-Docker.ps1 -SocketPort 9000 -HttpPort 8080

# Use Docker Compose instead of direct Docker commands
.\Run-Docker.ps1 -Compose

# Run with SSL enabled
.\Run-Docker.ps1 -SSL -Cert .\certs\mycert.pem

# Customize container name
.\Run-Docker.ps1 -Name my-chat-server

# Rebuild the Docker image
.\Run-Docker.ps1 -Build
```

## Standard Test Scripts

These scripts run tests in a Docker container for consistent test environment across platforms.

### run-tests.sh (Bash)

```bash
# Run all tests
./run-tests.sh

# Run only unit tests
./run-tests.sh --unit

# Run with coverage
./run-tests.sh --coverage

# Run a specific test file or case
./run-tests.sh --specific tests/test_api.py

# Format the code
./run-tests.sh --format

# Lint the code
./run-tests.sh --lint

# Force rebuild of the Docker test image
./run-tests.sh --build
```

### Run-Tests.ps1 (PowerShell)

```powershell
# Run all tests
.\Run-Tests.ps1

# Run only unit tests
.\Run-Tests.ps1 -Unit

# Run with coverage
.\Run-Tests.ps1 -Coverage

# Run a specific test file or case
.\Run-Tests.ps1 -Specific tests/test_api.py

# Format the code
.\Run-Tests.ps1 -Format

# Lint the code
.\Run-Tests.ps1 -Lint

# Force rebuild of the Docker test image
.\Run-Tests.ps1 -Build
```

## Common Options

### Logging Options

All archive scripts support configurable logging with these options:

- `--log-mode MODE` / `-LoggingMode MODE`: Control where logs are written. Values can be:
  - `file`: Only write logs to file
  - `console`: Only display logs on the console
  - `both`: Write logs to both file and console (default)
  - `none`: Disable logging

- `--log-file FILE` / `-LoggingFile FILE`: Specify a custom log file path

### Archive Options

For scripts that work with archive files:

- `--archive FILE` / `-Archive FILE`: Specify a local archive file to use
- `--release TAG` / `-Release TAG`: Specify a specific release tag to download
- No archive parameter: Download and use the latest release automatically

## GitHub Releases

The scripts can automatically download the latest release or a specific tagged release from the GitHub repository. This feature requires:

- `curl` and `jq` for Bash scripts
- PowerShell 3.0+ for PowerShell scripts

The downloaded release assets include both the main Chat Server archive and individual run scripts.