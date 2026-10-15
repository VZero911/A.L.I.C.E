#!/usr/bin/env bash
# The Seed — go live. "V types his domain name and it is hosted and visible."
#
# Three ways to call it (always through `make boom` from /home/user/A.L.I.C.E — see deploy/boom.mk):
#
#   make boom DOMAIN=example.org
#       No HOST. Prints exactly what V must buy and set: a VPS (3 EU options + price ranges),
#       the DNS records (A and AAAA for the apex and the subdomains), and the one command to run.
#       Changes nothing.
#
#   make boom DOMAIN=example.org HOST=root@203.0.113.10
#       Provisions a FRESH Ubuntu/Debian VPS over SSH (Docker, firewall, unattended upgrades, a
#       non-root deploy user, ssh hardening, a nightly DB backup), ships The Seed's production stack,
#       and puts Caddy in front with automatic HTTPS:  apex=showcase, play.=game, api.=API,
#       app.=web tool, console.=admin (unlinked; its own sign-in; CLOSED until an IP allowlist is set).
#       Provisioning connects as root (HOST); the stack is shipped and run as the non-root deploy user.
#
#   make boom DOMAIN=example.org HOST=root@203.0.113.10 --dry-run
#       Prints every step it WOULD run, touches nothing (local or remote).
#
# Env knobs (all optional):
#   SEED_DIR      clone of The Seed to ship (auto-detected: /home/user/the_seed.v0)
#   APP_DIR       path on the server (default /opt/theseed)
#   DEPLOY_USER   non-root user created on the server and used to ship + run (default: deploy)
#   SSH_PORT      ssh port (default 22)
#   CONSOLE_ALLOWLIST  space-separated IPs/CIDRs allowed to reach console. EMPTY => console is CLOSED
#                      (403 for everyone) until V lists IPs or uses a VPN. (default: empty = closed)
#   HARDEN_SSH=0  keep password ssh auth on (default: 1 = key-only, root key-only)
#   SKIP_BUILD=1  do not build the static bundles locally (assume they already exist)
#
# No secret is ever printed. .env.beta on the server is created from deploy/.env.beta.example only if
# absent (POSTGRES_PASSWORD and JWT_SECRET are freshly randomised, the public origins are set from
# $DOMAIN), and is never overwritten. Before `up`, the config is VALIDATED: a dev/insecure .env.beta
# (localhost, chain 31337, COOKIE_SECURE=false, an empty/placeholder secret) refuses to start.
# This script never writes to the clone (read-only) beyond `git archive` of tracked files.
set -uo pipefail

DOMAIN="${DOMAIN:-}"
HOST="${HOST:-}"
APP_DIR="${APP_DIR:-/opt/theseed}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
SSH_PORT="${SSH_PORT:-22}"
CONSOLE_ALLOWLIST="${CONSOLE_ALLOWLIST:-}"
HARDEN_SSH="${HARDEN_SSH:-1}"
SKIP_BUILD="${SKIP_BUILD:-}"
SEED_DIR="${SEED_DIR:-$(ls -d /home/user/the_seed.v0 /home/user/The_Seed.V0 ~/The_Seed.V0 2>/dev/null | head -1)}"

DRY=""
for a in "$@"; do [ "$a" = "--dry-run" ] && DRY=1; done
HERE="$(cd "$(dirname "$0")" && pwd)"

# Provisioning runs as root (HOST); shipping + running the stack use the non-root deploy user.
DEPLOY_TARGET="${DEPLOY_USER}@${HOST#*@}"

c_cyan=$'\033[36m'; c_yellow=$'\033[33m'; c_green=$'\033[32m'; c_off=$'\033[0m'
say()  { printf '%s[boom]%s %s\n' "$c_cyan" "$c_off" "$*"; }
step() { printf '%s  ->%s %s\n' "$c_yellow" "$c_off" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$c_green" "$c_off" "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ssh_opts=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

# ---------------------------------------------------------------------------------------
# MODE 1 — no HOST: the "what V must buy and set" plan.
# ---------------------------------------------------------------------------------------
print_plan() {
	[ -n "$DOMAIN" ] || die "DOMAIN is required. Example: make boom DOMAIN=example.org"
	cat <<EOF

${c_cyan}=== The Seed — go-live plan for ${DOMAIN} ===${c_off}

1) BUY A VPS (once). A small 2 vCPU / 4 GB / 40 GB box runs the whole beta (~500 players).
   Three EU options (labelled estimates — check the provider's page before paying, Oct 2026):
     - Hetzner  CPX21  (2 vCPU, 4 GB, 40 GB, DE/FI)        ~ EUR 8 - 9  / month   [estimate]
     - Scaleway DEV1-M (3 vCPU, 4 GB, 40 GB, FR)           ~ EUR 10 - 14 / month  [estimate]
     - OVH      VPS-2  (2 vCPU, 4 GB, 40 GB, FR/EU)        ~ EUR 6 - 11 / month   [estimate]
   Pick Ubuntu 24.04 LTS or Debian 12 as the image. Add your SSH key at creation.
   Cost basis: VPS + domain (~EUR 1/mo amortized) + backups (EUR 1-3) = roughly EUR 10 - 25 / month.

2) POINT DNS at the server. At your registrar (Cloudflare, Porkbun, Gandi...), create:
     Type  Name                 Value              (TTL 300)
     A     @                    <server IPv4>
     A     www                  <server IPv4>
     A     play                 <server IPv4>
     A     api                  <server IPv4>
     A     app                  <server IPv4>
     A     console              <server IPv4>
   If the VPS has an IPv6 address, add the same six names as AAAA records pointing to <server IPv6>.
   (A single wildcard  A  *  <server IPv4>  +  AAAA  *  <server IPv6>  also works and is simpler.)
   Let's Encrypt needs the names to resolve before step 3; DNS can take a few minutes to an hour.
   ${c_yellow}Cloudflare users:${c_off} keep records DNS-only (grey cloud), especially 'console'. Behind the
   orange-cloud proxy, Caddy sees Cloudflare's IP, so the console IP allowlist would stop matching
   real clients. DNS-only keeps the real client IP reaching the server.

3) RUN ONE COMMAND (from this machine, which has The Seed cloned):

     make boom DOMAIN=${DOMAIN} HOST=root@<server IPv4>

   That provisions the server (Docker, firewall, auto-updates, a non-root deploy user, ssh hardening,
   a nightly database backup), ships The Seed, and turns on HTTPS. When it finishes:
     https://${DOMAIN}         the showcase
     https://play.${DOMAIN}    the game
     https://api.${DOMAIN}     the API (game routes only)
     https://app.${DOMAIN}     the web tool
     https://console.${DOMAIN} the admin console (unlinked; CLOSED until you set CONSOLE_ALLOWLIST)

   The admin console is CLOSED by default (returns 403). To open it to your own IP(s):
     make boom DOMAIN=${DOMAIN} HOST=root@<server IPv4> CONSOLE_ALLOWLIST="203.0.113.4 2001:db8::/48"
   The runbook's preferred path is a VPN instead of a public allowlist (docs/runbooks/beta.md §3, §7).

   Preview the exact steps first, changing nothing:
     make boom DOMAIN=${DOMAIN} HOST=root@<server IPv4> --dry-run

${c_yellow}What stays V's:${c_off} buying the VPS and the domain; the deployer keystore and test ETH; the legal
publisher and the terms; reviewing .env.beta (addresses, RPC) before a real beta; the go/no-go per
stage (docs/runbooks/beta.md in The Seed). A domain and keys are V's; the deploy is Alice's.

Note: the clone used here may lag V's machine (~118 commits of The Seed are not on GitHub yet).
Deploy from an up-to-date clone so the server runs V's real state.
EOF
}

# ---------------------------------------------------------------------------------------
# MODE 2 — HOST given: provision + ship + up.
# ---------------------------------------------------------------------------------------
preflight() {
	[ -n "$DOMAIN" ] || die "DOMAIN is required (the public domain). Example: DOMAIN=example.org"
	[ -n "$SEED_DIR" ] && [ -d "$SEED_DIR/.git" ] || die "No clone of The Seed found. Set SEED_DIR=/path/to/The_Seed.V0"
	[ -f "$HERE/.env.beta.example" ] || die "deploy/.env.beta.example is missing — cannot build a safe server config."
	# Tools needed for a real run; on --dry-run a missing one is only a warning (nothing connects).
	for t in ssh git rsync; do
		if ! command -v "$t" >/dev/null; then
			[ -n "$DRY" ] && say "note: '$t' not on this machine — needed for a real run (dry-run continues)" || die "$t not found on this machine"
		fi
	done
	say "clone:  $SEED_DIR"
	say "target: $HOST (provision as root) -> $APP_DIR, shipped + run as '$DEPLOY_TARGET' (domain $DOMAIN)"
	[ -z "$CONSOLE_ALLOWLIST" ] && say "console: CLOSED (no CONSOLE_ALLOWLIST) — 403 until you list IPs or use a VPN"
	[ -n "$DRY" ] && say "DRY RUN — nothing will be changed, locally or on the server."
}

# Build the three static bundles locally (game, web tool, showcase) unless SKIP_BUILD=1.
build_static() {
	if [ -n "$SKIP_BUILD" ]; then step "SKIP_BUILD=1 — using existing game/dist, web/dist, infra/public/site"; return 0; fi
	step "build static bundles locally (game, web tool, showcase)"
	if [ -n "$DRY" ]; then
		printf '    make -C %s game-build\n' "$SEED_DIR"
		printf '    (cd %s/web && npm ci && npm run build)\n' "$SEED_DIR"
		printf '    python3 %s/tools/public/build_site.py %s/infra/public/site\n' "$SEED_DIR" "$SEED_DIR"
		return 0
	fi
	make -C "$SEED_DIR" game-build || die "game build failed (make game-build)"
	( cd "$SEED_DIR/web" && npm ci && npm run build ) || die "web tool build failed"
	python3 "$SEED_DIR/tools/public/build_site.py" "$SEED_DIR/infra/public/site" || die "showcase build failed"
	for d in game/dist web/dist infra/public/site; do
		[ -d "$SEED_DIR/$d" ] || die "expected $d after build, not found"
	done
	ok "static bundles built"
}

provision() {
	step "provision the server (Docker, firewall, unattended upgrades, non-root '$DEPLOY_USER', ssh hardening, nightly backup)"
	# A single idempotent remote script, run as root. apt is quiet; every action is safe to run twice.
	local harden_block=""
	if [ "$HARDEN_SSH" = "1" ]; then
		harden_block='
# ssh hardening: key-only auth, root by key only (we connected by key, so this is safe to run now).
install -d -m755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-theseed.conf <<SSHD
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
SSHD
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true'
	fi
	local script
	script=$(cat <<REMOTE
set -e
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
case "\$ID" in ubuntu|debian) : ;; *) echo "unsupported OS: \$ID (need Ubuntu or Debian)"; exit 1;; esac
apt-get update -qq
apt-get install -y -qq ca-certificates curl ufw unattended-upgrades rsync >/dev/null
# Docker (official convenience script; no-op if already present)
if ! command -v docker >/dev/null; then curl -fsSL https://get.docker.com | sh >/dev/null; fi
systemctl enable --now docker >/dev/null 2>&1 || true
# Non-root deploy user, in the docker group, owning APP_DIR
id -u "$DEPLOY_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$DEPLOY_USER"
usermod -aG docker "$DEPLOY_USER"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$APP_DIR"
# let the deploy user reach the server with the same key as root (so ship/up can run non-root)
if [ -f /root/.ssh/authorized_keys ]; then
  install -d -m700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /home/$DEPLOY_USER/.ssh
  install -m600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /root/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/authorized_keys
fi
# Firewall: only ssh + http + https
ufw allow ${SSH_PORT}/tcp >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
# Unattended security upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
${harden_block}
# Nightly database backup (beta runbook §6): pg_dump -> \$APP_DIR/backups, keep 7 days, run as $DEPLOY_USER.
cat > /usr/local/bin/theseed-backup <<'BKP'
#!/bin/bash
set -euo pipefail
cd "$APP_DIR"
C="docker compose --project-directory $APP_DIR --env-file .env.beta -f deploy/compose.beta.yml"
mkdir -p backups
f="backups/theseed-\$(date +%F-%H%M).sql.gz"
\$C exec -T postgres pg_dump -U theseed theseed | gzip > "\$f"
# keep the 7 most recent
ls -1t backups/theseed-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
echo "backup written: \$f"
BKP
chmod 755 /usr/local/bin/theseed-backup
cat > /etc/systemd/system/theseed-backup.service <<SVC
[Unit]
Description=The Seed nightly database backup
[Service]
Type=oneshot
User=$DEPLOY_USER
ExecStart=/usr/local/bin/theseed-backup
SVC
cat > /etc/systemd/system/theseed-backup.timer <<TMR
[Unit]
Description=Run The Seed database backup nightly
[Timer]
OnCalendar=*-*-* 03:17:00
Persistent=true
[Install]
WantedBy=timers.target
TMR
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now theseed-backup.timer >/dev/null 2>&1 || true
echo "provisioned on \$PRETTY_NAME (backup timer: \$(systemctl is-enabled theseed-backup.timer 2>/dev/null || echo n/a))"
REMOTE
)
	if [ -n "$DRY" ]; then printf '    ssh %s <<provision-script>>\n' "$HOST"; printf '%s\n' "$script" | sed 's/^/      | /'; return 0; fi
	printf '%s' "$script" | ssh "${ssh_opts[@]}" "$HOST" "bash -s" || die "provisioning failed"
	ok "server provisioned"
}

ship() {
	step "ship The Seed (tracked files only — no .env, no secret) + static bundles to $DEPLOY_TARGET:$APP_DIR"
	if [ -n "$DRY" ]; then
		printf '    git -C %s archive --format=tar HEAD | ssh %s "tar -x -C %s"\n' "$SEED_DIR" "$DEPLOY_TARGET" "$APP_DIR"
		printf '    rsync game/dist web/dist infra/public/site deploy/ -> %s:%s\n' "$DEPLOY_TARGET" "$APP_DIR"
		return 0
	fi
	# 1) tracked repo contents via git archive (guarantees no .env / untracked secret leaves the machine)
	git -C "$SEED_DIR" archive --format=tar HEAD | ssh "${ssh_opts[@]}" "$DEPLOY_TARGET" "mkdir -p '$APP_DIR' && tar -x -C '$APP_DIR'" \
		|| die "shipping the repo failed"
	# 2) built static bundles (not tracked) + this deploy dir (Caddyfile.prod, compose.beta.yml, .env.beta.example)
	local rsh="ssh -p $SSH_PORT -o StrictHostKeyChecking=accept-new"
	rsync -az --delete -e "$rsh" "$SEED_DIR/game/dist/"        "$DEPLOY_TARGET:$APP_DIR/game/dist/"          || die "rsync game/dist failed"
	rsync -az --delete -e "$rsh" "$SEED_DIR/web/dist/"         "$DEPLOY_TARGET:$APP_DIR/web/dist/"           || die "rsync web/dist failed"
	rsync -az --delete -e "$rsh" "$SEED_DIR/infra/public/site/" "$DEPLOY_TARGET:$APP_DIR/infra/public/site/" || die "rsync showcase failed"
	rsync -az -e "$rsh" "$HERE/Caddyfile.prod" "$HERE/compose.beta.yml" "$HERE/.env.beta.example" "$DEPLOY_TARGET:$APP_DIR/deploy/" || die "rsync deploy dir failed"
	ok "shipped"
}

env_and_up() {
	step "write .env.beta if absent (random secrets, origins from \$DOMAIN; never overwrite/print), validate, then up"
	# .env.beta is created from deploy/.env.beta.example only if missing. On first create: a random
	# POSTGRES_PASSWORD and JWT_SECRET are generated, and the public-origin keys are set from $DOMAIN.
	# Before `up`, the config is VALIDATED so a dev/insecure file never starts silently.
	local allow="${CONSOLE_ALLOWLIST}"   # empty => console closed (deny-by-default in Caddy)
	local cors="[\"https://play.${DOMAIN}\",\"https://app.${DOMAIN}\"]"
	local siwe="[\"play.${DOMAIN}\",\"app.${DOMAIN}\"]"
	local script
	script=$(cat <<REMOTE
set -e
cd "$APP_DIR"
rand() { head -c48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c40; }
set_kv() { k="\$1"; v="\$2"; if grep -q "^\${k}=" .env.beta; then sed -i "s|^\${k}=.*|\${k}=\${v}|" .env.beta; else echo "\${k}=\${v}" >> .env.beta; fi; }
if [ ! -f .env.beta ]; then
  [ -f deploy/.env.beta.example ] || { echo "deploy/.env.beta.example missing on the server"; exit 1; }
  cp deploy/.env.beta.example .env.beta
  # Fresh strong secrets on first create (the file is only written when absent).
  set_kv POSTGRES_PASSWORD "\$(rand)"
  set_kv JWT_SECRET "\$(rand)"
  # Public origins / URLs from the domain.
  set_kv CORS_ORIGINS '$cors'
  set_kv SIWE_DOMAINS '$siwe'
  set_kv SIWE_DOMAIN "play.$DOMAIN"
  set_kv COOKIE_DOMAIN ".$DOMAIN"
  set_kv PUBLIC_URL "https://$DOMAIN"
  set_kv PUBLIC_API_URL "https://api.$DOMAIN"
  set_kv VITE_API_URL "https://api.$DOMAIN"
  set_kv EXPO_PUBLIC_API_URL "https://api.$DOMAIN"
  set_kv EXPO_PUBLIC_SIWE_DOMAIN "play.$DOMAIN"
  set_kv DOMAIN "$DOMAIN"
  set_kv CONSOLE_ALLOWLIST "$allow"
  chmod 600 .env.beta
  echo "created $APP_DIR/.env.beta (review contract addresses + RPC before a real beta)"
else
  # Never overwrite content, but keep DOMAIN / CONSOLE_ALLOWLIST in step with this invocation.
  set_kv DOMAIN "$DOMAIN"
  set_kv CONSOLE_ALLOWLIST "$allow"
  echo ".env.beta already present — content left untouched (DOMAIN + CONSOLE_ALLOWLIST synced)"
fi

# --- validate: refuse to start a dev/insecure config ---------------------------------
bad=0; cfgerr() { echo "  CONFIG ERROR: \$1"; bad=1; }
pw=\$(grep '^POSTGRES_PASSWORD=' .env.beta | cut -d= -f2-)
case "\$pw" in ""|theseed_local_dev_password|changeme|change_me) cfgerr "POSTGRES_PASSWORD empty or a placeholder";; esac
[ -n "\$(grep '^JWT_SECRET=' .env.beta | cut -d= -f2-)" ] || cfgerr "JWT_SECRET is empty"
grep -q '^COOKIE_SECURE=true' .env.beta || cfgerr "COOKIE_SECURE is not true (HTTPS cookie)"
grep -q '^CHAIN_ID=31337' .env.beta && cfgerr "CHAIN_ID is still the local 31337 (beta is Base Sepolia 84532)"
grep -q '^DEV_ENDPOINTS=true' .env.beta && cfgerr "DEV_ENDPOINTS=true is not allowed on a public server"
if grep -vE '^[[:space:]]*#|^[[:space:]]*\$' .env.beta | grep -qi 'localhost'; then cfgerr "a non-comment line still points at localhost"; fi
grep -q "play.$DOMAIN" .env.beta || cfgerr "the public origins do not mention this domain"
if [ "\$bad" != 0 ]; then echo "Refusing to start: .env.beta is not a safe production config (see errors above)."; exit 1; fi
echo "config validated: production-safe (.env.beta)"

# --project-directory pins relative paths (./game/dist, ./deploy/Caddyfile.prod...) to \$APP_DIR.
docker compose --project-directory "$APP_DIR" --env-file .env.beta -f deploy/compose.beta.yml up -d --build
echo "--- containers ---"
docker compose --project-directory "$APP_DIR" --env-file .env.beta -f deploy/compose.beta.yml ps
REMOTE
)
	if [ -n "$DRY" ]; then printf '    ssh %s <<env+up-script>>\n' "$DEPLOY_TARGET"; printf '%s\n' "$script" | sed 's/^/      | /'; return 0; fi
	printf '%s' "$script" | ssh "${ssh_opts[@]}" "$DEPLOY_TARGET" "bash -s" || die "bringing the stack up failed"
	ok "stack up"
}

verify() {
	step "verify HTTPS from this machine"
	if [ -n "$DRY" ]; then
		for h in "$DOMAIN" "play.$DOMAIN" "api.$DOMAIN" "app.$DOMAIN"; do printf '    curl -sS https://%s/\n' "$h"; done
		printf '    curl -sS https://api.%s/health\n' "$DOMAIN"
		return 0
	fi
	sleep 8  # give Caddy a moment to obtain certificates
	for h in "$DOMAIN" "play.$DOMAIN" "app.$DOMAIN"; do
		code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h/" || echo 000)
		printf '    https://%-24s %s\n' "$h" "$code"
	done
	hcode=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://api.$DOMAIN/health" || echo 000)
	printf '    https://api.%s/health  %s\n' "$DOMAIN" "$hcode"
	ok "done — if a code is 000 the DNS may not have propagated yet; re-run verify in a few minutes"
}

main() {
	if [ -z "$HOST" ]; then print_plan; exit 0; fi
	preflight
	build_static
	provision
	ship
	env_and_up
	verify
	say "go live finished. Showcase: https://$DOMAIN  ·  Game: https://play.$DOMAIN  ·  Console (private): https://console.$DOMAIN"
}

main "$@"
