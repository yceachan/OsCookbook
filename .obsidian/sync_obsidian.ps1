<#
.SYNOPSIS
    Syncs the .obsidian configuration directory from a remote Git repository to the current location.
    Safe to run inside existing Git repositories.

.DESCRIPTION
    This script performs the following steps:
    1. Creates a temporary directory.
    2. Clones the remote repository (sparse, no-checkout, depth 1) into temp.
    3. Sparse-checkouts only the .obsidian directory.
    4. Copies the .obsidian directory to the current location (overwriting existing).
    5. Cleans up the temporary directory.

.EXAMPLE
    # Run via One-Liner (PowerShell)
    irm https://raw.githubusercontent.com/yceachan/OsCookbook/main/sync_obsidian.ps1 | iex
#>

param (
    [string]$RepoUrl = "git@github.com:yceachan/OsCookbook.git",
    [string]$Branch = "main",
    [string]$TargetDir = $PWD.Path
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[Sync-Obsidian] $Message" -ForegroundColor Cyan
}

try {
    # 1. Setup Temporary Directory
    $TempGuid = [System.Guid]::NewGuid().ToString()
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "obsidian-sync-$TempGuid"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    Write-Log "Created temp workspace: $TempDir"

    # 2. Git Clone (Sparse & Partial)
    Write-Log "Cloning metadata from $RepoUrl..."
    Push-Location $TempDir
    try {
        # Initialize an empty git repo to configure sparse checkout before fetching full tree
        git init -b $Branch
        git remote add origin $RepoUrl
        git config core.sparseCheckout true

        # Define what we want
        Set-Content -Path .git/info/sparse-checkout -Value ".obsidian/"

        # Pull only the needed files
        git pull --depth 1 origin $Branch
    }
    finally {
        Pop-Location
    }

    # 3. Copy to Target
    $SourcePath = Join-Path $TempDir ".obsidian"
    if (-not (Test-Path $SourcePath)) {
        throw "The .obsidian directory was not found in the remote repository."
    }

    $DestPath = Join-Path $TargetDir ".obsidian"
    Write-Log "Syncing configuration to $DestPath..."
    
    # Ensure destination exists (though Copy-Item usually handles the folder structure)
    if (-not (Test-Path $DestPath)) {
        New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
    }

    # Copy and overwrite
    Copy-Item -Path "$SourcePath\*" -Destination $DestPath -Recurse -Force

    Write-Log "Synchronization complete!"

}
catch {
    Write-Error "Sync failed: $_"
    exit 1
}
finally {
    # 4. Cleanup
    if (Test-Path $TempDir) {
        Write-Log "Cleaning up temp files..."
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $TempDir)) {
            Write-Log "Temporary workspace successfully removed."
        }
    }
}
