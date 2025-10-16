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
- `scripts/runpod-create-pod.ps1` — create a RunPod GPU pod for vLLM or Open WebUI
- `scripts/runpod.env.example` — env template for provisioning

## Next
- Add chunking/summarization pipeline patterns
- Add optional Cloudflare Tunnel helper for stable private URLs
- Add an OpenAI MCP package install snippet for Claude config
