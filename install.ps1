#Requires -Version 5.1
<#
.SYNOPSIS
    Internal installation script for glitch-CLT. 
    Assumes the repository is already cloned and current location is the repo root.
#>

[CmdletBinding()]
param(
    [int]$Port = 9998,
    [int]$ContextLength = 262144
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = 'utf-8'

# --- Constants ---
$ModelRepo = "unsloth/Qwen3.6-35B-A3B-GGUF"
$ModelFile = "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf"
$ScriptVersion = "1.0.0"

# --- Helpers ---
function Write-Step { param([string]$Num, [string]$Text) Write-Host "`n[$Num] $Text" -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host "  ✓ $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Warning $Text }
function Test-CommandExists { param([string]$Name); return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

# --- Prerequisite Check ---
Write-Step "0/4" "Checking prerequisites..."

$allOk = $true
Write-Host ""
if (Test-CommandExists docker) {
    Write-Host "  ✓ Docker Desktop (docker)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Docker Desktop (docker)" -ForegroundColor Red
    $allOk = $false
}
if (Test-CommandExists git) {
    Write-Host "  ✓ Git" -ForegroundColor Green
} else {
    Write-Host "  ✗ Git" -ForegroundColor Red
    $allOk = $false
}
$hasHf = Test-CommandExists hf
$hasHfCli = Test-CommandExists huggingface-cli
if ($hasHf -or $hasHfCli) {
    Write-Host "  ✓ Hugging Face CLI (hf or huggingface-cli)" -ForegroundColor Green
} else {
    Write-Host "  ? Hugging Face CLI (hf or huggingface-cli)" -ForegroundColor Yellow
    Write-Host "    Attempting to install huggingface_hub via pip..." -ForegroundColor Gray
    try {
        pip install huggingface_hub --quiet
        Write-Host "  ✓ Hugging Face CLI (Successfully installed)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Hugging Face CLI (Failed to install)" -ForegroundColor Red
        $allOk = $false
    }
}
if (Test-CommandExists code-insiders) {
    Write-Host "  ✓ VS Code Insiders (code-insiders)" -ForegroundColor Green
} else {
    Write-Host "  ✗ VS Code Insiders (code-insiders)" -ForegroundColor Red
    $allOk = $false
}

if (-not $allOk) {
    Write-Host "`nPlease install the missing prerequisites and re-run this script." -ForegroundColor Yellow
    exit 1
} else {
    Write-Success "All prerequisites satisfied."
}

# --- Main Infrastructure Setup ---
Write-Host ""
Write-Step "1/4" "Initializing and configuring environment..."

# Verify submodule is present
if (-not (Test-Path "llama.cpp-turboquant")) {
    Write-Host "  Submodule missing. Attempting to initialize..." -ForegroundColor Gray
    git submodule update --init --recursive 2>&1 | Out-Null
    Write-Success "Submodule initialized"
} else {
    Write-Success "Submodule present"
}

# Environment Files
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Success "Created .env from .env.example"
    } else {
        "MODEL_PATH=./models`nMODEL_FILE=$ModelFile`nLLAMACPP_PORT=$Port`nCONTEXT_SIZE=$ContextLength" | Out-File -FilePath ".env" -Encoding UTF8
        Write-Success "Created new .env file"
    }
}

# Inject parameters into .env
$envContent = Get-Content ".env" -Raw
$envContent = $envContent -replace '(?m)^LLAMACPP_PORT=.*$', "LLAMACPP_PORT=$Port"
$envContent = $envContent -replace '(?m)^CONTEXT_SIZE=.*$', "CONTEXT_SIZE=$ContextLength"
$envContent = $envContent -replace '(?m)^MODEL_FILE=.*$', "MODEL_FILE=$ModelFile"
$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Success "Configuration injected into .env (Port: $Port, Context: $ContextLength)"

# --- Model Download ---
Write-Step "2/4" "Downloading model (~18GB)..."
$modelPath = Join-Path (Get-Location).Path "models"
if (Test-Path (Join-Path $modelPath "$ModelFile")) {
    Write-Success "Model file already exists: $ModelFile"
} else {
    if (-not (Test-Path $modelPath)) { New-Item -ItemType Directory -Path $modelPath | Out-Null }
    Write-Host "  Downloading from HuggingFace: $ModelRepo/$ModelFile" -ForegroundColor Gray
    try {
        # Using huggingface-cli for download
        $cmd = if ($hasHfCli) { "huggingface-cli" } else { "hf" }
        & $cmd download $ModelRepo $ModelFile --local-dir $modelPath
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $modelPath $ModelFile))) {
            Write-Success "Model downloaded successfully"
        } else {
            throw "Download failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Error "`nFailed to download model. You can also download manually from:"
        Write-Host "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/$($ModelFile)" -ForegroundColor Cyan
        Write-Host "Then place the file in: $modelPath" -ForegroundColor Gray
        exit 1
    }
}

# --- VS Code Setup ---
Write-Step "3/4" "Configuring VS Code Insiders..."
try {
    & (Join-Path (Get-Location).Path 'scripts' 'setup-vscode.ps1') -Port $Port -ContextLength $ContextLength
    Write-Success "VS Code configuration complete"
} catch {
    Write-Warn "VS Code setup encountered an issue: $_"
    Write-Host "  You can run it manually later: .\scripts\setup-vscode.ps1" -ForegroundColor Gray
}

# --- Docker Start ---
Write-Step "4/4" "Starting Docker container..."
try {
    $dockerOutput = docker compose up -d 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker container started (building on first run)"
    } else {
        Write-Warn "Docker compose failed. Attempting to show output..."
        Write-Host $dockerOutput -ForegroundColor Red
        docker compose up -d
    }
} catch {
    Write-Warn "Docker compose failed: $_"
}

# --- Wrap-up ---
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Model URL:   http://localhost:${Port}/v1" -ForegroundColor White
Write-Host "Context:     $ContextLength" -ForegroundColor White
Write-Host ""
Write-Host "Launching VS Code Insiders..." -ForegroundColor Yellow
try {
    Start-Process "code-insiders" -ArgumentList "." -ErrorAction Stop
} catch {
    Write-Host "  Please open VS Code Insiders manually: code-insiders ." -ForegroundColor Gray
}
Write-Host ""
