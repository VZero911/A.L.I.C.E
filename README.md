<p align="center">
  <img src="https://img.shields.io/badge/A.L.I.C.E-Alice%20Framework%20Agi-00ffcc?style=for-the-badge&labelColor=07060f" alt="ALICE" />
  <img src="https://img.shields.io/badge/V0-Active-5fd38d?style=for-the-badge&labelColor=07060f" alt="V0" />
  <img src="https://img.shields.io/badge/Scope-LOCAL-8f6cf0?style=for-the-badge&labelColor=07060f" alt="Local" />
</p>

<p align="center"><b>Autonomous Local Intelligence & Cybernetic Entity</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.12-3776ab?style=flat-square&logo=python&logoColor=white&labelColor=07060f" />
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

## Metrics

<p align="center">
  <img src="https://img.shields.io/badge/Dashboard-106%20panels-8f6cf0?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/AI%20modules-36-00ffcc?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/x402%20routes-12-f2c14e?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Tools-156-5fd38d?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/LoC-132K-c0caf5?style=flat-square&labelColor=07060f" />
  <img src="https://img.shields.io/badge/Containers-6-2496ED?style=flat-square&labelColor=07060f" />
</p>

## Public Node

The `docker/` directory contains a **zero-dependency** autonomous agent:

```bash
docker compose -f docker/docker-compose.public-node.yml up -d
```

- **Zero `pip install`** — pure Python stdlib only
- **Auto-starts** on boot, self-healing loop
- **Chain sync** to THESEED L0 (chain 31337)
- **/health** + **/status** endpoints always on

## API

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check |
| `/status` | GET | Full node status |
| `/api/chain` | GET | Chain info (block, sync) |
| `/api/query` | POST | Query the agent |
| `/api/task` | POST | Send task |
| `/api/node` | GET | Node identity |
| `/api/logs` | GET | Activity logs |

## Environment

| Variable | Default | Description |
|---|---|---|
| `ALICE_PORT` | `7781` | HTTP server port |
| `ALICE_ROLE` | `GENERAL` | Agent role |
| `RPC_URL` | `http://127.0.0.1:8545` | Blockchain RPC endpoint |
| `CHAIN_ID` | `31337` | L0 Chain ID |

## Related

<p align="center">
  <a href="https://github.com/VZero911/MCP"><img src="https://img.shields.io/badge/MCP-Server-8f6cf0?style=for-the-badge&logo=github&labelColor=07060f" alt="MCP" /></a>
  <a href="https://github.com/VZero911/AGENTS"><img src="https://img.shields.io/badge/AGENTS-Public%20Nodes-5fd38d?style=for-the-badge&logo=github&labelColor=07060f" alt="AGENTS" /></a>
  <a href="https://github.com/VZero911/THESEED"><img src="https://img.shields.io/badge/THESEED-Web3%20Game-f2c14e?style=for-the-badge&logo=github&labelColor=07060f" alt="THESEED" /></a>
  <a href="https://github.com/VZero911/THEROOT"><img src="https://img.shields.io/badge/THEROOT-Infrastructure-ea4335?style=for-the-badge&logo=github&labelColor=07060f" alt="THEROOT" /></a>
</p>

---

<p align="center"><i>Design By V0</i></p>
