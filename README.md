<p align="center">
  <img src="https://img.shields.io/badge/A.L.I.C.E-Alice%20Framework%20Agi-00ffcc?style=for-the-badge&labelColor=07060f" alt="ALICE" />
  <img src="https://img.shields.io/badge/V0-Active-5fd38d?style=for-the-badge&labelColor=07060f" alt="V0" />
  <img src="https://img.shields.io/badge/Scope-LOCAL-8f6cf0?style=for-the-badge&labelColor=07060f" alt="Local" />
</p>

<p align="center"><b>Autonomous Local Intelligence & Cybernetic Entity</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.12-3776ab?style=flat-square&logo=python&logoColor=white&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Ollama-Local%20LLM-ffffff?style=flat-square&logo=ollama&logoColor=white&labelColor=07060f" />
  <img src="https://img.shields.io/badge/React-TSX-61dafb?style=flat-square&logo=react&logoColor=white&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white&labelColor=07060f" />
  <img src="https://img.shields.io/badge/MCP-Server-8f6cf0?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/x402-USDC-00ffcc?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/License-MIT-c0caf5?style=flat-square&labelColor=07060f" />
</p>

---

## What is A.L.I.C.E?

An AI agent framework that runs **100% local** — zero cloud dependency.
Autonomous operations, monitoring, chain sync, self-healing. Designed to operate on a single machine with full sovereignty over its data and decisions.

Includes **Ollama** for local LLM inference — no Anthropic/OpenAI API key needed. ALICE talks to her own brain.

## Metrics

<p align="center">
  <img src="https://img.shields.io/badge/Dashboard-106%20panels-8f6cf0?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/AI%20modules-36-00ffcc?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/x402%20routes-12-f2c14e?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Tools-156-5fd38d?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/LoC-132K-c0caf5?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Containers-7-2496ED?style=flat-square&labelColor=07060f" />
</p>

## Quick Start

```bash
docker compose -f docker/docker-compose.public-node.yml up -d
```

This starts **3 services** automatically:

| Service | Port | Description |
|---|---|---|
| **Ollama** | `127.0.0.1:11434` | Local LLM (auto-pulls `mistral` on first run) |
| **THESEED Anvil** | `127.0.0.1:8545` | L0 blockchain (chain 31337) |
| **ALICE Node** | `127.0.0.1:7781` | Autonomous agent with LLM + chain sync |

Ollama pulls the model automatically on first boot — no manual setup needed.

## Architecture

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐
│  ALICE Node │────▶│  Ollama  │     │ THESEED L0   │
│  :7781      │     │  :11434  │     │  :8545       │
│  Agent API  │────▶│  mistral │     │  chain 31337 │
└─────────────┘     └──────────┘     └──────────────┘
       │                                    │
       └────────────────────────────────────┘
                  chain sync
```

## API

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check |
| `/status` | GET | Full node status (agent + chain + LLM) |
| `/api/chain` | GET | Chain info (block, sync) |
| `/api/query` | POST | Query the agent (LLM-powered) |
| `/api/task` | POST | Send task |
| `/api/node` | GET | Node identity |
| `/api/logs` | GET | Activity logs |
| `/api/llm` | GET | LLM status (model, availability) |

### Query Examples

```bash
# LLM-powered query
curl -X POST http://127.0.0.1:7781/api/query \
  -H "Content-Type: application/json" \
  -d '{"input": "What is the current chain state?"}'

# Chain info
curl http://127.0.0.1:7781/api/chain

# LLM status
curl http://127.0.0.1:7781/api/llm
```

## Environment

| Variable | Default | Description |
|---|---|---|
| `ALICE_PORT` | `7781` | HTTP server port |
| `ALICE_ROLE` | `GENERAL` | Agent role |
| `RPC_URL` | `http://127.0.0.1:8545` | Blockchain RPC endpoint |
| `CHAIN_ID` | `31337` | L0 Chain ID |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Ollama API endpoint |
| `OLLAMA_MODEL` | `mistral` | Default LLM model |

## GPU Support

To enable GPU acceleration for Ollama, add to `docker-compose.public-node.yml`:

```yaml
# NVIDIA
ollama:
  deploy:
    resources:
      reservations:
        devices:
          - capabilities: [gpu]

# AMD (ROCm)
ollama:
  image: ollama/ollama:0.3.12-rocm
  devices:
    - /dev/kfd
    - /dev/dri
```

## Related

<p align="center">
  <a href="https://github.com/VZero911/MCP"><img src="https://img.shields.io/badge/MCP-Server-8f6cf0?style=for-the-badge&logo=github&labelColor=07060f" alt="MCP" /></a>
  <a href="https://github.com/VZero911/AGENTS"><img src="https://img.shields.io/badge/AGENTS-Public%20Nodes-5fd38d?style=for-the-badge&logo=github&labelColor=07060f" alt="AGENTS" /></a>
  <a href="https://github.com/VZero911/THESEED"><img src="https://img.shields.io/badge/THESEED-Web3%20Game-f2c14e?style=for-the-badge&logo=github&labelColor=07060f" alt="THESEED" /></a>
  <a href="https://github.com/VZero911/THEROOT"><img src="https://img.shields.io/badge/THEROOT-Infrastructure-ea4335?style=for-the-badge&logo=github&labelColor=07060f" alt="THEROOT" /></a>
</p>

---

<p align="center"><i>Design By V0</i></p>
