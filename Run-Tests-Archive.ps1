#
# Run-Tests-Archive.ps1 - PowerShell script to run tests for the Chat Server using an archive
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
    
    [Parameter(HelpMessage="Run code formatter (ruff format)")]
    [Alias("f")]
    [switch]$Format,
    
    [Parameter(HelpMessage="Run linter (ruff check)")]
    [Alias("l")]
    [switch]$Lint,
    
    [Parameter(HelpMessage="Set extraction directory")]
    [Alias("e")]
    [string]$ExtractDir = "chat-server-test",
    
    [Parameter(HelpMessage="Clean extraction directory before extracting")]
    [switch]$Clean,
    
    [Parameter(HelpMessage="Download and use the latest release from GitHub")]
    [switch]$Latest,
    
    [Parameter(HelpMessage="Specify the GitHub repository (owner/name)")]
    [string]$Repo = "Jeff-Lowrey/ChatServer",
    
    [Parameter(Position=0, HelpMessage="Archive file to extract and run tests on (not required with --latest)")]
    [string]$ArchiveFile
)

# Set default test mode if none specified
if (-not $All -and -not $Unit -and -not $Integration -and -not $Specific) {
    $All = $true
}

# Print usage information
function Show-Help {
    Write-Host "Usage: .\Run-Tests-Archive.ps1 [options] [<archive-file>]"
    Write-Host "Run tests for the Chat Server using an archive file (zip, tar.gz, or tgz)."
    Write-Host "If no archive file is provided and -Latest is used, the latest release will be downloaded."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help, -h              Show this help message"
    Write-Host "  -All, -a               Run all tests (default)"
    Write-Host "  -Unit, -u              Run only unit tests"
    Write-Host "  -Integration, -i       Run only integration tests"
    Write-Host "  -Specific, -s PATH     Run a specific test file or test case"
    Write-Host "                          Example: -s tests/test_api.py"
    Write-Host "                          Example: -s tests/test_api.py::TestChatAPI::test_init"
    Write-Host "  -Coverage, -c          Run tests with coverage report"
    Write-Host "  -Verbose, -v           Run tests with verbose output"
    Write-Host "  -Format, -f            Run code formatter (ruff format)"
    Write-Host "  -Lint, -l              Run linter (ruff check)"
    Write-Host "  -ExtractDir, -e DIR    Set extraction directory (default: chat-server-test)"
    Write-Host "  -Clean                 Clean extraction directory before extracting"
    Write-Host "  -Latest                Download and use the latest release from GitHub"
    Write-Host "  -Repo OWNER/NAME       Specify the GitHub repository (default: Jeff-Lowrey/ChatServer)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Run-Tests-Archive.ps1 chat-server.zip                 Run all tests from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Unit -Coverage chat-server.zip  Run unit tests with coverage from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Specific tests/test_api.py chat-server.zip  Run specific test from archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Lint -Format chat-server.zip    Run linter and formatter on extracted archive"
    Write-Host "  .\Run-Tests-Archive.ps1 -Clean chat-server.zip          Clean directory before extracting"
    Write-Host "  .\Run-Tests-Archive.ps1 -Latest                         Download and run tests on the latest release"
    Write-Host "  .\Run-Tests-Archive.ps1 -Latest -Unit                   Download and run unit tests on the latest release"
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

# Extract archive
Write-Host "Extracting archive to $ExtractDir..."
New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null

# Determine archive type and extract accordingly
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

# Change to extraction directory
Set-Location -Path $ExtractDir

# Check if test directory exists
if (-not (Test-Path "tests")) {
    Write-Host "Error: No tests directory found in the extracted archive." -ForegroundColor Red
    exit 1
}

# Create and activate virtual environment
$VenvDir = "venv"
if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment..."
    & $PythonCmd -m venv $VenvDir
}

# Activate virtual environment
$ActivateScript = Join-Path -Path $VenvDir -ChildPath "Scripts\Activate.ps1"
if (Test-Path $ActivateScript) {
    Write-Host "Activating virtual environment..."
    & $ActivateScript
} else {
    Write-Host "Error: Could not find activation script in virtual environment." -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "Installing dependencies..."
if (Test-Path "requirements.txt") {
    & pip install -r requirements.txt
} else {
    Write-Host "Error: No requirements.txt found in the extracted archive." -ForegroundColor Red
    exit 1
}

# Install test dependencies
& pip install pytest pytest-cov ruff

# Run formatter if requested
if ($Format) {
    Write-Host "Running code formatter..."
    & ruff format .
}

# Run linter if requested
if ($Lint) {
    Write-Host "Running linter..."
    & ruff check .
}

# Prepare the test command
$TestCmd = ""

if ($All) {
    Write-Host "Running all tests..."
    $TestCmd = "pytest tests/"
    
    if ($Coverage) {
        $TestCmd = "pytest --cov=src tests/"
    }
} elseif ($Unit) {
    Write-Host "Running unit tests..."
    
    # Define unit test files (excluding integration tests)
    $UnitTests = Get-ChildItem -Path "tests" -Filter "test_*.py" | 
                 Where-Object { $_.Name -ne "test_integration.py" } |
                 ForEach-Object { "tests/$($_.Name)" }
    
    $UnitTestsStr = $UnitTests -join " "
    
    if ($Coverage) {
        $TestCmd = "pytest --cov=src $UnitTestsStr"
    } else {
        $TestCmd = "pytest $UnitTestsStr"
    }
} elseif ($Integration) {
    Write-Host "Running integration tests..."
    
    if ($Coverage) {
        $TestCmd = "pytest --cov=src tests/test_integration.py"
    } else {
        $TestCmd = "pytest tests/test_integration.py"
    }
} elseif ($Specific) {
    if ([string]::IsNullOrEmpty($Specific)) {
        Write-Host "Error: No specific test provided." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Running specific test: $Specific"
    
    if ($Coverage) {
        $TestCmd = "pytest --cov=src $Specific"
    } else {
        $TestCmd = "pytest $Specific"
    }
}

# Add verbose flag if requested
if ($Verbose) {
    $TestCmd = "$TestCmd -v"
}

# Run the tests
try {
    Invoke-Expression $TestCmd
    $ExitCode = $LASTEXITCODE
    
    # Display test results
    if ($ExitCode -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "Tests failed with exit code $ExitCode" -ForegroundColor Red
        exit $ExitCode
    }
} catch {
    Write-Host "Error running tests: $_" -ForegroundColor Red
    exit 1
}

# Return to original directory
Set-Location -Path $PSScriptRoot
