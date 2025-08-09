#
# Run-Docker.ps1 - PowerShell script to run the Chat Server in Docker
# Author: Jeff Lowrey <jeff@jaral.org>
# Date: 2025-08-09
#
# This script was created with assistance from Anthropic's Claude AI
#

# Set default configuration
$SocketPort = 10010
$HttpPort = 8000
$ConfigFile = "config.properties"
$UseSSL = $false
$CertPath = ""
$Mode = "both"
$Detached = $false
$Build = $false
$Stop = $false
$Logs = $false

# Process command line arguments
param(
    [Parameter(HelpMessage="Show this help message")]
    [Alias("h")]
    [switch]$Help,
    
    [Parameter(HelpMessage="Set socket server port")]
    [Alias("s")]
    [int]$SocketPort = 10010,
    
    [Parameter(HelpMessage="Set HTTP server port")]
    [Alias("w")]
    [int]$HttpPort = 8000,
    
    [Parameter(HelpMessage="Use custom config file")]
    [Alias("c")]
    [string]$ConfigFile = "config.properties",
    
    [Parameter(HelpMessage="Enable SSL")]
    [switch]$SSL,
    
    [Parameter(HelpMessage="Path to SSL certificate")]
    [string]$Cert,
    
    [Parameter(HelpMessage="Set server mode: socket, http, both")]
    [Alias("m")]
    [ValidateSet("socket", "http", "both")]
    [string]$Mode = "both",
    
    [Parameter(HelpMessage="Run in detached mode")]
    [Alias("d")]
    [switch]$Detached,
    
    [Parameter(HelpMessage="Rebuild the Docker image")]
    [switch]$Build,
    
    [Parameter(HelpMessage="Stop running containers")]
    [switch]$Stop,
    
    [Parameter(HelpMessage="View logs of running container")]
    [switch]$Logs
)

# Print usage information
function Show-Help {
    Write-Host "Usage: .\Run-Docker.ps1 [options]"
    Write-Host "Run the Chat Server using Docker."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help, -h              Show this help message"
    Write-Host "  -SocketPort, -s PORT   Set socket server port (default: 10010)"
    Write-Host "  -HttpPort, -w PORT     Set HTTP server port (default: 8000)"
    Write-Host "  -ConfigFile, -c FILE   Use custom config file (default: config.properties)"
    Write-Host "  -SSL                   Enable SSL"
    Write-Host "  -Cert PATH             Path to SSL certificate (required if SSL enabled)"
    Write-Host "  -Mode, -m MODE         Set server mode: socket, http, both (default: both)"
    Write-Host "  -Detached, -d          Run in detached mode"
    Write-Host "  -Build                 Rebuild the Docker image"
    Write-Host "  -Stop                  Stop running containers"
    Write-Host "  -Logs                  View logs of running container"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Run-Docker.ps1                      Run with default settings"
    Write-Host "  .\Run-Docker.ps1 -SocketPort 9000     Run with custom socket port"
    Write-Host "  .\Run-Docker.ps1 -SSL -Cert .\certs\mycert.pem   Run with SSL enabled"
    Write-Host "  .\Run-Docker.ps1 -Mode http           Run only the HTTP server"
    Write-Host "  .\Run-Docker.ps1 -Stop                Stop running containers"
}

# If help was requested, show help and exit
if ($Help) {
    Show-Help
    exit 0
}

# If build was requested, build the image and exit
if ($Build) {
    Write-Host "Building Docker image..."
    docker build -t chatserver .
    exit 0
}

# If stop was requested, stop containers and exit
if ($Stop) {
    Write-Host "Stopping running containers..."
    docker-compose down
    exit 0
}

# If logs was requested, show logs and exit
if ($Logs) {
    Write-Host "Viewing logs..."
    docker-compose logs -f
    exit 0
}

# Assign values from parameters
$UseSSL = $SSL
$CertPath = $Cert

# Validate arguments
if ($UseSSL -and -not $CertPath) {
    Write-Host "Error: SSL certificate path is required when SSL is enabled." -ForegroundColor Red
    Write-Host "Use -Cert PATH to specify the certificate path." -ForegroundColor Red
    exit 1
}

# Make sure the certificate directory exists if SSL is enabled
if ($UseSSL) {
    $CertDir = Split-Path -Parent $CertPath
    
    if (-not (Test-Path $CertDir)) {
        New-Item -Path $CertDir -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $CertPath)) {
        Write-Host "Warning: Certificate file not found at $CertPath" -ForegroundColor Yellow
        Write-Host "You need to place your SSL certificate at this location." -ForegroundColor Yellow
    }
}

# Prepare environment variables
$EnvVars = "-e CHAT_SERVER_MODE=$Mode"
$EnvVars = "$EnvVars -e CHAT_SERVER_SOCKET_PORT=$SocketPort"
$EnvVars = "$EnvVars -e CHAT_SERVER_HTTP_PORT=$HttpPort"

if ($UseSSL) {
    $EnvVars = "$EnvVars -e CHAT_SERVER_USE_SSL=true"
    $CertName = Split-Path -Leaf $CertPath
    $EnvVars = "$EnvVars -e CHAT_SERVER_CERT_PATH=/app/certs/$CertName"
}

# Create config directory if it doesn't exist
$ConfigDir = Split-Path -Parent $ConfigFile
if (-not [string]::IsNullOrEmpty($ConfigDir) -and -not (Test-Path $ConfigDir)) {
    New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
}

# Check if config file exists, if not create a sample one
if (-not (Test-Path $ConfigFile)) {
    if (Test-Path "config.example.properties") {
        Write-Host "Config file not found, creating one from example..."
        Copy-Item "config.example.properties" $ConfigFile
    } else {
        Write-Host "Warning: Neither config file nor example config found." -ForegroundColor Yellow
        Write-Host "Using default configuration." -ForegroundColor Yellow
    }
}

# Check if docker-compose is available
$UseCompose = $null -ne (Get-Command "docker-compose" -ErrorAction SilentlyContinue)

# Run with docker-compose if available, otherwise use docker run
if ($UseCompose) {
    Write-Host "Running with docker-compose..."
    
    # Create or update the docker-compose override file
    $ComposeOverride = @"
version: '3.8'
services:
  chatserver:
    ports:
      - "${SocketPort}:10010"
      - "${HttpPort}:8000"
    environment:
      - CHAT_SERVER_MODE=${Mode}
"@

    if ($UseSSL) {
        $ComposeOverride += @"

      - CHAT_SERVER_USE_SSL=true
      - CHAT_SERVER_CERT_PATH=/app/certs/$CertName
"@
        
        # Make sure certs directory exists
        if (-not (Test-Path "certs")) {
            New-Item -Path "certs" -ItemType Directory -Force | Out-Null
        }
        
        # If certificate exists, copy it to the certs directory
        if (Test-Path $CertPath) {
            Copy-Item $CertPath "certs/$CertName" -Force
        }
    }
    
    # Save the override file
    $ComposeOverride | Out-File -FilePath "docker-compose.override.yml" -Encoding utf8
    
    # Run docker-compose
    if ($Detached) {
        docker-compose up -d
    } else {
        docker-compose up
    }
} else {
    Write-Host "Running with docker run..."
    
    # Prepare volumes
    $ConfigPath = Resolve-Path $ConfigFile
    $Volumes = "-v ${ConfigPath}:/etc/chatserver/config.properties:ro"
    
    if ($UseSSL) {
        # Make sure certs directory exists
        if (-not (Test-Path "certs")) {
            New-Item -Path "certs" -ItemType Directory -Force | Out-Null
        }
        
        # If certificate exists, copy it to the certs directory
        if (Test-Path $CertPath) {
            $CertName = Split-Path -Leaf $CertPath
            Copy-Item $CertPath "certs/$CertName" -Force
        }
        
        $CertsPath = Resolve-Path "certs"
        $Volumes = "$Volumes -v ${CertsPath}:/app/certs:ro"
    }
    
    # Create logs directory
    if (-not (Test-Path "logs")) {
        New-Item -Path "logs" -ItemType Directory -Force | Out-Null
    }
    $LogsPath = Resolve-Path "logs"
    $Volumes = "$Volumes -v ${LogsPath}:/app/logs"
    
    # Run the container
    if ($Detached) {
        Invoke-Expression "docker run -d --name chatserver -p ${SocketPort}:10010 -p ${HttpPort}:8000 $EnvVars $Volumes chatserver"
        
        Write-Host "Container started in detached mode. Use the following to view logs:"
        Write-Host "docker logs -f chatserver"
    } else {
        Invoke-Expression "docker run --rm --name chatserver -p ${SocketPort}:10010 -p ${HttpPort}:8000 $EnvVars $Volumes chatserver"
    }
}

Write-Host "Chat Server is running!"
Write-Host "Socket server available at: localhost:${SocketPort}"
Write-Host "HTTP server available at: http://localhost:${HttpPort}"
