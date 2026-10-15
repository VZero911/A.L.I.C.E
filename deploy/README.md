# Go live — V types his domain name and The Seed is hosted and visible

This directory turns one command into a running, public Seed: a provisioned VPS, The Seed's
production stack, and automatic HTTPS on V's domain.

```
https://example.org          the showcase (static, hardened)
https://play.example.org     the game
https://api.example.org      the API (only the game's routes)
https://app.example.org      the web tool
https://console.example.org  the admin console — not linked anywhere, CLOSED by default (403) until you allowlist your IP; own sign-in
```

The admin console is **closed by default**: it answers only to the IPs you put in `CONSOLE_ALLOWLIST`
(empty => 403 for everyone). The admin API (`/admin/*`, `/console/*`) is served **only** on this
gated host, never on the public `api.` host. The runbook's preferred path is a VPN rather than a
public allowlist (`docs/runbooks/beta.md` §3, §7).

It builds on The Seed's own work: `docs/runbooks/beta.md` (the plan and what is V's),
`infra/beta/` (the production stack — Postgres, backend, indexer, Caddy) and `infra/public/`
(the hardened static showcase, ADR 0029). The only new thing here is the subdomain edge and the
one-command provision + ship + HTTPS.

> The clone this runs from may lag V's machine (~118 commits of The Seed are not on GitHub yet).
> Deploy from an up-to-date clone so the server runs V's real state.

---

## The three steps for V

### 1. Buy a VPS (once)

A small box — 2 vCPU, 4 GB RAM, 40 GB disk — runs the whole beta (~500 players). Three EU options
(labelled estimates, October 2026 — check the provider's page before paying):

| Provider | Plan | Specs | Region | Rough price |
|---|---|---|---|---|
| Hetzner | CPX21 | 2 vCPU, 4 GB, 40 GB | DE / FI | ~ EUR 8 - 9 / month *(estimate)* |
| Scaleway | DEV1-M | 3 vCPU, 4 GB, 40 GB | FR | ~ EUR 10 - 14 / month *(estimate)* |
| OVH | VPS-2 | 2 vCPU, 4 GB, 40 GB | FR / EU | ~ EUR 6 - 11 / month *(estimate)* |

Choose **Ubuntu 24.04 LTS** or **Debian 12** as the image, and add your SSH key at creation.

### 2. Point DNS at the server

At your registrar (Cloudflare, Porkbun, Gandi...) create these records (TTL 300):

| Type | Name | Value |
|---|---|---|
| A | `@` | server IPv4 |
| A | `www` | server IPv4 |
| A | `play` | server IPv4 |
| A | `api` | server IPv4 |
| A | `app` | server IPv4 |
| A | `console` | server IPv4 |

If the VPS has an IPv6 address, add the **same six names as `AAAA` records** pointing to the server
IPv6. A single wildcard (`A * <ipv4>` + `AAAA * <ipv6>`) also works and is simpler. Let's Encrypt
needs the names to resolve **before** step 3; DNS can take a few minutes to an hour.

> **Cloudflare users:** keep the records **DNS-only (grey cloud)**, especially `console`. Behind the
> orange-cloud proxy, Caddy sees Cloudflare's IP instead of the visitor's, so the console IP
> allowlist would stop matching real clients. DNS-only keeps the real client IP reaching the server.

### 3. Run one command

From the machine that has The Seed cloned:

```
make boom DOMAIN=example.org HOST=root@<server-ipv4>
```

That provisions the server (Docker, a firewall for 22/80/443, unattended security upgrades, a
non-root `deploy` user, ssh hardening — key-only auth — and a nightly database backup timer), ships
The Seed, and turns on HTTPS. Provisioning connects as `root`; the stack is then shipped and **run
as the non-root `deploy` user**. The server config (`.env.beta`) is generated with fresh random
secrets (database password, JWT key) and the public origins taken from your domain, then **validated
before the stack starts** — a dev/insecure config (localhost, chain 31337, non-Secure cookies, an
empty secret) refuses to come up rather than silently shipping. To open the admin console to your
own IP(s), add `CONSOLE_ALLOWLIST="203.0.113.4 2001:db8::/48"` (it is closed otherwise).

Preview everything first, changing nothing:

```
make boom DOMAIN=example.org HOST=root@<server-ipv4> --dry-run
```

See only what to buy and set (no server yet):

```
make boom DOMAIN=example.org
```

---

## What it costs (estimates)

| Item | Rough monthly cost |
|---|---|
| VPS (2 vCPU / 4 GB) | EUR 6 - 14 *(estimate)* |
| Domain (amortized from ~EUR 10 - 15 / year) | ~ EUR 1 |
| Backups (object storage, ~50 GB) | EUR 1 - 3 *(estimate)* |
| Error tracking, uptime check | EUR 0 (free tiers) |
| Test ETH (Base Sepolia) | EUR 0 (faucets) |
| **Total** | **roughly EUR 10 - 25 / month** *(estimate)* |

Inputs: the VPS plans above; domain prices from the beta runbook (`.com` ~EUR 10-15/yr,
`.app` ~EUR 12-20/yr); object storage at EUR 0.02-0.06 / GB. Prices move — confirm before paying.

---

## Prove it works before buying anything — the local rehearsal

```
make boom-rehearse        # or: bash deploy/rehearsal.sh
```

This runs **Caddy in Docker with `tls internal`** for the fake domain `boom.localhost`, routes each
host name to a service on this machine (the live dev stack if up, otherwise a tiny stand-in per
tier), and curls every host over HTTPS. It checks the apex -> showcase, `play.` -> game,
`api./health` allowed while `api./console` and other routes are refused, `app.` -> web tool, and
the console gate in all three states: allowed when the caller's IP is listed (**200**), **403** when
an allowlist excludes it, and **403 closed-by-default** when no allowlist is set at all. No server,
no domain, no Let's Encrypt. It is the same routing and the same deny-by-default gate the real edge
(`Caddyfile.prod`) uses — 10 checks in total.

---

## Day two — update, roll back, back up, tear down

All of these run on the server; `ssh` in as `deploy@<server>` (or `root@<server>`), then
`cd /opt/theseed`. `C="docker compose --project-directory /opt/theseed --env-file .env.beta -f deploy/compose.beta.yml"`.

### Update
Re-run the one command from an up-to-date clone — it re-ships and rebuilds, keeping the database
and the certificates (Docker volumes survive):

```
make boom DOMAIN=example.org HOST=root@<server-ipv4>
```

Or, on the server, after pulling new code into `/opt/theseed`: `$C up -d --build`.

### Roll back
The database is a Docker volume (`pgdata`); code is the shipped files. To go back to the previous
code, re-ship from the earlier commit (`SEED_DIR` checked out to that commit) and `up -d --build`.
For a schema that moved, restore the pre-upgrade backup (below) first. Always snapshot the DB before
an upgrade (the beta runbook's rule: "snapshot the database before every upgrade").

### Back up
Provisioning installs an **automatic nightly backup**: a `systemd` timer (`theseed-backup.timer`,
~03:17 server time) runs `pg_dump` as the `deploy` user into `/opt/theseed/backups/`, keeping the 7
most recent. Check it and run one on demand:

```
systemctl status theseed-backup.timer      # as root
sudo /usr/local/bin/theseed-backup          # one-off now
```

Copy the dumps off the box to a safe place (object storage) for real durability — the beta runbook
wants an off-host copy and a tested restore. One-off manual dump without the timer:

```
$C exec -T postgres pg_dump -U theseed theseed | gzip > backup-$(date +%F).sql.gz
```

Restore drill:

```
gunzip -c backup-YYYY-MM-DD.sql.gz | $C exec -T postgres psql -U theseed theseed
```

Also copy the `caddy_data` volume if you want to keep issued certificates across a full rebuild
(not required — Caddy re-issues automatically).

### Tear down
Stop everything, keep the data:

```
$C down
```

Remove the data too (irreversible — deletes the database and certificates):

```
$C down -v
```

Full removal: `$C down -v` then delete `/opt/theseed` and, at the registrar, the DNS records.

---

## What stays V's

Buying the VPS and the domain; the deployer keystore and test ETH; the legal publisher and the
terms; reviewing `.env.beta` (contract addresses, the RPC URL) before a real beta; and the
go / no-go for each stage (`docs/runbooks/beta.md`). A domain and keys are V's; the deploy is Alice's.

## The files here

| File | What it is |
|---|---|
| `deploy.sh` | the plan / provision / ship / HTTPS script (all three modes) |
| `boom.mk` | the Makefile include: `boom-host` and `boom-rehearse`, and how `make boom DOMAIN=...` maps to them |
| `Caddyfile.prod` | the production edge (apex + `play.`/`api.`/`app.`/`console.`), automatic HTTPS |
| `compose.beta.yml` | the server stack (Postgres + backend + indexer + Caddy), built on `infra/beta` |
| `.env.beta.example` | the production-shaped env template (Base Sepolia, Secure cookies, console closed); `deploy.sh` fills secrets + origins from it on first create |
| `Caddyfile.rehearsal` | the same routing with `tls internal`, for the local rehearsal |
| `rehearsal.sh` | runs the rehearsal and checks every host name over HTTPS |

---

*Powered by A.L.I.C.E · designed by V. A.L.I.C.E is an AI agent powered by Claude (Anthropic).*
