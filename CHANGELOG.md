# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Initial release of glitch-CLT as a standalone deployment package
- TurboQuant KV cache compression support (turbo4 mode) via llama.cpp-turboquant submodule
- PowerShell setup script for VS Code Insiders Copilot Chat configuration
- Docker Compose configuration with CUDA backend and multi-stage builds
- Comprehensive documentation including README, CONTRIBUTING, SECURITY policies
- Hardware requirements guide and troubleshooting section
- Benchmark reference data for RTX 3090 hardware

### Changed
- Restructured from monolithic `turboquant_temp/` to clean project layout
- Converted llama.cpp fork to git submodule for cleaner version management
- Separated environment variables into `.env.example` template

### Security
- Added SECURITY.md with vulnerability reporting process
- Model files excluded from repository via `.gitignore`
- No hardcoded credentials or API keys in configuration

---

## Version History

### v1.0.0 — Initial Release (2026-04-19)

**Base Components:**
- llama.cpp-turboquant: commit `627ebbc` (feature/turboquant-kv-cache branch)
- Docker Compose: CUDA 12.8 + Ubuntu 24.04 multi-stage build
- Qwen3.6-35B-A3B model support with IQ4_XS quantization
- TurboQuant turbo4 KV cache compression mode

**Features:**
- One-command Docker deployment (`docker compose up`)
- VS Code Insiders integration via setup script
- Up to 262K token context window with turbo4 compression
- OpenAI-compatible API endpoint at `/v1/chat/completions`

**Documentation:**
- Comprehensive README with architecture diagrams and quick-start guide
- Hardware requirements and benchmark data
- Troubleshooting section covering common issues
- Contribution guidelines for community development

---

## Submodule Versions

The llama.cpp-turboquant submodule tracks the following upstream fork:

| Component | Source | Branch/Tag |
|-----------|--------|------------|
| Core engine | TheTom/llama-cpp-turboquant | `feature/turboquant-kv-cache` |
| TurboQuant KV cache | Same fork | Integrated in ggml layer |
| CUDA backend | Same fork | CUDA 12.8 support |
| Metal backend | Same fork | macOS GPU acceleration |
| Vulkan backend | Same fork | Cross-platform GPU support |

To check for updates:
```bash
cd llama.cpp-turboquant
git fetch origin
git log HEAD..origin/feature/turboquant-kv-cache
```

---

## Migration Notes

### From Previous Setup (turboquant_temp/)

If you were using the previous `turboquant_temp/` structure:

1. **Model file**: Move from `models/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf` to this repo's `models/` directory
2. **Docker Compose**: The existing `docker-compose.yml` is compatible — no changes needed
3. **VS Code config**: Run `.\scripts\setup-vscode.ps1` to add/update your configuration
4. **Environment variables**: Copy `.env.example` to `.env.local` and adjust as needed

The Docker container port mapping remains unchanged (`9998:8000`).
