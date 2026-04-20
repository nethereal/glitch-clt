# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in glitch-CLT, please follow responsible disclosure practices.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, use one of these methods:

1. **GitHub Security Advisories**: Navigate to the "Security" tab and click "Report a vulnerability"
2. **Direct contact**: Email [your-email] with "[SECURITY]" in the subject line

### What to Include

When reporting a vulnerability, please include:

- A clear description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment (if known)
- Your contact information for follow-up questions

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 7 days
- **Fix target**: Within 30 days for critical vulnerabilities
- **Disclosure**: Coordinated public disclosure after fix is released

## Security Best Practices

### For Users

1. **Network isolation**: Run the Docker container on a private network when possible
2. **Firewall rules**: Restrict access to port 9998 to trusted IPs only
3. **Model files**: Never commit GGUF model files to version control
4. **Environment variables**: Use `.env.local` (gitignored) for any sensitive configuration
5. **Docker security**: Keep Docker and NVIDIA Container Toolkit updated

### For Contributors

1. **No secrets in code**: Never hardcode API keys, passwords, or tokens
2. **Dependency updates**: Review dependency updates for known vulnerabilities
3. **Submodule updates**: When updating llama.cpp-turboquant submodule, review changes for security implications
4. **CI/CD security**: Do not expose secrets in GitHub Actions workflows

## Known Security Considerations

### Local Inference Server

The llama.cpp server exposes an HTTP API that accepts model inference requests. By default:

- It binds to `0.0.0.0` (all interfaces) — consider restricting to `127.0.0.1` in production
- No authentication is required by default — add reverse proxy auth if exposing externally
- The server runs with the privileges of the Docker container user

### Model Files

GGUF model files are binary artifacts that could theoretically contain malicious payloads. While the risk is low for models from trusted sources (HuggingFace, official releases), always:

- Verify model file checksums when available
- Use models from trusted repositories
- Run containers with minimal privileges (`--security-opt=no-new-privileges`)

## Dependencies

This project depends on:

- **llama.cpp-turboquant** (git submodule) — Security updates tracked via submodule commits
- **Docker base images** (Ubuntu 24.04, NVIDIA CUDA) — Update regularly via `docker compose pull`
- **Python packages** (requirements.txt) — Pin versions and audit periodically

To check for outdated dependencies:
```bash
# Check Docker image vulnerabilities
docker scan llamacpp-turboquant

# Review Python package security advisories
pip-audit -r requirements.txt
```

---

*Thank you for helping keep glitch-CLT secure.*
