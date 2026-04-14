# Containerized Agent Development: Safe Yolo Mode

**Research Date:** 2026-04-13
**Sources:** Sandcastle, Docker Sandboxes, Anthropic srt, Trail of Bits, Sandcat, Greywall, E2B, Daytona, Modal, Codex CLI, Devin, academic papers, OWASP

---

## The Problem

Making "yolo mode" safe: agents run destructive commands, install packages, modify system files without risk to developer's machine.

---

## 1. Sandcastle (Matt Pocock / AI Hero)

**Source:** github.com/mattpocock/sandcastle | NPM: `@ai-hero/sandcastle` (v0.4.0)

### How It Works
TypeScript library for orchestrating AI agents in isolated Docker containers. Core primitive: `sandcastle.run()`:
1. Creates git worktree on specified branch
2. Bind-mounts worktree into Docker container
3. Runs agent (Claude Code, Codex, OpenCode) with `--dangerously-skip-permissions`
4. Commits inside container appear on host via bind mount

### Branch Strategies
- **Head**: Agent writes directly to host working directory
- **Merge-to-head**: Temp branch in worktree, auto-merged back
- **Branch**: Commits land on explicit named branch

### Orchestration Pattern (from course-video-manager)
- Phase 1 (Plan): Opus agent analyzes GitHub issues, picks parallelizable work
- Phase 2 (Execute): Multiple Sonnet agents in parallel, each in own sandbox/branch, with review
- Phase 3 (Merge): Single agent merges all branches

### Details
- Setup: `npm install @ai-hero/sandcastle` + `npx sandcastle init`
- Performance: Container startup per sandbox; bind-mount = no file copy overhead
- Network: Full access inside container
- Templates: blank, simple-loop, sequential-reviewer, parallel-planner
- Limitations: Docker-only (no microVM). Bind-mount means agent CAN affect host through worktree. 100% local

---

## 2. Docker Sandboxes (Docker Desktop 4.50+, March 2026)

**Source:** docs.docker.com/ai/sandboxes/

### How It Works
Each agent runs in a **microVM** (not regular container). Each sandbox gets:
- Dedicated Linux kernel (hardware-level isolation)
- Private Docker daemon (safe Docker-in-Docker)
- Isolated filesystem and network
- No sandbox-to-sandbox or sandbox-to-host communication

**Credential proxy**: API keys never enter VM. Proxy on host injects auth headers. Session token stays host-side.

### Details
- Setup: `sbx run claude --name my-sandbox .` — single command
- Performance: Sub-200ms microVM startup (microsandbox technology). Can stop/restart without recreating
- File system: Only project workspace mounted in
- Network: Outbound through HTTP/HTTPS proxy on host
- State: VM can stop and restart, preserving installed packages and Docker images
- Cost: Included with Docker Desktop subscription
- Supports: Claude Code, Gemini CLI, Codex, Copilot, Kiro, OpenCode, Docker Agent
- **Strongest local isolation** — separate kernel means container escape doesn't compromise host
- Limitations: Requires Docker Desktop (not available on Linux without it). Windows/macOS only

---

## 3. Anthropic Sandbox Runtime (srt)

**Source:** github.com/anthropic-experimental/sandbox-runtime (3,743 stars)

### How It Works
**No container required.** Uses native OS primitives:
- macOS: `sandbox-exec` with Seatbelt profiles
- Linux: `bubblewrap` for filesystem/namespace + network namespace isolation

Network isolation: proxy-based filtering (HTTP + SOCKS5 on localhost).

### Dual Isolation Model
- **Filesystem**: Deny-then-allow reads, allow-only writes. Sensitive paths always blocked (.ssh, .gnupg, .env)
- **Network**: All access denied by default. Must explicitly allow domains

### Details
- Setup: `npm install -g @anthropic-ai/sandbox-runtime` then `srt <command>`
- Performance: Near-zero overhead — no VM or container
- **Reduces permission prompts by 84%** in Claude Code internal usage
- Cost: Free, open source
- Limitations: Research preview. macOS Seatbelt undocumented. No Windows (WSL2 only)

---

## 4. Trail of Bits DevContainer

**Source:** github.com/trailofbits/claude-code-devcontainer (696 stars)

VS Code/Cursor devcontainer for running Claude Code with `bypassPermissions` safely. Built at Trail of Bits for security audits.

- Ubuntu 24.04, Node.js 22, Python 3.13, zsh
- Named Docker volumes for persistence (history, Claude config, gh auth)
- Host ~/.gitconfig mounted read-only
- Optional iptables network isolation
- Setup: `devc .` in any repo
- CLI: `devc up/rebuild/destroy/shell/exec/mount/sync`
- `devc sync` copies session logs to host for /insights

---

## 5. Sandcat (VirtusLab)

**Source:** github.com/VirtusLab/sandcat (128 stars)

Docker + **transparent mitmproxy via WireGuard**. All container traffic routed through proxy without per-tool config.

**Key innovation: Secret substitution at proxy level.** Container never sees real API keys — proxy injects them into matching requests.

- Setup: `sandcat init --agent claude --ide vscode --stacks "python,node"` then `sandcat run`
- Stacks: node, python, java, rust, go, scala, ruby, dotnet, zig
- Deny-by-default with allow/deny lists
- First-match-wins rule evaluation

---

## 6. Greywall (GreyhavenHQ)

**Source:** github.com/GreyhavenHQ/greywall (149 stars)

**Container-free, deny-by-default sandbox** using kernel enforcement:
- Linux: Bubblewrap + Landlock LSM + Seccomp BPF + eBPF monitoring + TUN network capture
- macOS: sandbox-exec with filesystem access control

All traffic through greyproxy (deny-by-default transparent proxy with live dashboard).

- Setup: `brew install greywall` then `greywall -- claude`
- Performance: Near-zero overhead
- **Learning mode**: `greywall --learning` traces access, auto-generates least-privilege profiles
- Command blocking: rm -rf /, git push --force denied
- Agent profiles for: Claude Code, Codex, Cursor, Aider, Goose, Gemini, OpenCode, Amp, Cline, Copilot
- Limitations: No Windows. macOS has limited transparent proxy

---

## 7. E2B

**Source:** github.com/e2b-dev/e2b (11,686 stars)

Cloud-hosted sandboxes using **Firecracker microVMs** with Kubernetes.

- Performance: ~150ms cold start. Scales to thousands concurrent
- File system: Ephemeral by default. Upload/download API
- Cost: ~$0.10/hour per sandbox. Free tier available
- Self-hosting: Terraform on AWS or GCP
- Used by ~half of Fortune 500
- Limitations: Cloud-only (latency). Not for long interactive sessions

---

## 8. Daytona

**Source:** github.com/daytonaio/daytona (72,313 stars)

Secure infrastructure runtime using Docker with complete isolation.

- Performance: **27-90ms** from request to execution — industry-leading
- Snapshots enable persistent operations across sessions
- SDKs: Python, TypeScript, Ruby, Go, Java
- MCP server support, LSP, PTY, webhooks, Git operations
- Unique: web terminal, VNC, SSH gateway
- Self-hosting available via Docker Compose

---

## 9. Modal

**Source:** modal.com

Serverless platform using **gVisor** (user-space kernel intercepting syscalls).

- Sub-second cold starts. Scales to 20,000+ concurrent containers
- Autoscales from zero
- Pay-per-second billing. **GPU access** (A100, H100) — unique advantage
- Free tier: $30/month credits
- Limitations: No persistent state by default. Python SDK only

---

## 10. OpenAI Codex CLI (Built-in Sandbox)

**Source:** github.com/openai/codex (74,952 stars)

Built-in sandboxing using platform-native primitives:
- macOS: Apple Seatbelt
- Linux: Bubblewrap + Landlock LSM
- Windows: Dedicated sandbox users + filesystem permissions + firewall rules

Docker mode: runs in container with iptables firewall. Only api.openai.com allowed by default.

---

## 11. Devin

Proprietary. Each session in self-contained cloud sandbox with shell, editor, browser. $500/month. No self-hosting.

---

## 12. Other Notable Solutions

- **Spritz** (TextCortex): Kubernetes-native control plane for agent instances. Alpha.
- **Claudetainer**: Auto-configured devcontainer. Now obsoleted by Claude Code Remote Control.
- **Ductor**: Control agents via Telegram/Matrix. Optional Docker sidecar.
- **Gluon Agent**: Parallel Claude Code tasks in Docker with bubblewrap inside. Kanban dashboard.
- **aibox**: Multi-CLI Docker container with multi-account support.

---

## Comparative Summary

| Solution | Isolation | Startup | Self-hosted | Cost | Claude Support | Setup |
|----------|----------|---------|-------------|------|---------------|-------|
| Sandcastle | Docker (bind-mount) | Seconds | Local | Free | First-class | Easy |
| Docker Sandboxes | microVM | <200ms | Local | Docker sub | First-class | Very Easy |
| Anthropic srt | OS primitives | Near-zero | Local | Free | Built-in | Easy |
| Trail of Bits devc | Docker | Seconds | Local | Free | First-class | Easy |
| Sandcat | Docker+mitmproxy+WG | Seconds | Local | Free | Yes | Medium |
| Greywall | Kernel-level | Near-zero | Local | Free | Profiles | Easy |
| E2B | Firecracker microVM | ~150ms | Self-host | ~$0.10/hr | Via SDK | Easy |
| Daytona | Docker | 27-90ms | Self-host | Managed/Free | Via SDK | Medium |
| Modal | gVisor | Sub-second | No | Pay/sec | Via SDK | Easy |
| Codex CLI | OS primitives | Near-zero | Local | Free | N/A | Built-in |

---

## Best Practices (OWASP + NVIDIA + Industry)

1. **Defense in depth**: Combine filesystem + network + process isolation
2. **Deny-by-default**: Network, filesystem, secrets require explicit allowlisting
3. **Credential injection, not exposure**: Proxy-based injection so agents never see raw keys
4. **Prompt injection defense**: Malicious instructions in code comments/READMEs. Sandbox limits blast radius
5. **Git isolation**: Use worktrees/branches, never touch main. Auto-create PRs
6. **Command denylists**: Block rm -rf /, git push --force, npm publish
7. **Resource limits**: CPU/memory caps prevent runaway agents
8. **Audit trails**: Log all actions, tool calls, file modifications
9. **Ephemeral environments**: Disposable sandboxes that reset between sessions
10. **VM over container**: For max security, microVM (Docker Sandboxes, E2B) over containers (shared kernel)

**Critical 2026 context**: McKinsey red-team showed AI agent gaining full enterprise access in 120 minutes. VM-in-container (VM as security, container as convenience) is emerging gold standard.

## Recommendations By Use Case

**Solo dev, local yolo:**
- Best: Docker Sandboxes (`sbx run claude`) — strongest local isolation
- Runner-up: Anthropic srt + Greywall — zero overhead, no Docker

**Multiple parallel agents:**
- Best: Sandcastle — purpose-built, TypeScript API, worktree management
- Runner-up: Gluon Agent or Spritz

**Security audits:**
- Best: Trail of Bits devcontainer
- Runner-up: Sandcat (mitmproxy gives full traffic visibility)

**Cloud/production:**
- Best: Daytona (fastest) or E2B (microVM)
- Runner-up: Modal (GPU access)

**Minimal change to existing workflow:**
- Best: Anthropic srt (84% fewer permission prompts)
- Runner-up: Docker Sandboxes (single command)

## Sources

- docs.docker.com/ai/sandboxes/
- github.com: sandcastle, sandbox-runtime, claude-code-devcontainer, sandcat, greywall, e2b, daytona, codex, claudetainer, spritz, ductor, gluon-agent, aibox
- anthropic.com/engineering/claude-code-sandboxing
- modal.com/blog/sandbox-launch
- OWASP AI Agent Security Cheat Sheet
- NVIDIA: Practical Security Guidance for Sandboxing
- firecrawl.dev/blog/ai-agent-sandbox
- northflank.com/blog/how-to-sandbox-ai-agents
- betterstack.com (sandbox benchmark 2026)
