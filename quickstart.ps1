#Requires -Version 5.1
<#
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

# --- Main ---
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║          glitch-CLT — Quickstart v$ScriptVersion              ║" -ForegroundColor Magenta
Write-Host "║  One-command setup for local Qwen 3.6 + Copilot Chat    ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
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

# Download model
Write-Step "2/5" "Downloading model (~18GB)..."
$modelPath = Join-Path $cloneDir "models"
if (Test-Path (Join-Path $modelPath "$ModelFile")) {
    Write-Success "Model file already exists: $ModelFile"
} else {
    if (-not (Test-CommandExists huggingface-cli)) {
        Write-Error "`nhuggingface-cli not found. Please install it first:"
        Write-Error "  pip install huggingface_hub"
        exit 1
    }

    # Create models directory if needed
    if (-not (Test-Path $modelPath)) { New-Item -ItemType Directory -Path $modelPath | Out-Null }

    Write-Host "  Downloading from HuggingFace: $ModelRepo/$ModelFile" -ForegroundColor Gray
    Write-Host "  This may take 10-30 minutes depending on your connection..." -ForegroundColor Gray
    Write-Host ""

    try {
        huggingface-cli download $ModelRepo $ModelFile --local-dir "$modelPath" 2>&1 | ForEach-Object {
            # Show progress without overwhelming the output
            if ($_ -match '(\d+)%') {
                $progress = [int]$Matches[1]
                if ($progress % 5 -eq 0) {
                    Write-Host "  Downloading... $progress%" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
        Write-Success "Model downloaded successfully"
    } catch {
        Write-Error "`nFailed to download model. Check your internet connection and try again."
        Write-Error "You can also download manually from:"
        Write-Error "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF?show_file_info=$([Uri]::EscapeDataString($ModelFile))"
        exit 1
    }
}

# Configure VS Code
Write-Step "3/5" "Configuring VS Code Insiders..."
try {
    & "$PSScriptRoot\scripts\setup-vscode.ps1" -Port $Port -ContextLength $ContextLength
    Write-Success "VS Code configuration complete"
} catch {
    Write-Warn "VS Code setup encountered an issue: $_"
    Write-Host "  You can run it manually later: .\scripts\setup-vscode.ps1" -ForegroundColor Gray
}

# Start Docker server
Write-Step "4/5" "Starting Docker container..."
try {
    docker compose up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker container started (building on first run)"
    } else {
        # Try without suppressing output to see errors
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
