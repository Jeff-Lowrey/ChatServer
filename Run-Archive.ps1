#
# Run-Archive.ps1 - PowerShell script to extract and run the archived Chat Server
# Author: Jeff Lowrey <jeff@jaral.org>
# Date: 2025-08-09
#
# This script was created with assistance from Anthropic's Claude AI
#

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
    
    [Parameter(HelpMessage="Set extraction directory")]
    [Alias("e")]
    [string]$ExtractDir = "chat-server-extract",
    
    [Parameter(HelpMessage="Set virtual environment path")]
    [Alias("v")]
    [string]$VenvPath = "venv",
    
    [Parameter(HelpMessage="Clean extraction directory before extracting")]
    [switch]$Clean,
    
    [Parameter(HelpMessage="Skip extraction if directory already exists")]
    [switch]$NoExtract,
    
    [Parameter(HelpMessage="Download and use the latest release from GitHub")]
    [switch]$Latest,
    
    [Parameter(HelpMessage="Specify the GitHub repository (owner/name)")]
    [string]$Repo = "Jeff-Lowrey/ChatServer",
    
    [Parameter(Position=0, HelpMessage="Archive file to extract and run (not required with --latest)")]
    [string]$ArchiveFile
)

# Print usage information
function Show-Help {
    Write-Host "Usage: .\Run-Archive.ps1 [options] [<archive-file>]"
    Write-Host "Extract and run the Chat Server from an archive file (zip, tar.gz, or tgz)."
    Write-Host "If no archive file is provided and -Latest is used, the latest release will be downloaded."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help, -h              Show this help message"
    Write-Host "  -SocketPort, -s PORT   Set socket server port (default: 10010)"
    Write-Host "  -HttpPort, -w PORT     Set HTTP server port (default: 8000)"
    Write-Host "  -ConfigFile, -c FILE   Use custom config file (default: config.properties)"
    Write-Host "  -SSL                   Enable SSL"
    Write-Host "  -Cert PATH             Path to SSL certificate (required if SSL enabled)"
    Write-Host "  -Mode, -m MODE         Set server mode: socket, http, both (default: both)"
    Write-Host "  -ExtractDir, -e DIR    Set extraction directory (default: chat-server-extract)"
    Write-Host "  -VenvPath, -v PATH     Set virtual environment path (default: venv)"
    Write-Host "  -Clean                 Clean extraction directory before extracting"
    Write-Host "  -NoExtract             Skip extraction if directory already exists"
    Write-Host "  -Latest                Download and use the latest release from GitHub"
    Write-Host "  -Repo OWNER/NAME       Specify the GitHub repository (default: Jeff-Lowrey/ChatServer)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Run-Archive.ps1 chat-server.zip                 Extract and run with default settings"
    Write-Host "  .\Run-Archive.ps1 -SocketPort 9000 chat-server.zip    Run with custom socket port"
    Write-Host "  .\Run-Archive.ps1 -SSL -Cert .\certs\mycert.pem chat-server.zip   Run with SSL enabled"
    Write-Host "  .\Run-Archive.ps1 -Mode http chat-server.zip      Run only the HTTP server"
    Write-Host "  .\Run-Archive.ps1 -Clean chat-server.zip          Clean directory before extraction"
    Write-Host "  .\Run-Archive.ps1 -Latest                         Download and run the latest release"
    Write-Host "  .\Run-Archive.ps1 -Latest -Repo username/repo     Download from a custom repository"
}

# If help was requested, show help and exit
if ($Help) {
    Show-Help
    exit 0
}

# Split the repository into owner and name
$RepoOwner = $Repo.Split('/')[0]
$RepoName = $Repo.Split('/')[1]

# Check if we need to download the latest release
if ($Latest) {
    Write-Host "Downloading latest release from GitHub repository: $Repo"
    
    try {
        # Check if Invoke-RestMethod is available (PowerShell 3.0+)
        if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) {
            throw "PowerShell 3.0 or later is required for downloading releases."
        }
        
        # Get the latest release information
        $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -ErrorAction Stop
        
        if (-not $LatestRelease) {
            throw "Could not find latest release."
        }
        
        # Extract the tag name
        $TagName = $LatestRelease.tag_name
        Write-Host "Latest release: $TagName"
        
        # Find the archive asset (prefer tar.gz but fall back to zip)
        $Asset = $LatestRelease.assets | Where-Object { $_.name -like "*.tar.gz" } | Select-Object -First 1
        
        if (-not $Asset) {
            # Try to find zip file if no tar.gz
            $Asset = $LatestRelease.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        }
        
        if (-not $Asset) {
            throw "Could not find a valid release asset (tar.gz or zip)."
        }
        
        # Extract the filename and download URL
        $ArchiveFilename = $Asset.name
        $DownloadUrl = $Asset.browser_download_url
        
        Write-Host "Downloading: $ArchiveFilename from $DownloadUrl"
        
        # Download the asset
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchiveFilename -ErrorAction Stop
        
        $ArchiveFile = $ArchiveFilename
        Write-Host "Download complete: $ArchiveFile"
    }
    catch {
        Write-Host "Error: Failed to download release. $_" -ForegroundColor Red
        exit 1
    }
}

# Check if archive file is provided
if (-not $ArchiveFile) {
    Write-Host "Error: Archive file is required unless -Latest is specified." -ForegroundColor Red
    Show-Help
    exit 1
}

# Check if archive file exists
if (-not (Test-Path $ArchiveFile)) {
    Write-Host "Error: Archive file '$ArchiveFile' not found." -ForegroundColor Red
    exit 1
}

# Validate arguments
if ($SSL -and -not $Cert) {
    Write-Host "Error: SSL certificate path is required when SSL is enabled." -ForegroundColor Red
    Write-Host "Use -Cert PATH to specify the certificate path." -ForegroundColor Red
    exit 1
}

# Check if Python is installed
$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $PythonCmd = $cmd
        break
    }
}

if ($null -eq $PythonCmd) {
    Write-Host "Error: Python is not installed or not in PATH. Please install Python and try again." -ForegroundColor Red
    exit 1
}

# Check Python version
$PythonVersion = & $PythonCmd -c "import sys; print(sys.version_info.major)"
if ($PythonVersion -lt 3) {
    Write-Host "Error: Python 3 is required. Found Python $PythonVersion." -ForegroundColor Red
    exit 1
}

# Clean extraction directory if requested
if ($Clean -and (Test-Path $ExtractDir)) {
    Write-Host "Cleaning extraction directory..."
    Remove-Item -Path $ExtractDir -Recurse -Force
}

# Extract archive if needed
if (-not (Test-Path $ExtractDir) -or -not $NoExtract) {
    Write-Host "Extracting archive..."
    
    # Create extraction directory if it doesn't exist
    if (-not (Test-Path $ExtractDir)) {
        New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null
    }
    
    # Extract based on file extension
    $Extension = [System.IO.Path]::GetExtension($ArchiveFile).ToLower()
    
    if ($Extension -eq ".zip") {
        # Check if Expand-Archive is available (PowerShell 5.0+)
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
            Expand-Archive -Path $ArchiveFile -DestinationPath $ExtractDir -Force
        } else {
            # Fall back to using .NET for older PowerShell versions
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchiveFile, $ExtractDir)
        }
        
        # If the zip has a single directory at the root, move its contents up
        $FirstDir = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
        if ($FirstDir -and ((Get-ChildItem -Path $ExtractDir | Measure-Object).Count -eq 1)) {
            $TempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
            New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
            
            Get-ChildItem -Path $FirstDir.FullName | Move-Item -Destination $TempDir
            Remove-Item -Path $FirstDir.FullName -Force
            Get-ChildItem -Path $TempDir | Move-Item -Destination $ExtractDir
            Remove-Item -Path $TempDir -Force
        }
    } elseif ($Extension -eq ".gz" -or $ArchiveFile -match "\.tar\.gz$" -or $ArchiveFile -match "\.tgz$") {
        # Check if 7-Zip is installed
        $7zPath = $null
        foreach ($path in @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe")) {
            if (Test-Path $path) {
                $7zPath = $path
                break
            }
        }
        
        if ($7zPath) {
            # Use 7-Zip to extract
            & $7zPath x "$ArchiveFile" -o"$ExtractDir" -y
            
            # If it's a .tar.gz or .tgz, extract the tar file
            if ($ArchiveFile -match "\.tar\.gz$" -or $ArchiveFile -match "\.tgz$") {
                $TarFile = Get-ChildItem -Path $ExtractDir -Filter "*.tar" | Select-Object -First 1
                if ($TarFile) {
                    & $7zPath x "$($TarFile.FullName)" -o"$ExtractDir" -y
                    Remove-Item -Path $TarFile.FullName -Force
                }
            }
        } else {
            Write-Host "Error: 7-Zip is required to extract .tar.gz or .tgz files on Windows." -ForegroundColor Red
            Write-Host "Please install 7-Zip from https://www.7-zip.org/" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: Unsupported archive format. Use .zip, .tar.gz, or .tgz." -ForegroundColor Red
        exit 1
    }
}

# Change to extraction directory
Set-Location -Path $ExtractDir

# Check if requirements.txt exists
if (-not (Test-Path "requirements.txt")) {
    Write-Host "Warning: requirements.txt not found. The application may not work properly." -ForegroundColor Yellow
} else {
    # Create and activate virtual environment
    if (-not (Test-Path $VenvPath)) {
        Write-Host "Creating virtual environment..."
        
        # Determine venv creation command
        try {
            & $PythonCmd -m venv $VenvPath
        } catch {
            Write-Host "Error creating virtual environment with venv. Trying virtualenv..." -ForegroundColor Yellow
            try {
                & $PythonCmd -m pip install virtualenv
                & $PythonCmd -m virtualenv $VenvPath
            } catch {
                Write-Host "Error: Failed to create virtual environment." -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
                exit 1
            }
        }
    }
    
    # Determine activation script
    $ActivateScript = Join-Path -Path $VenvPath -ChildPath "Scripts\Activate.ps1"
    
    if (Test-Path $ActivateScript) {
        Write-Host "Activating virtual environment..."
        & $ActivateScript
        
        Write-Host "Installing dependencies..."
        pip install -r requirements.txt
    } else {
        Write-Host "Error: Activation script not found at $ActivateScript" -ForegroundColor Red
        exit 1
    }
}

# Create config file if it doesn't exist
if (-not (Test-Path $ConfigFile)) {
    if (Test-Path "config.example.properties") {
        Write-Host "Config file not found, creating one from example..."
        Copy-Item "config.example.properties" $ConfigFile
    } else {
        Write-Host "Warning: Neither config file nor example config found." -ForegroundColor Yellow
        Write-Host "Using default configuration." -ForegroundColor Yellow
    }
}

# Prepare environment variables
$env:CHAT_SERVER_MODE = $Mode
$env:CHAT_SERVER_SOCKET_PORT = $SocketPort
$env:CHAT_SERVER_HTTP_PORT = $HttpPort

if ($SSL) {
    $env:CHAT_SERVER_USE_SSL = "true"
    $env:CHAT_SERVER_CERT_PATH = $Cert
    
    # Make sure the certificate directory exists
    $CertDir = Split-Path -Parent $Cert
    if (-not [string]::IsNullOrEmpty($CertDir) -and -not (Test-Path $CertDir)) {
        New-Item -Path $CertDir -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $Cert)) {
        Write-Host "Warning: Certificate file not found at $Cert" -ForegroundColor Yellow
        Write-Host "You need to place your SSL certificate at this location." -ForegroundColor Yellow
    }
}

# Run the server
Write-Host "Starting Chat Server..."
Write-Host "Socket server will be available at: localhost:${SocketPort}"
Write-Host "HTTP server will be available at: http://localhost:${HttpPort}"

if (Test-Path "src\main.py") {
    & $PythonCmd -m src.main --config $ConfigFile
} else {
    Write-Host "Error: Could not find the main.py file in the src directory." -ForegroundColor Red
    Write-Host "Make sure the archive has the correct structure." -ForegroundColor Red
    exit 1
}
