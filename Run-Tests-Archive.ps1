#
# Run-Tests-Archive.ps1 - PowerShell script to run tests for the Chat Server using an archive

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

Write-Log "Starting Run-Tests-Archive.ps1 script"
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
    
    [Parameter(HelpMessage="Run all tests")]
    [Alias("a")]
    [switch]$All,
    
    [Parameter(HelpMessage="Run only unit tests")]
    [Alias("u")]
    [switch]$Unit,
    
    [Parameter(HelpMessage="Run only integration tests")]
    [Alias("i")]
    [switch]$Integration,
    
    [Parameter(HelpMessage="Run a specific test file or test case")]
    [Alias("s")]
    [string]$Specific,
    
    [Parameter(HelpMessage="Run tests with coverage report")]
    [Alias("c")]
    [switch]$Coverage,
    
    [Parameter(HelpMessage="Run tests with verbose output")]
    [Alias("v")]
    [switch]$Verbose,
    
    [Parameter(HelpMessage="Set extraction directory")]
    [Alias("e")]
    [string]$ExtractDir = "chat-server-test",
    
    [Parameter(HelpMessage="Clean extraction directory before extracting")]
    [switch]$Clean,
    
    [Parameter(HelpMessage="Specify a specific release tag to download (instead of latest)")]
    [string]$Release,
    
    [Parameter(HelpMessage="Specify a local archive file to use instead of downloading")]
    [string]$Archive,
    
    [Parameter(HelpMessage="Set logging mode: file, console, both, none")]
    [ValidateSet("file", "console", "both", "none")]
    [string]$LoggingMode = "both",
    
    [Parameter(HelpMessage="Set log file path")]
    [string]$LoggingFile = "Run-Tests-Archive.log"
)

# Set default test mode if none specified
if (-not $All -and -not $Unit -and -not $Integration -and -not $Specific) {
    $All = $true
}

# Print usage information
function Show-Help {
    Write-Host "Usage: .\Run-Tests-Archive.ps1 [options]"
    Write-Host "Run tests for the Chat Server using an archive file (zip, tar.gz, or tgz)."
    Write-Host "If no archive file is provided, the latest release will be downloaded automatically."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help, -h              Show this help message"
    Write-Host "  -All, -a               Run all tests (default)"
    Write-Host "  -Unit, -u              Run only unit tests"
    Write-Host "  -Integration, -i       Run only integration tests"
    Write-Host "  -LoggingMode MODE      Set logging mode: file, console, both, none (default: both)"
    Write-Host "  -LoggingFile FILE      Set log file path (default: Run-Tests-Archive.log)"
    Write-Host "  -Specific, -s PATH     Run a specific test file or test case"
    Write-Host "                          Example: -s tests/test_api.py"
    Write-Host "                          Example: -s tests/test_api.py::TestChatAPI::test_init"
    Write-Host "  -Coverage, -c          Run tests with coverage report"
    Write-Host "  -Verbose, -v           Run tests with verbose output"
    Write-Host "  -ExtractDir, -e DIR    Set extraction directory (default: chat-server-test)"
    Write-Host "  -Clean                 Clean extraction directory before extracting"
    Write-Host "  -Release TAG           Specify a specific release tag to download (instead of latest)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Run-Tests-Archive.ps1 -Archive chat-server.zip        Run all tests from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Unit -Coverage -Archive chat-server.zip  Run unit tests with coverage from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Specific tests/test_api.py -Archive chat-server.zip  Run specific test from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Clean -Archive chat-server.zip          Clean directory before extracting"
    Write-Host "  .\Run-Tests-Archive.ps1                                 Download and run tests on the latest release"
    Write-Host "  .\Run-Tests-Archive.ps1 -Release v1.0.0                Download and run tests on a specific release by tag"
    Write-Host "  .\Run-Tests-Archive.ps1 -Unit                           Download and run unit tests on the latest release"
    Write-Host "  .\Run-Tests-Archive.ps1 -LoggingMode file -LoggingFile test.log  Use custom logging settings"
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

# Extract archive
Write-Log "Extracting archive to $ExtractDir"
Write-Host "Extracting archive to $ExtractDir..."
New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null

# Determine archive type and extract accordingly
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

# Change to extraction directory
Write-Log "Changing to extraction directory: $ExtractDir"
Set-Location -Path $ExtractDir

# Check if test directory exists
Write-Log "Checking for tests directory"
if (-not (Test-Path "tests")) {
    Write-Log "ERROR: No tests directory found"
    Write-Host "Error: No tests directory found in the extracted archive." -ForegroundColor Red
    exit 1
}

# Create and activate virtual environment (always use a virtual environment)
$VenvDir = "venv"
if (-not (Test-Path $VenvDir)) {
    Write-Log "Creating virtual environment at $VenvDir"
    Write-Host "Creating virtual environment..."
    & $PythonCmd -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: Failed to create virtual environment"
        Write-Host "Error: Failed to create virtual environment." -ForegroundColor Red
        exit 1
    }
}

# Activate virtual environment
$ActivateScript = Join-Path -Path $VenvDir -ChildPath "Scripts\Activate.ps1"
Write-Log "Activating virtual environment from $ActivateScript"
if (Test-Path $ActivateScript) {
    Write-Host "Activating virtual environment..."
    & $ActivateScript
} else {
    Write-Log "ERROR: Activation script not found"
    Write-Host "Error: Could not find activation script in virtual environment." -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Log "Installing dependencies from requirements.txt"
Write-Host "Installing dependencies..."
if (Test-Path "requirements.txt") {
    & pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: Failed to install dependencies"
        Write-Host "Error: Failed to install dependencies." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Log "ERROR: requirements.txt not found"
    Write-Host "Error: No requirements.txt found in the extracted archive." -ForegroundColor Red
    exit 1
}

# Install test dependencies
Write-Log "Installing test dependencies (pytest, pytest-cov)"
& pip install pytest pytest-cov
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Failed to install test dependencies"
    Write-Host "Error: Failed to install test dependencies." -ForegroundColor Red
    exit 1
}



# Prepare the test command
Write-Log "Preparing test command based on selected test modes"
$TestCmd = ""

if ($All) {
    Write-Log "Selected test mode: all"
    Write-Host "Running all tests..."
    $TestCmd = "python -m pytest tests/"
    
    if ($Coverage) {
        Write-Log "Coverage enabled"
        $TestCmd = "python -m pytest --cov=src tests/"
    }
} elseif ($Unit) {
    Write-Log "Selected test mode: unit"
    Write-Host "Running unit tests..."
    
    # Define unit test files (excluding integration tests)
    $UnitTests = Get-ChildItem -Path "tests" -Filter "test_*.py" | 
                 Where-Object { $_.Name -ne "test_integration.py" } |
                 ForEach-Object { "tests/$($_.Name)" }
    
    $UnitTestsStr = $UnitTests -join " "
    Write-Log "Found unit tests: $UnitTestsStr"
    
    if ($Coverage) {
        Write-Log "Coverage enabled"
        $TestCmd = "python -m pytest --cov=src $UnitTestsStr"
    } else {
        $TestCmd = "python -m pytest $UnitTestsStr"
    }
} elseif ($Integration) {
    Write-Log "Selected test mode: integration"
    Write-Host "Running integration tests..."
    
    if ($Coverage) {
        Write-Log "Coverage enabled"
        $TestCmd = "python -m pytest --cov=src tests/test_integration.py"
    } else {
        $TestCmd = "python -m pytest tests/test_integration.py"
    }
} elseif ($Specific) {
    if ([string]::IsNullOrEmpty($Specific)) {
        Write-Log "ERROR: No specific test provided"
        Write-Host "Error: No specific test provided." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Selected test mode: specific - $Specific"
    Write-Host "Running specific test: $Specific"
    
    if ($Coverage) {
        Write-Log "Coverage enabled"
        $TestCmd = "python -m pytest --cov=src $Specific"
    } else {
        $TestCmd = "python -m pytest $Specific"
    }
}

# Add verbose flag if requested
if ($Verbose) {
    Write-Log "Verbose mode enabled"
    $TestCmd = "$TestCmd -v"
}

# Run the tests
try {
    Write-Log "Executing test command: $TestCmd"
    Invoke-Expression $TestCmd
    $ExitCode = $LASTEXITCODE
    
    # Display test results
    if ($ExitCode -eq 0) {
        Write-Log "Tests completed successfully"
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Log "Tests failed with exit code $ExitCode"
        Write-Host "Tests failed with exit code $ExitCode" -ForegroundColor Red
        exit $ExitCode
    }
} catch {
    Write-Log "ERROR: Exception while running tests - $_"
    Write-Host "Error running tests: $_" -ForegroundColor Red
    exit 1
}

# Return to original directory
Set-Location -Path $PSScriptRoot
