#Requires -Version 5.1
<#!
.SYNOPSIS
    One-command setup for glitch-CLT — clones, downloads model, configures VS Code, and launches server.
.DESCRIPTION
    This is the fastest way to get glitch-CLT running end-to-end. It assumes all prerequisites are installed:
      1. Docker Desktop (with NVIDIA Container Toolkit)
      2. Git
      3. huggingface_hub (pip install huggingface_hub)
      4. VS Code Insiders with Copilot Chat support

.PARAMETER ClonePath
    Parent directory where the repo will be cloned (default: current directory).
.PARAMETER Port
    Server port (default: 9998).
.PARAMETER ContextLength
    Context window in tokens (default: 262144).
.EXAMPLE
    .\quickstart.ps1
    .\quickstart.ps1 -ClonePath "C:\projects" -Port 8000
#>

[CmdletBinding()]
param(
    [string]$ClonePath = ".",
    [int]$Port = 9998,
    [int]$ContextLength = 262144
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = 'utf-8' # Fix for Windows Unicode character encoding

# --- Constants ---
$RepoUrl = "https://github.com/nethereal/glitch-clt.git"
$RepoName = "glitch-clt"
$ModelRepo = "unsloth/Qwen3.6-35B-A3B-GGUF"
$ModelFile = "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf"
$ScriptVersion = "1.0.0"

# --- Helpers ---
function Write-Step { param([string]$Num, [string]$Text) Write-Host "`n[$Num] $Text" -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host "  ✓ $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Warning $Text }
function Test-CommandExists { param([string]$Name); return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

# --- Prerequisite Check ---
Write-Step "0/5" "Checking prerequisites..."

# Visual prereq check
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
    Write-Host "\nPlease install the missing prerequisites and re-run this script." -ForegroundColor Yellow
    exit 1
} else {
    Write-Success "All prerequisites satisfied."
}

# --- Main ---
Write-Host ""

# --- Dynamic ASCII Header ---
$boxWidth = 58
$top = "╔" + ("═" * ($boxWidth - 2)) + "╗"
$bottom = "╚" + ("═" * ($boxWidth - 2)) + "╝"
$title = "glitch-CLT — Quickstart v$ScriptVersion"
$subtitle = "One-command setup for local Qwen 3.6 + Copilot Chat"
function PadCenter($text, $width) {
    $pad = [Math]::Max(0, $width - 2 - $text.Length)
    $left = [Math]::Floor($pad / 2)
    $right = $pad - $left
    return "║" + (" " * $left) + $text + (" " * $right) + "║"
}
Write-Host $top -ForegroundColor Magenta
Write-Host (PadCenter $title $boxWidth) -ForegroundColor Magenta
Write-Host (PadCenter $subtitle $boxWidth) -ForegroundColor Magenta
Write-Host $bottom -ForegroundColor Magenta
Write-Host ""

# Resolve clone path
$cloneDir = Join-Path (Resolve-Path $ClonePath) $RepoName
if (Test-Path $cloneDir) {
    Write-Success "Repository already exists at: $cloneDir"
} else {
    Write-Step "1/5" "Cloning repository..."
    git clone --recurse-submodules $RepoUrl $cloneDir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        # Try without submodules first, then init separately
        git clone $RepoUrl $cloneDir 2>&1 | Out-Null
        Set-Location $cloneDir
        git submodule update --init --recursive 2>&1 | Out-Null
    }
    Write-Success "Cloned to $cloneDir"
}

Set-Location $cloneDir

# Verify submodule is present
if (-not (Test-Path "llama.cpp-turboquant")) {
    Write-Step "1b/5" "Initializing submodules..."
    git submodule update --init --recursive 2>&1 | Out-Null
    Write-Success "Submodule initialized"
} else {
    Write-Success "Submodule already present"
}

# --- Environment Setup ---
Write-Step "1c/5" "Configuring environment files..."
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Success "Created .env from .env.example"
    } else {
        # Create a basic .env if example is missing
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

# Download model
Write-Step "2/5" "Downloading model (~18GB)..."
$modelPath = Join-Path $cloneDir "models"
if (Test-Path (Join-Path $modelPath "$ModelFile")) {
    Write-Success "Model file already exists: $ModelFile"
} else {

    # Create models directory if needed
    if (-not (Test-Path $modelPath)) { New-Item -ItemType Directory -Path $modelPath | Out-Null }

    Write-Host "  Downloading from HuggingFace: $ModelRepo/$ModelFile" -ForegroundColor Gray
    Write-Host "  This may take 10-30 minutes depending on your connection..." -ForegroundColor Gray
    Write-Host ""

    try {
        $downloadOutput = hf download $ModelRepo $ModelFile --local-dir $modelPath 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $modelPath $ModelFile))) {
            Write-Success "Model downloaded successfully"
        } else {
            Write-Error "`nFailed to download model. Output:"
            Write-Host $downloadOutput -ForegroundColor Red
            Write-Error "You can also download manually from:"
            Write-Error "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/$($ModelFile)?download=true"
            Write-Error "Then place the file in: $modelPath"
            exit 1
        }
    } catch {
        Write-Error "`nFailed to download model. Check your internet connection and try again."
        Write-Error "You can also download manually from:"
        Write-Error "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/$($ModelFile)?download=true"
        Write-Error "Then place the file in: $modelPath"
        exit 1
    }
}

# Configure VS Code
Write-Step "3/5" "Configuring VS Code Insiders..."
try {
    & (Join-Path $cloneDir 'scripts' 'setup-vscode.ps1') -Port $Port -ContextLength $ContextLength
    Write-Success "VS Code configuration complete"
} catch {
    Write-Warn "VS Code setup encountered an issue: $_"
    Write-Host "  You can run it manually later: .\scripts\setup-vscode.ps1" -ForegroundColor Gray
}

# Start Docker server
Write-Step "4/5" "Starting Docker container..."
try {
    Write-Host "  Running: docker compose up -d" -ForegroundColor DarkGray
    $dockerOutput = docker compose up -d 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker container started (building on first run)"
        if ($dockerOutput) {
            Write-Host $dockerOutput -ForegroundColor Gray
        }
    } else {
        Write-Warn "Docker compose up -d returned a non-zero exit code. Output:"
        Write-Host $dockerOutput -ForegroundColor Red
        Write-Host "  Retrying without output suppression..." -ForegroundColor Yellow
        docker compose up -d
    }
} catch {
    Write-Warn "Docker compose failed: $_"
    Write-Host "  You can start it manually later: docker compose up -d" -ForegroundColor Gray
}

# Wait for server health check
Write-Step "5/5" "Waiting for server to be ready..."
$maxWait = 180  # 3 minutes max for initial build
$elapsed = 0
$interval = 5
while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds $interval
    $elapsed += $interval

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/v1/models" -TimeoutSec 3 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "Server is responding! (took $($elapsed)s)"
            break
        }
    } catch {}

    if ($elapsed % 15 -eq 0) {
        # Check if container is building or running
        $containerStatus = docker ps --filter "name=glitch-clt-server" --format "{{.Status}}" 2>$null
        if ([string]::IsNullOrWhiteSpace($containerStatus)) {
            $containerStatus = docker ps -a --filter "name=glamacpp-qwen3-6-35b-a3b-iq4xs" --format "{{.Status}}" 2>$null
        }
        $statusText = if ($elapsed -lt 60) { 'building' } else { 'loading model' }
        Write-Host "  Waiting... ($statusText — ${elapsed}s elapsed)" -ForegroundColor DarkGray
    }
}

if ($elapsed -ge $maxWait) {
    Write-Warn "Server didn't respond within ${maxWait}s. It may still be building."
    Write-Host "  Check status: docker logs glitch-clt-server" -ForegroundColor Gray
    Write-Host "  Or wait and retry: curl http://localhost:$Port/v1/models" -ForegroundColor Gray
}

# Launch VS Code Insiders
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Model URL:   http://localhost:${Port}/v1" -ForegroundColor White
Write-Host "Container:   glitch-clt-server" -ForegroundColor White
Write-Host "Model file:  $modelPath\$ModelFile" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  • Open Copilot Chat (Ctrl+Shift+P → 'Copilot Chat')" -ForegroundColor Gray
Write-Host "  • Select 'llamacpp-turboquant' from the model picker" -ForegroundColor Gray
Write-Host "  • Start chatting with your local Qwen 3.6!" -ForegroundColor Gray
Write-Host ""

# Launch VS Code Insiders
try {
    Write-Host "Launching VS Code Insiders..." -ForegroundColor Yellow
    Start-Process "code-insiders" -ArgumentList "." -ErrorAction Stop
    Write-Success "VS Code Insiders launched"
} catch {
    # Try alternate names
    $alternatives = @("Code - Insiders", "code-insiders.exe")
    $launched = $false
    foreach ($cmd in $alternatives) {
        try {
            Start-Process $cmd -ArgumentList (Get-Location).Path -ErrorAction Stop
            Write-Success "$cmd launched"
            $launched = $true
            break
        } catch {}
    }
    if (-not $launched) {
        Write-Warn "Could not launch VS Code Insiders automatically."
        Write-Host "  Open it manually: code-insiders ." -ForegroundColor Gray
    }
}

Write-Host ""
