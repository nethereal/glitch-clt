#Requires -Version 5.1
<#
.SYNOPSIS
    One-command setup for glitch-CLT — clones and launches internal installer.
#>

[CmdletBinding()]
param(
    [string]$ClonePath = ".",
    [int]$Port = 9998,
    [int]$ContextLength = 262144
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/nethereal/glitch-clt.git"
$RepoName = "glitch-clt"

function Write-Step { param([string]$Num, [string]$Text) Write-Host "`n[$Num] $Text" -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host "  [OK] $Text" -ForegroundColor Green }

Write-Host "`n************************************************************" -ForegroundColor Magenta
Write-Host "*             glitch-CLT — Quickstart Bootstrapper       *" -ForegroundColor Magenta
Write-Host "************************************************************`n" -ForegroundColor Magenta

# 1. Resolve Location
$basePath = Resolve-Path $ClonePath
$cloneDir = Join-Path $basePath $RepoName

# Check if we are already INSIDE the repo
$currentDir = (Get-Location).Path
if ($currentDir -like "*$RepoName" -and (Test-Path "$currentDir\.git")) {
    $cloneDir = $currentDir
    Write-Success "Already inside repository directory: $cloneDir"
} elseif (Test-Path $cloneDir) {
    Write-Success "Repository already exists at: $cloneDir"
} else {
    Write-Step "1/2" "Cloning repository..."
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    git clone --recurse-submodules $RepoUrl $cloneDir
    $ErrorActionPreference = $oldPreference
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone repository. Please check your internet connection."
        exit 1
    }
    Write-Success "Cloned to $cloneDir"
}

# 2. Run Installer
Write-Step "2/2" "Running internal installer..."
Set-Location $cloneDir
if (Test-Path "install.ps1") {
    & .\install.ps1 -Port $Port -ContextLength $ContextLength
} else {
    Write-Error "Could not find install.ps1 in $cloneDir"
    exit 1
}
