# Contributing to glitch-CLT

Thank you for your interest in contributing! This document covers how to contribute effectively to this project.

## Table of Contents

- [What We're Building](#what-were-building)
- [How to Contribute](#how-to-contribute)
- [Reporting Issues](#reporting-issues)
- [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Documentation](#documentation)

---

## What We're Building

glitch-CLT is a production-ready deployment package that enables VS Code Copilot Chat to use self-hosted Qwen models with TurboQuant KV cache compression. Our focus areas:

1. **Reliability** — Stable, well-tested Docker deployments
2. **Performance** — Optimized inference configurations for various hardware
3. **Usability** — One-command setup and clear documentation
4. **Transparency** — Clear understanding of what's customized vs upstream

### Scope

This repository contains:
- Deployment configuration (Docker, environment variables)
- Setup scripts for VS Code integration
- Documentation and benchmarks
- The llama.cpp-turboquant submodule (see below)

**Not in scope:**
- Core llama.cpp development (handled upstream)
- TurboQuant algorithm research (handled by the fork maintainers)
- Model training or quantization pipelines

---

## How to Contribute

### We Welcome Contributions For:

- Bug reports and fixes
- Documentation improvements
- Docker configuration optimizations
- Benchmark additions
- Setup script enhancements
- Hardware compatibility testing

### We Prefer:

- **Focused changes** — One feature or fix per PR
- **Clear descriptions** — Explain what, why, and how
- **Testing** — Verify your changes work on real hardware
- **Respect for scope** — Keep deployment-focused; don't drift into core engine changes

---

## Reporting Issues

Before opening an issue, please check:

1. **Existing issues** — Search for similar problems
2. **Troubleshooting section** in README.md
3. **Docker logs** — Include `docker compose logs` output

When reporting bugs, include:

```markdown
### Environment
- OS: [e.g., Windows 11, Ubuntu 24.04]
- GPU: [e.g., RTX 3090, CUDA 12.8]
- Docker version: [output of `docker --version`]
- Model: [model filename and quantization]

### Steps to Reproduce
1. ...
2. ...
3. ...

### Expected Behavior
...

### Actual Behavior
...

### Logs/Errors
[Include relevant log output]
```

---

## Pull Requests

### Before Submitting

1. **Create an issue first** for significant changes (unless it's a trivial fix)
2. **Test your changes** on actual hardware if possible
3. **Update documentation** if you change behavior
4. **Follow existing conventions** in the codebase

### PR Checklist

- [ ] Changes are focused and well-scoped
- [ ] Documentation is updated where needed
- [ ] No unrelated files are modified
- [ ] Commit messages follow conventional format: `type(scope): description`

### Commit Message Format

```
type(scope): short description

body (optional, if more context needed)
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

**Examples:**
```
feat(docker): add health check for llama.cpp server
fix(config): correct default context size in .env.example
docs(readme): update hardware requirements section
perf(compose): reduce Docker build time with multi-stage caching
```

---

## Development Setup

### Prerequisites

- Git with submodule support
- Docker Desktop with NVIDIA Container Toolkit
- PowerShell 5.1+ or Bash

### Setting Up a Development Environment

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/glitch-clt.git
cd glitch-clt

# Initialize submodules
git submodule update --init --recursive

# Build and start (first run compiles llama.cpp-turboquant)
docker compose up --build
```

### Testing Changes

1. Modify configuration files in `docker-compose.yml` or `.env.example`
2. Rebuild: `docker compose down && docker compose up --build`
3. Verify with: `curl http://localhost:9998/v1/models`
4. Test VS Code integration by running `.\scripts\setup-vscode.ps1 -UseNativeProvider`

---

## Code Style

### Docker / Compose

- Use multi-stage builds for smaller images
- Comment complex configurations
- Follow [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

### PowerShell Scripts

- Use `[CmdletBinding()]` and proper parameter validation
- Include comment-based help (`<# .SYNOPSIS ... #>`)
- Use `Write-Host` with color codes for user feedback
- Follow [PowerShell Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/style-scripting/)

### Documentation

- Write in clear, concise English
- Use code blocks for commands and configuration
- Include examples for common use cases
- Keep sections focused on a single topic

---

## Documentation

Good documentation is critical. When contributing:

1. **Update README.md** if you change setup steps or add features
2. **Add to troubleshooting** if users might encounter your issue
3. **Include benchmarks** if performance characteristics change
4. **Keep it current** — outdated docs are worse than no docs

---

## Acknowledgments

All contributors are welcome regardless of experience level. We appreciate every bug report, documentation fix, and improvement suggestion.

This project follows the [llama.cpp](https://github.com/ggml-org/llama.cpp) philosophy of practical, production-focused development over theoretical perfection.
