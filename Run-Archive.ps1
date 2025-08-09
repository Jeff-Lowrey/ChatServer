#
# Run-Archive.ps1 - PowerShell script to extract and run the archived Chat Server

# Default logging configuration
$LogFile = $LoggingFile
$LogMode = $LoggingMode # Options: file, console, both, none

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    
    switch ($LogMode) {
        "file" {
            $LogMessage | Out-File -FilePath $LogFile -Append
        }
        "console" {
            Write-Host $LogMessage
        }
        "both" {
            Write-Host $LogMessage
            $LogMessage | Out-File -FilePath $LogFile -Append
        }
        "none" {
            # Do nothing
        }
        default {
            # Default to both if invalid mode specified
            Write-Host $LogMessage
            $LogMessage | Out-File -FilePath $LogFile -Append
        }
    }
}

Write-Log "Starting Run-Archive.ps1 script"
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
    
    [Parameter(HelpMessage="Specify a specific release tag to download (instead of latest)")]
    [string]$Release,
    
    [Parameter(HelpMessage="Specify a local archive file to use instead of downloading")]
    [string]$Archive,
    
    [Parameter(HelpMessage="Set logging mode: file, console, both, none")]
    [ValidateSet("file", "console", "both", "none")]
    [string]$LoggingMode = "both",
    
    [Parameter(HelpMessage="Set log file path")]
    [string]$LoggingFile = "Run-Archive.log"
)

# Print usage information
function Show-Help {
    Write-Host "Usage: .\Run-Archive.ps1 [options]"
    Write-Host "Extract and run the Chat Server from an archive file (zip, tar.gz, or tgz)."
    Write-Host "By default, the latest release will be downloaded automatically."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help, -h              Show this help message"
    Write-Host "  -SocketPort, -s PORT   Set socket server port (default: 10010)"
    Write-Host "  -HttpPort, -w PORT     Set HTTP server port (default: 8000)"
    Write-Host "  -ConfigFile, -c FILE   Use custom config file (default: config.properties)"
    Write-Host "  -LoggingMode MODE      Set logging mode: file, console, both, none (default: both)"
    Write-Host "  -LoggingFile FILE      Set log file path (default: Run-Archive.log)"
    Write-Host "  -SSL                   Enable SSL"
    Write-Host "  -Cert PATH             Path to SSL certificate (required if SSL enabled)"
    Write-Host "  -Mode, -m MODE         Set server mode: socket, http, both (default: both)"
    Write-Host "  -ExtractDir, -e DIR    Set extraction directory (default: chat-server-extract)"
    Write-Host "  -VenvPath, -v PATH     Set virtual environment path (default: venv)"
    Write-Host "  -Clean                 Clean extraction directory before extracting"
    Write-Host "  -NoExtract             Skip extraction if directory already exists"
    Write-Host "  -Release TAG           Specify a specific release tag to download (instead of latest)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Run-Archive.ps1 -Archive chat-server.zip       Extract and run with local archive file"
    Write-Host "  .\Run-Archive.ps1 -SocketPort 9000 -Archive chat-server.zip    Run with custom socket port"
    Write-Host "  .\Run-Archive.ps1 -SSL -Cert .\certs\mycert.pem -Archive chat-server.zip   Run with SSL enabled"
    Write-Host "  .\Run-Archive.ps1 -Mode http -Archive chat-server.zip      Run only the HTTP server"
    Write-Host "  .\Run-Archive.ps1 -Clean -Archive chat-server.zip          Clean directory before extraction"
    Write-Host "  .\Run-Archive.ps1                                 Download and run the latest release"
    Write-Host "  .\Run-Archive.ps1 -Release v1.0.0                 Download and run a specific release by tag"
    Write-Host "  .\Run-Archive.ps1 -LoggingMode file -LoggingFile logs.txt  Use custom logging settings"
}

# If help was requested, show help and exit
if ($Help) {
    Write-Log "Displaying help information"
    Show-Help
    exit 0
}

# Set the repository owner and name
$RepoOwner = "Jeff-Lowrey"
$RepoName = "ChatServer"

# Check if we need to download a release
$DownloadRelease = -not $Archive
if ($DownloadRelease) {
    $RepoString = "$RepoOwner/$RepoName"
    
    if ($Release) {
        Write-Log "Downloading release with tag '$Release' from GitHub repository: $RepoString"
        Write-Host "Downloading release with tag '$Release' from GitHub repository: $RepoString"
    } else {
        Write-Log "Downloading latest release from GitHub repository: $RepoString"
        Write-Host "Downloading latest release from GitHub repository: $RepoString"
    }
    
    try {
        # Check if Invoke-RestMethod is available (PowerShell 3.0+)
        if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) {
            throw "PowerShell 3.0 or later is required for downloading releases."
        }
        
        # Get the release information
        if ($Release) {
            # Get the specific release by tag
            Write-Log "Fetching release information for tag: $Release"
            $ReleaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$Release" -ErrorAction Stop
            
            if (-not $ReleaseInfo) {
                Write-Log "ERROR: Could not find release with tag '$Release'"
                throw "Could not find release with tag '$Release'."
            }
            
            # Use the specified tag
            $TagName = $Release
            Write-Log "Using release: $TagName"
            Write-Host "Using release: $TagName"
        } else {
            # Get the latest release
            Write-Log "Fetching latest release information from GitHub API"
            $ReleaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest" -ErrorAction Stop
            
            if (-not $ReleaseInfo) {
                Write-Log "ERROR: Could not find latest release"
                throw "Could not find latest release."
            }
            
            # Extract the tag name
            $TagName = $ReleaseInfo.tag_name
            Write-Log "Found latest release: $TagName"
            Write-Host "Latest release: $TagName"
        }
        
        # Find the archive asset (prefer tar.gz but fall back to zip)
        Write-Log "Searching for tar.gz asset in release"
        $Asset = $ReleaseInfo.assets | Where-Object { $_.name -like "*.tar.gz" } | Select-Object -First 1
        
        if (-not $Asset) {
            Write-Log "No tar.gz asset found, looking for zip file"
            # Try to find zip file if no tar.gz
            $Asset = $ReleaseInfo.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        }
        
        if (-not $Asset) {
            Write-Log "ERROR: No valid release asset found"
            throw "Could not find a valid release asset (tar.gz or zip)."
        }
        
        # Extract the filename and download URL
        $ArchiveFilename = $Asset.name
        $DownloadUrl = $Asset.browser_download_url
        
        Write-Log "Downloading asset: $ArchiveFilename from $DownloadUrl"
        Write-Host "Downloading: $ArchiveFilename from $DownloadUrl"
        
        # Download the asset
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchiveFilename -ErrorAction Stop
        
        $Archive = $ArchiveFilename
        Write-Log "Download complete: $Archive"
        Write-Host "Download complete: $Archive"
    }
    catch {
        Write-Log "ERROR: Failed to download release - $_"
        Write-Host "Error: Failed to download release. $_" -ForegroundColor Red
        exit 1
    }
}


# Check if archive file exists when specified
Write-Log "Checking if archive file exists: $Archive"
if ($Archive -and -not (Test-Path $Archive)) {
    Write-Log "ERROR: Archive file not found"
    Write-Host "Error: Archive file '$Archive' not found." -ForegroundColor Red
    exit 1
}

# Validate arguments
Write-Log "Validating arguments"
if ($SSL -and -not $Cert) {
    Write-Log "ERROR: SSL enabled but no certificate path provided"
    Write-Host "Error: SSL certificate path is required when SSL is enabled." -ForegroundColor Red
    Write-Host "Use -Cert PATH to specify the certificate path." -ForegroundColor Red
    exit 1
}

# Check if Python is installed
Write-Log "Checking for Python installation"
$PythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $PythonCmd = $cmd
        Write-Log "Found Python command: $cmd"
        break
    }
}

if ($null -eq $PythonCmd) {
    Write-Log "ERROR: Python is not installed or not in PATH"
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
    Write-Log "Cleaning extraction directory: $ExtractDir"
    Write-Host "Cleaning extraction directory..."
    Remove-Item -Path $ExtractDir -Recurse -Force
}

# Extract archive if needed
if (-not (Test-Path $ExtractDir) -or -not $NoExtract) {
    Write-Log "Extracting archive to $ExtractDir"
    Write-Host "Extracting archive..."
    
    # Create extraction directory if it doesn't exist
    if (-not (Test-Path $ExtractDir)) {
        Write-Log "Creating extraction directory"
        New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null
    }
    
    # Extract based on file extension
    $Extension = [System.IO.Path]::GetExtension($Archive).ToLower()
    
    if ($Extension -eq ".zip") {
        Write-Log "Archive is zip format, using PowerShell extraction"
        # Check if Expand-Archive is available (PowerShell 5.0+)
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
            Write-Log "Using Expand-Archive cmdlet"
            Expand-Archive -Path $Archive -DestinationPath $ExtractDir -Force
        } else {
            # Fall back to using .NET for older PowerShell versions
            Write-Log "Using .NET ZipFile class for extraction"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($Archive, $ExtractDir)
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
    } elseif ($Extension -eq ".gz" -or $Archive -match "\.tar\.gz$" -or $Archive -match "\.tgz$") {
        # Use Windows built-in compression for tar.gz
        try {
            # First try to use tar command (available in Windows 10 1803+)
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                Write-Host "Using built-in tar command..."
                tar -xzf "$Archive" -C "$ExtractDir"
            } else {
                # Fall back to .NET and PowerShell
                Write-Host "Using .NET compression..."
                
                # Create a temporary directory for intermediate steps
                $TempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
                New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
                
                # Decompress .gz to temporary directory
                Add-Type -AssemblyName System.IO.Compression
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                
                # Use .NET classes for GZip decompression
                $GzipStream = New-Object System.IO.Compression.GZipStream([System.IO.File]::OpenRead($Archive), [System.IO.Compression.CompressionMode]::Decompress)
                $TargetStream = [System.IO.File]::Create([System.IO.Path]::Combine($TempDir, "temp.tar"))
                $GzipStream.CopyTo($TargetStream)
                $GzipStream.Close()
                $TargetStream.Close()
                
                # Extract tar file using COM object for the Windows shell
                $shell = New-Object -ComObject Shell.Application
                $tarFile = $shell.NameSpace([System.IO.Path]::Combine($TempDir, "temp.tar"))
                $destination = $shell.NameSpace($ExtractDir)
                $destination.CopyHere($tarFile.Items())
                
                # Clean up temporary directory
                Remove-Item -Path $TempDir -Recurse -Force
            }
        } catch {
            Write-Host "Error extracting tar.gz file: $_" -ForegroundColor Red
            Write-Host "If this continues to fail, please install 7-Zip and try again." -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "Error: Unsupported archive format. Use .zip, .tar.gz, or .tgz." -ForegroundColor Red
        exit 1
    }
}

# Change to extraction directory
Write-Log "Changing to extraction directory: $ExtractDir"
Set-Location -Path $ExtractDir

# Check if requirements.txt exists
Write-Log "Checking for requirements.txt"
if (-not (Test-Path "requirements.txt")) {
    Write-Log "WARNING: requirements.txt not found"
    Write-Host "Warning: requirements.txt not found. The application may not work properly." -ForegroundColor Yellow
} else {
    # Create and activate virtual environment
    if (-not (Test-Path $VenvPath)) {
        Write-Log "Creating virtual environment at $VenvPath"
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
    Write-Log "Activating virtual environment from $ActivateScript"
    
    if (Test-Path $ActivateScript) {
        Write-Host "Activating virtual environment..."
        & $ActivateScript
        
        Write-Log "Installing dependencies from requirements.txt"
        Write-Host "Installing dependencies..."
        pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR: Failed to install dependencies"
            Write-Host "Error: Failed to install dependencies." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: Activation script not found at $ActivateScript" -ForegroundColor Red
        exit 1
    }
}

# Create config file if it doesn't exist
Write-Log "Checking for config file: $ConfigFile"
if (-not (Test-Path $ConfigFile)) {
    if (Test-Path "config.example.properties") {
        Write-Log "Creating config file from example"
        Write-Host "Config file not found, creating one from example..."
        Copy-Item "config.example.properties" $ConfigFile
    } else {
        Write-Log "WARNING: Neither config file nor example config found"
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
Write-Log "Starting Chat Server with socket port $SocketPort and HTTP port $HttpPort"
Write-Host "Starting Chat Server..."
Write-Host "Socket server will be available at: localhost:${SocketPort}"
Write-Host "HTTP server will be available at: http://localhost:${HttpPort}"

if (Test-Path "src\main.py") {
    Write-Log "Executing main.py with config $ConfigFile"
    & $PythonCmd -m src.main --config $ConfigFile
    Write-Log "Server execution completed with exit code $LASTEXITCODE"
} else {
    Write-Log "ERROR: main.py not found in src directory"
    Write-Host "Error: Could not find the main.py file in the src directory." -ForegroundColor Red
    Write-Host "Make sure the archive has the correct structure." -ForegroundColor Red
    exit 1
}
