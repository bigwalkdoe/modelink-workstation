# Modelink Workstation

**AI-Native Engineering Platform — Codename: Atlas**

> From Power On to Productive in Under 10 Minutes.

Modelink Workstation is a purpose-built Ubuntu LTS-based Linux distribution for AI engineers, SaaS architects, DevOps engineers, cybersecurity professionals, and technical founders.

## Editions

| Edition | Focus | Key Packages |
|---------|-------|-------------|
| **Core** | Lightweight engineering base | KDE Plasma, dev tools, networking, security defaults |
| **Developer** | Full-stack development | Languages, containers, k8s, databases, API tools |
| **AI** | Local LLM & AI agents | Ollama, CUDA, ROCm, LangChain, Jupyter, MCP servers |
| **Security** | Defensive security | Nmap, Wireshark, Metasploit, forensics, crypto |
| **Enterprise** | Organizational deployment | Ansible, Prometheus, Grafana, K3s, Keycloak |

## Quick Start

### Prerequisites

- Ubuntu 24.04 build host (or Docker)
- 40GB+ free disk space
- 8GB+ RAM

### Build with Make

```bash
# Build Developer edition (default)
make -f build/Makefile developer

# Build AI edition
make -f build/Makefile ai EDITION=ai

# Build all editions
make -f build/Makefile build-all
```

### Build with Docker

```bash
make -f build/Makefile docker-build EDITION=developer
```

### Build Artifacts

ISOs are output to `/tmp/modelink-iso/` by default:

```
/tmp/modelink-iso/
├── modelink-developer-24.04-20250101.iso
├── modelink-developer-24.04-20250101.iso.sha256
```

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 8+ cores |
| RAM | 4 GB | 16+ GB |
| Storage | 40 GB | 256+ GB SSD |
| GPU | — | NVIDIA/AMD (for AI edition) |

## Architecture

```
Modelink Workstation
├── Core OS          — Ubuntu LTS, KDE Plasma, system hardening
├── AI Platform      — Ollama, agents, MCP, GPU acceleration
├── Engineering      — Languages, containers, k8s, databases
├── Infrastructure   — Ansible, Terraform, monitoring
├── Security         — Firewall, IDS, forensics, cryptography
├── Automation       — CI/CD pipelines, project templates
├── Workspace        — Opinionated directory structure
└── Recovery         — Snapshots, backup, restore
```

## Workspace Structure

```
~/Workspace/
├── Projects/        — Active development projects
├── Clients/         — Client-specific work
├── Research/        — Experiments and research
├── Agents/          — AI agent projects
├── AI/              — Models, datasets, inference
├── Containers/      — Docker/Podman configurations
├── Infrastructure/  — Terraform, Ansible, Kubernetes
├── Automation/      — Scripts and CI/CD pipelines
├── Templates/       — Project and agent templates
└── Backups/         — Backup archives
```

## First Boot

The Welcome Center guides you through:

1. System update
2. Git configuration
3. SSH key generation
4. GitHub authentication
5. AI runtime initialization
6. GPU driver installation
7. Workspace creation
8. Backup configuration

## Development Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Foundation — Ubuntu base, branding, KDE, core packages | In Progress |
| 2 | Engineering Platform — Languages, containers, databases | Planned |
| 3 | AI Platform — LLMs, agents, MCP, GPU | Planned |
| 4 | Infrastructure — Kubernetes, monitoring, automation | Planned |
| 5 | User Experience — Welcome Center, documentation | Planned |
| 6 | Release Engineering — CI/CD, ISO pipeline, validation | Planned |

## License

MIT
