#Requires -Version 5.1
<#
.SYNOPSIS
    Configures VS Code Insiders Copilot Chat to use the local Qwen 3.6 TurboQuant server.
#>

[CmdletBinding()]
param(
    [int]$Port = 9998,
    [string]$tgtHost = "localhost",
    [string]$ModelName = "Qwen 3.6 35B A3B (Local)",
    [int]$ContextLength = 262144,
    [int]$MaxOutputTokens = 8192,
    [switch]$UseNativeProvider
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$EntryName = "Glitch-CLT-Qwen3.6-35B"
$VendorCustomOAI = "customoai"
$VendorNative = "llamacpp"
$ModelId = "qwen3.6-35b-local"
$vendorType = $VendorCustomOAI
if ($UseNativeProvider) { $vendorType = $VendorNative }

function Get-VSCodeInsidersUserDataPath {
    $envVar = $env:APPDATA
    if (-not $envVar) { return $null }
    return Join-Path $envVar "Code - Insiders\User"
}

Write-Host ""
Write-Host "************************************************************" -ForegroundColor Cyan
Write-Host "*             glitch-CLT -- VS Code Setup                *" -ForegroundColor Cyan
Write-Host "************************************************************" -ForegroundColor Cyan
Write-Host ""

$userDataPath = Get-VSCodeInsidersUserDataPath
if ($null -eq $userDataPath) {
    Write-Error "Could not find VS Code Insiders user data path."
    exit 1
}
$configFile = Join-Path $userDataPath "chatLanguageModels.json"

Write-Host "[1/5] Config file: $configFile" -ForegroundColor Yellow

$vscodeWasRunning = $null -ne (Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue)

if (-not (Test-Path $configFile)) {
    Write-Host "[2/5] Creating new config file..." -ForegroundColor Yellow
    @() | ConvertTo-Json | Out-File -FilePath $configFile -Encoding UTF8
}

Write-Host "[2/5] Reading existing configuration..." -ForegroundColor Yellow
$configContent = Get-Content -Path $configFile -Raw
try {
    $existingConfig = $configContent | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON in $configFile"
    exit 1
}

# Ensure $existingConfig is an array
if ($null -eq $existingConfig) { $existingConfig = @() }
elseif ($existingConfig -isnot [Array]) { $existingConfig = @($existingConfig) }

# Define the new entry as an object rather than a string template to avoid here-string issues
$newEntry = @{
    "name" = $EntryName
    "vendor" = $vendorType
    "models" = @(
        @{
            "id" = $ModelId
            "name" = $ModelName
            "url" = "http://$($tgtHost):$($Port)/v1"
            "api_key" = "not-needed"
            "toolCalling" = $true
            "vision" = $false
            "maxInputTokens" = $ContextLength
            "maxOutputTokens" = $MaxOutputTokens
            "completionOptions" = @{
                "stop" = @("<|im_end|>", "<|im_start|>", "<|endoftext|>")
            }
        }
    )
}

# Update or Add
$found = $false
for ($i = 0; $i -lt $existingConfig.Count; $i++) {
    if ($existingConfig[$i].name -eq $EntryName) {
        $existingConfig[$i] = $newEntry
        $found = $true
        Write-Host "[4/5] Updated existing entry: $EntryName" -ForegroundColor Green
        break
    }
}

if (-not $found) {
    # Try to insert after Copilot
    $inserted = $false
    $newConfig = @()
    for ($i = 0; $i -lt $existingConfig.Count; $i++) {
        $newConfig += $existingConfig[$i]
        if ($existingConfig[$i].name -eq "Copilot") {
            $newConfig += $newEntry
            $inserted = $true
        }
    }
    
    if (-not $inserted) {
        # Prepend to start if Copilot not found
        $configToWrite = @($newEntry) + $existingConfig
    } else {
        $configToWrite = $newConfig
    }
    Write-Host "[4/5] Added new entry: $EntryName" -ForegroundColor Green
} else {
    $configToWrite = $existingConfig
}

Write-Host "[5/5] Writing configuration..." -ForegroundColor Yellow
$configToWrite | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8

Write-Host ""
Write-Host "Success! VS Code configuration updated." -ForegroundColor Green
Write-Host "URL: http://$($tgtHost):$($Port)/v1" -ForegroundColor Gray
if ($vscodeWasRunning) {
    Write-Warning "VS Code Insiders is running. Please restart it to apply changes."
}
Write-Host ""
