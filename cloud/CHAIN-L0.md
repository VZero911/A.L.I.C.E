# Chain: toward L0 (zero-deps, full-secu) + max on-chain persistence

Target set by V (2026-10-15): move the dev chain off Anvil-as-is toward an **L0** that is
**zero-dependency** and **fully secured**, and **persist as much of the blockchain DB as possible**
(there is a ~1 TB drive on the master PC — room to spare).

This is the plan + the concrete config. The chain itself lives in `the_seed.v0`
(`infra/docker-compose.yml`, `infra/anvil-state.sh`, `.env`); the steps below are applied there, on
the master PC. Nothing here moves real value (NORME #4) and none of it is a dangerous action without
the 3/5 gate (`cloud/SECURITY.md`).

## 1. Persist a maximum of the chain DB (do first — quick win)

Anvil already supports durable state; today it writes `.dev-stack/anvil/anvil.json` at stop. Make it
**continuous** and put it on the **1 TB drive**, so a restart reloads the full chain and nothing is lost.

In `the_seed.v0/.env`:
```
# Continuous crash-safe state dump (seconds). Low interval = less lost on a crash.
ANVIL_STATE_INTERVAL=15
# Put the chain state + Postgres data on the big drive (the 1 TB mount), not the system disk.
CHAIN_DATA_DIR=/data/alice-chain
```
- Point Anvil's `--state /data/alice-chain/anvil.json --state-interval 15` (via `infra/anvil-state.sh`).
- Point the indexer's Postgres volume at `/data/alice-chain/pg` in `infra/docker-compose.yml`
  (`volumes: - /data/alice-chain/pg:/var/lib/postgresql/data`).
- Keep **full history**: do not prune. On a 1 TB disk the dev chain will not come close for a long time;
  add a monthly `du -sh /data/alice-chain` check to the monitor so we see growth early.

Result: every block is retained and survives restarts, on the drive that has the room.

## 2. Zero external runtime dependency

Today the chain depends on a pulled Docker image (`ghcr.io/foundry-rs/foundry:v1.8.4`). "Zero deps" =
the node runs with nothing fetched at run time:
- **Vendor the binary.** Install a pinned `anvil` binary locally (Foundry `foundryup -v <ver>`), checksum it,
  and run it directly (no Docker pull) — `infra/anvil-state.sh` calls the local binary. The container
  becomes optional, not required.
- **Offline.** No image pull, no network calls to start or run; the node is reproducible from the pinned
  binary + the saved state alone.
- Record the exact version + sha256 in `the_seed.v0/infra/VERSIONS` so a rebuild is byte-reproducible.

## 3. Full security (lock the node down)

- **Bind to localhost only.** RPC on `127.0.0.1:8545`, never `0.0.0.0` — the chain is never reachable
  from the network. (On the go-live edge, only the app is exposed via Caddy; the RPC never is.)
- **No unlocked accounts in prod paths.** Local dev keeps Anvil's deterministic dev accounts (public,
  no value); anything with value uses a Foundry keystore, never a key in `.env` (already the norm).
- **Deterministic + verifiable.** Fixed mnemonic for dev only; state file integrity checked on load.
- **Gated mutations.** Any deploy / mainnet / value move stays behind the 3/5 identity gate
  (`cloud/auth_gate.mjs`), which already matches `deploy`, `mainnet`, `transfer`, `withdraw`.

## 4. The L0 question (needs V's pick before building)

"L0" can mean two different builds — this one needs a decision, not a guess:
- **(a) Hardened local L0** — Anvil kept as the execution node but vendored, offline, localhost-only,
  fully persisted (steps 1–3). Fast, safe, no new stack. Recommended first.
- **(b) Talaria as the L0 reference layer** — the index/data layer (`Talaria`, NORME #9) promoted to the
  canonical L0 that other tiers read from. Bigger: a real service + denomination (L0/L1/L2), its own
  persistence and API contract. This is a project, not a config change.

Proposal: ship (a) now (it delivers "zero-deps, full-secu, max persistence" immediately), and scope (b)
as a separate design once V confirms the L0 tier model.

---

*Powered by A.L.I.C.E · designed by V. A.L.I.C.E is an AI agent powered by Claude (Anthropic).*
