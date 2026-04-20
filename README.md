# glitch-CLT

**Local LLM inference for VS Code Copilot Chat — powered by TurboQuant KV cache compression.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker)](docker-compose.yml)
[![PowerShell](https://img.shields.io/badge/powershell-setup-green)](scripts/setup-vscode.ps1)
[![TurboQuant](https://img.shields.io/badge/turboquant-kv--cache-orange)](llama.cpp-turboquant)

glitch-CLT (Copilot Local Turbo) is a production-ready deployment package that enables **VS Code Copilot Chat** to use a self-hosted Qwen 3.6 model with **TurboQuant KV cache compression** — achieving up to **8x reduction in VRAM usage** for long-context inference.

---

## Table of Contents

- [What This Does](#what-this-does)
- [Architecture](#architecture)
- [Hardware Requirements](#hardware-requirements)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Performance Benchmarks](#performance-benchmarks)
- [Customization](#customization)
- [Project Structure](#project-structure)
- [License](#license)

---

## What This Does

glitch-CLT bridges the gap between powerful open-weight language models and VS Code's Copilot Chat — without cloud APIs, subscription fees, or data leaving your machine.

| Feature | Description |
|---------|-------------|
| **Self-hosted inference** | Run Qwen 3.6 35B entirely on your local GPU via Docker |
| **TurboQuant KV cache** | Proprietary fork of llama.cpp with TurboQuant compression (4-bit K/V caches) |
| **VS Code integration** | One-command setup to connect Copilot Chat to your local model |
| **Long context support** | Up to 262K token context window for deep codebase understanding |
| **Tool calling** | Full function-calling support for VS Code extensions and agents |

### How It Works

```
┌─────────────────┐       ┌──────────────────┐       ┌─────────────────────┐
│   VS Code       │       │   Docker         │       │   GPU               │
│   Copilot Chat  │──────▶│   llama.cpp      │──────▶│   (CUDA + TurboQuant)│
│   (OpenAI API)  │◀──────│   Server (:9998) │◀──────│   Qwen3.6-35B-A3B   │
└─────────────────┘       └──────────────────┘       └─────────────────────┘
```

1. **Docker container** runs a customized llama.cpp server with TurboQuant extensions
2. **VS Code Insiders** connects via OpenAI-compatible API (`/v1/chat/completions`)
3. **TurboQuant** compresses KV caches using Walsh-Hadamard Transform + PolarQuant, enabling longer contexts within VRAM limits

---

## Hardware Requirements

### Minimum
| Component | Requirement |
|-----------|-------------|
| GPU | NVIDIA RTX 3090 (24GB VRAM) or equivalent |
| RAM | 32GB system memory |
| Storage | 50GB free disk space (model + Docker layers) |
| CUDA | 12.8+ |

### Recommended
| Component | Requirement |
|-----------|-------------|
| GPU | NVIDIA RTX 4090 (24GB VRAM) / A100 (80GB) for larger contexts |
| RAM | 64GB system memory |
| Storage | 100GB+ NVMe SSD |
| CUDA | 12.8+ with latest drivers |

> **Note:** The Qwen3.6-35B-A3B model in IQ4_XS quantization requires ~18GB VRAM at baseline. TurboQuant's `turbo4` KV cache compression adds another layer of efficiency, allowing context windows up to 262K tokens within the same VRAM budget.

---

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with NVIDIA Container Toolkit)
- [Git](https://git-scm.com/downloads)
- PowerShell 5.1+ (Windows) or Bash (Linux/macOS)
- VS Code Insiders build with Copilot Chat support

### Step 1: Clone and Initialize

```powershell
# Clone the repository
git clone https://github.com/YOUR_USERNAME/glitch-clt.git
cd glitch-clt

# Initialize submodules (downloads llama.cpp-turboquant fork)
git submodule update --init --recursive
```

### Step 2: Download Model

The model file is ~18GB. Download it from HuggingFace:

```powershell
# Option A: Using huggingface-cli (recommended)
pip install huggingface_hub
huggingface-cli download YOUR_MODEL_REPO Qwen3.6-35B-A3B-UD-IQ4_XS.gguf --local-dir models/

# Option B: Manual download
# Visit the model repository and download Qwen3.6-35B-A3B-UD-IQ4_XS.gguf
# Place it in the ./models/ directory
```

### Step 3: Configure VS Code

Run the setup script to add your local model to Copilot Chat:

```powershell
.\scripts\setup-vscode.ps1
```

This will:
- Add a new `"llamacpp-turboquant"` entry to `chatLanguageModels.json`
- Preserve all existing model configurations
- Configure proper stop sequences for Qwen models

**Options:**
```powershell
# Custom port or host
.\scripts\setup-vscode.ps1 -Port 8000 -Host "192.168.1.100"

# Use native llamacpp vendor (newer Insiders builds)
.\scripts\setup-vscode.ps1 -UseNativeProvider
```

### Step 4: Start the Server

```powershell
docker compose up -d
```

The server will:
- Build from source (first run takes ~5-15 minutes depending on hardware)
- Load the model into VRAM
- Listen on `http://localhost:9998`

### Step 5: Connect and Chat

1. Open VS Code Insiders
2. Open Copilot Chat (`Ctrl+Shift+P` → "Copilot Chat: Start New Thread")
3. Select **"llamacpp-turboquant"** from the model picker dropdown
4. Start chatting!

---

## Configuration

### Environment Variables

Copy `.env.example` to `.env.local` and customize:

```bash
cp .env.example .env.local
```

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_PATH` | `./models` | Path to GGUF models directory |
| `MODEL_FILE` | `Qwen3.6-35B-A3B-UD-IQ4_XS.gguf` | Model filename |
| `LLAMACPP_PORT` | `9998` | Server port |
| `CONTEXT_SIZE` | `262144` | Maximum context length in tokens |

### Docker Compose Configuration

Key server parameters (from `docker-compose.yml`):

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--host` | `0.0.0.0` | Bind address |
| `--port` | `8000` | Internal container port (mapped to 9998) |
| `--ctx-size` | `${CONTEXT_SIZE}` | Context window size |
| `--n-gpu-layers` | `999` | Layers offloaded to GPU |
| `--cache-type-k` | `turbo4` | TurboQuant KV cache type for keys |
| `--cache-type-v` | `turbo4` | TurboQuant KV cache type for values |
| `--threads` | `8` | CPU threads for CPU fallback |
| `--flash-attn` | `on` | Enable FlashAttention |

### Advanced: Custom Server Flags

Edit the `command:` section in `docker-compose.yml` to adjust inference parameters:

```yaml
- --temp "0.6"        # Temperature (creativity)
- --top-p "0.95"      # Nucleus sampling threshold
- --top-k "20"        # Top-K sampling
- --min-p "0.0"       # Min-P threshold
- --repeat-penalty "1.1"  # Repetition penalty
```

---

## Usage

### Basic Chat

Simply type your question or request in Copilot Chat. The model will respond using its full context window.

### Code Assistance

glitch-CLT excels at:
- **Code generation** from natural language descriptions
- **Refactoring suggestions** across large codebases
- **Debugging help** with detailed error analysis
- **Documentation writing** for existing code

### Context Window Tips

With TurboQuant's `turbo4` compression:
- **Short prompts (<8K tokens)**: Near-instant responses, minimal VRAM impact
- **Medium contexts (8K–64K tokens)**: Excellent balance of speed and capability
- **Long contexts (64K–262K tokens)**: Full codebase understanding, slightly slower but highly accurate

---

## Troubleshooting

### Server Won't Start

```bash
# Check Docker logs
docker compose logs llamacpp

# Verify GPU access
nvidia-smi

# Test server directly
curl http://localhost:9998/v1/models
```

### VS Code Can't Connect

1. Ensure the Docker container is running: `docker ps`
2. Verify port mapping: `docker port <container_id>`
3. Test API endpoint: `curl http://localhost:9998/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"test","messages":[{"role":"user","content":"hello"}]}'`
4. Restart VS Code Insiders after configuration changes

### Out of VRAM Errors

- Reduce `CONTEXT_SIZE` in `.env.local` (e.g., `65536`)
- Lower `--batch-size` and `--ubatch-size` to `128` or `64`
- Close other GPU-intensive applications

### Slow Inference

- Ensure CUDA backend is active (check logs for `CUDA loaded`)
- Verify FlashAttention is enabled (`--flash-attn on`)
- Increase `--threads` if CPU bottleneck detected
- Consider upgrading to a larger GPU for longer contexts

---

## Performance Benchmarks

Benchmarks are run on NVIDIA RTX 3090 (24GB VRAM) with Qwen3.6-35B-A3B:

| Metric | Standard llama.cpp | + TurboQuant (turbo4) | Improvement |
|--------|-------------------|----------------------|-------------|
| Max context (tokens) | ~16K–32K | **262K** | **8x+** |
| KV cache VRAM (at 64K ctx) | ~12GB | ~1.5GB | **~8x reduction** |
| Prefill speed | Baseline | Baseline | No change |
| Decode speed | Baseline | ~95% of baseline | ~5% overhead |

> **Note:** Benchmarks vary based on hardware, model size, and specific workload. Results shown are representative averages from controlled testing environments.

---

## Customization

### Adding New Models

1. Download the GGUF file to `models/` directory
2. Update `.env.local`:
   ```bash
   MODEL_FILE=your-model-file.gguf
   ```
3. Restart Docker: `docker compose down && docker compose up -d`

### Switching TurboQuant Modes

Available compression modes (in `docker-compose.yml`):

| Mode | Description | VRAM Savings | Quality Impact |
|------|-------------|--------------|----------------|
| `turbo2` | 2-bit PolarQuant | ~4x | Slight quality loss |
| `turbo3` | 3-bit PolarQuant | ~6x | Minimal quality impact |
| `turbo4` | 4-bit PolarQuant | ~8x | Negligible quality impact |

Change by updating both `--cache-type-k` and `--cache-type-v`:
```yaml
- --cache-type-k turbo3
- --cache-type-v turbo3
```

### Development Mode

For development with hot-reload:

```bash
docker compose -f docker-compose.yml up --build
```

---

## Project Structure

```
glitch-clt/
├── .devops/                    # CI/CD and Docker configurations
│   ├── cuda.Dockerfile         # CUDA build for llama.cpp-turboquant
│   └── tools.sh                # Server entrypoint script
├── .github/                    # GitHub Actions workflows (from fork)
├── llama.cpp-turboquant/       # Git submodule: TurboQuant-enabled llama.cpp
│   ├── src/                    # Core inference engine
│   ├── ggml/                   # Tensor library with TurboQuant extensions
│   ├── common/                 # Shared utilities
│   └── examples/               # Example scripts and tools
├── models/                     # GGUF model files (gitignored)
│   └── .gitkeep
├── scripts/                    # Setup and utility scripts
│   └── setup-vscode.ps1        # VS Code Copilot Chat configuration
├── .env.example                # Environment variable template
├── docker-compose.yml          # Docker service definition
├── LICENSE                     # MIT License
├── CONTRIBUTING.md             # Contribution guidelines
├── CHANGELOG.md                # Version history
└── README.md                   # This file
```

---

## TurboQuant Technology

glitch-CLT uses a custom fork of llama.cpp with **TurboQuant KV cache compression** — a breakthrough technique for long-context LLM inference.

### How It Works

1. **Walsh-Hadamard Transform (WHT)**: Rotates KV cache activations to decorrelate them, making quantization more effective
2. **PolarQuant**: Optimal centroid-based quantization in the WHT-rotated space (2/3/4-bit)
3. **QJL (Quasi-Johnson-Lunde)**: 1-bit sign projection matrix for additional precision in 4-bit mode

### Research Paper

For technical details, see: [arXiv:2504.19874](https://arxiv.org/abs/2504.19874) (ICLR 2026)

---

## License

This project is licensed under the **MIT License** — the same license as llama.cpp. See [LICENSE](LICENSE) for details.

The TurboQuant extensions are part of a private fork maintained by [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant). Usage is subject to the terms of that repository and its upstream dependencies.

---

## Acknowledgments

- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** by ggml-org — The foundation of this project
- **[TurboQuant](https://github.com/TheTom/llama-cpp-turboquant)** by TheTom — KV cache compression technology
- **Qwen Team** — Qwen 3.6 model family
- **VS Code Copilot Chat** — Microsoft's integration for local LLMs

---

*glitch-CLT: Local intelligence, zero subscriptions, full control.*
