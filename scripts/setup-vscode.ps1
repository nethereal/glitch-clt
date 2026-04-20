#Requires -Version 5.1
<#
.SYNOPSIS
    Configures VS Code Insiders Copilot Chat to use the local Qwen 3.6 TurboQuant server.
.DESCRIPTION
    This script automatically adds or updates a language model entry in your VS Code
    Insiders chatLanguageModels.json configuration file. It preserves all existing entries
    and intelligently inserts the new llamacpp entry after the "Copilot" entry (or at the
    top if no Copilot entry exists).

.PARAMETER Port
    The port the llama.cpp server is listening on (default: 9998).
.PARAMETER Host
    The host address (default: localhost).
.PARAMETER ModelName
    Display name for the model in VS Code UI (default: "Qwen 3.6 35B A3B Turbo").
.PARAMETER ContextLength
    Maximum input context length in tokens (default: 262144).
.PARAMETER MaxOutputTokens
    Maximum output tokens per completion (default: 8192).
.PARAMETER UseNativeProvider
    If set, uses vendor "llamacpp" instead of "customoai". Requires a newer Insiders build.
.EXAMPLE
    .\scripts\setup-vscode.ps1
    .\scripts\setup-vscode.ps1 -Port 8000 -ModelName "My Custom Model"
    .\scripts\setup-vscode.ps1 -UseNativeProvider
#>

[CmdletBinding()]
param(
    [int]$Port = 9998,
    [string]$Host = "localhost",
    [string]$ModelName = "Qwen 3.6 35B A3B Turbo",
    [int]$ContextLength = 262144,
    [int]$MaxOutputTokens = 8192,
    [switch]$UseNativeProvider
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$ScriptVersion = "1.0.0"
$EntryName = "llamacpp-turboquant"
$VendorCustomOAI = "customoai"
$VendorNative = "llamacpp"
$ModelId = "qwen3.6-35b-a3b-iq4xs"

# --- Helper Functions ---
function Get-VSCodeInsidersUserDataPath {
    $envVar = $env:APPDATA
    if (-not $envVar) {
        Write-Error "Could not determine APPDATA environment variable."
        exit 1
    }
    return Join-Path $envVar "Code - Insiders\User"
}

# --- Main Logic ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  glitch-CLT — VS Code Copilot Chat Setup" -ForegroundColor Cyan
Write-Host "  Script v$ScriptVersion" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Get the configuration file path
$userDataPath = Get-VSCodeInsidersUserDataPath
$configFile = Join-Path $userDataPath "chatLanguageModels.json"

Write-Host "[1/5] Configuration file: $configFile" -ForegroundColor Yellow

# Check if VS Code Insiders is running
$vscodeProcesses = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue
if ($vscodeProcesses) {
    Write-Warning "VS Code Insiders appears to be running. Changes may not take effect until restart."
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Red
        exit 0
    }
}

# Create the file if it doesn't exist
if (-not (Test-Path $configFile)) {
    Write-Host "[2/5] Creating new configuration file..." -ForegroundColor Yellow
    @() | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
}

# Read existing config
Write-Host "[2/5] Reading existing configuration..." -ForegroundColor Yellow
$configContent = Get-Content -Path $configFile -Raw -ErrorAction Stop
try {
    $existingConfig = $configContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Failed to parse JSON in $configFile. Please check the file manually."
    Write-Error $_.Exception.Message
    exit 1
}

# Build the new model entry
$stopSequences = @("```", "</s>", "``")
$modelEntry = @{
    id              = $ModelId
    name            = $ModelName
    url             = "http://${Host}:${Port}/v1"
    api_key         = "not-needed"
    toolCalling     = $true
    vision          = $false
    maxInputTokens  = $ContextLength
    maxOutputTokens = $MaxOutputTokens
    completionOptions = @{
        stop = $stopSequences
    }
}

# Determine vendor type
if ($UseNativeProvider) {
    $vendorType = $VendorNative
    Write-Host "[3/5] Using native 'llamacpp' vendor (requires newer Insiders build)" -ForegroundColor Yellow
} else {
    $vendorType = $VendorCustomOAI
    Write-Host "[3/5] Using 'customoai' vendor" -ForegroundColor Yellow
}

# Build the new entry object
$newEntry = @{
    name   = $EntryName
    vendor = $vendorType
    models = @($modelEntry)
}

# Check if entry already exists and update or create
$existingIndex = $null
for ($i = 0; $i -lt $existingConfig.Count; $i++) {
    if ($existingConfig[$i].name -eq $EntryName) {
        $existingIndex = $i
        break
    }
}

if ($existingIndex -ne $null) {
    # Update existing entry in place
    $existingConfig[$existingIndex] = $newEntry
    Write-Host "[4/5] Updated existing entry '$EntryName'" -ForegroundColor Green
} else {
    # Insert new entry after "Copilot" or at the beginning
    $copilotIndex = $null
    for ($i = 0; $i -lt $existingConfig.Count; $i++) {
        if ($existingConfig[$i].name -eq "Copilot") {
            $copilotIndex = $i
            break
        }
    }

    if ($copilotIndex -ne $null) {
        # Build new array: insert after Copilot
        $newConfig = @()
        for ($i = 0; $i -le $copilotIndex; $i++) {
            $newConfig += $existingConfig[$i]
        }
        $newConfig += $newEntry
        for ($i = $copilotIndex + 1; $i -lt $existingConfig.Count; $i++) {
            $newConfig += $existingConfig[$i]
        }
        $configToWrite = $newConfig
    } else {
        # Add as first entry
        $newConfig = @($newEntry)
        for ($i = 0; $i -lt $existingConfig.Count; $i++) {
            $newConfig += $existingConfig[$i]
        }
        $configToWrite = $newConfig
    }
    Write-Host "[4/5] Added new entry '$EntryName'" -ForegroundColor Green
}

# Write updated config back
Write-Host "[5/5] Writing configuration..." -ForegroundColor Yellow
$jsonOutput = $configToWrite | ConvertTo-Json -Depth 10
$jsonOutput | Out-File -FilePath $configFile -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Configuration complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Model:      $ModelName ($ModelId)" -ForegroundColor White
Write-Host "URL:        http://${Host}:${Port}/v1" -ForegroundColor White
Write-Host "Context:    $ContextLength tokens" -ForegroundColor White
Write-Host "Vendor:     $vendorType" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Start the Docker container: docker compose up -d" -ForegroundColor Gray
Write-Host "  2. Restart VS Code Insiders (if already open)" -ForegroundColor Gray
Write-Host "  3. Open Copilot Chat and select '$EntryName' from the model picker" -ForegroundColor Gray
Write-Host ""
