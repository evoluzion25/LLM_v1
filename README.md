# LLM_v1

A minimal, scalable Legal AI system: Claude Desktop + MCP servers locally, with GPU-backed inference in the cloud via RunPod (vLLM) or managed model endpoints (e.g., DigitalOcean). No LM Studio required.

## Purpose
Enable uninterrupted processing of massive legal documents and long-form drafting (RICO, fraud, civil rights) by pairing Claude’s reasoning with a GPU-backed model runtime that removes practical context limits.

## Core Use Case
- Ingest 100+ page filings, exhibits, discovery
- Summarize, extract, and structure content without hitting context limits
- Maintain continuity across sessions for drafting long federal complaints

## Tech Stack (lean)
- Local: Claude Desktop + MCP servers
  - Filesystem MCP (case docs), Memory MCP (working notes), PDF tools MCP, SQLite MCP, Sequential Thinking MCP
- Cloud options:
  - RunPod vLLM (OpenAI-compatible API; best performance/control)
  - OR DigitalOcean Model Endpoints (managed, token-billed)
- Optional UI: Open WebUI (browser UI for testing/sanity checks)

## Architecture
- Claude orchestrates and calls an OpenAI-compatible endpoint via an “OpenAI MCP” bridge
- Files stay local via Filesystem MCP; bulk docs can be uploaded to pods as needed
- Open WebUI (optional) provides a simple browser UI for inspection and model mgmt

## Repos & Scripts
- `docs/ARCHITECTURE.md` — details, contracts, ports, security
- `docs/STORAGE.md` — storage layers and how to persist data across pods
- `docs/SSH.md` — SSH key setup and connecting to pods
- `scripts/runpod-create-pod.ps1` — create a RunPod GPU pod for vLLM or Open WebUI
- `scripts/setup-ssh-env.ps1` — generate key and export RUNPOD_SSH_PUBKEY
- `scripts/workflows/create-runpod-pod.yml` — Actions workflow template (move to `.github/workflows/` to enable)

## GitHub Actions (optional)
- Add repository secret `RUNPOD_API_KEY` (you already added org/user-level secrets).
- Move `scripts/workflows/create-runpod-pod.yml` to `.github/workflows/create-runpod-pod.yml`.
- Trigger from the Actions tab and fill inputs (GPU, volume, SSH enable, etc.).

## Safe secrets usage
- Recognized secrets: `RUNPOD_API_KEY`, `RUNPOD_SSH_PUBKEY` (optional for SSH), `S3_API_KEY` (for future backups).
- Never commit keys. Local scripts read `RUNPOD_API_KEY` and `RUNPOD_SSH_PUBKEY` from your environment.

## Local provisioning (PowerShell)
```powershell
# vLLM API server (OpenAI-compatible)
pwsh -File .\scripts\runpod-create-pod.ps1 -Preset vllm-openai -Name 'legal-vllm' -GpuQuery 'H100' -GpuCount 1 `
  -VolumeInGb 100 -ContainerDiskInGb 50 -VllmModel 'mistralai/Mistral-7B-Instruct-v0.3' -VllmMaxContext 32768

# Enable SSH and attach Network Volume
pwsh -File .\scripts\runpod-create-pod.ps1 -Preset vllm-openai -Name 'legal-vllm' -GpuQuery 'H100' -GpuCount 1 `
  -NetworkVolumeId 'agv6w2qcg7' -VolumeMountPath '/workspace' -EnableSsh
```

After creation, open the Pod in RunPod → Connect to access the browser UI/API (ports 8000 for vLLM, 3000 for Open WebUI).
