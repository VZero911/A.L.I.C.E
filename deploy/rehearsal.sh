#!/usr/bin/env bash
# Local rehearsal: prove the production edge (Caddyfile.prod's routing + automatic HTTPS) works
# WITHOUT a real server. It runs Caddy in Docker with `tls internal` for a fake domain
# (boom.localhost) and routes each host name to a service on this machine, then curls every host
# through it over HTTPS and checks the answer.
#
# Origins: if The Seed's dev stack is up on this machine (showcase, game :8081, api :8000, web :5173)
# the rehearsal routes to it. Any tier that is NOT up is replaced by a tiny stand-in origin, so the
# rehearsal always proves the *edge* (host-based routing, TLS, the console allowlist, the api path
# filter) end to end. Each line of output says which origin answered.
#
# Usage:  bash deploy/rehearsal.sh          # run it
#         KEEP=1 bash deploy/rehearsal.sh   # leave Caddy + stand-ins running for manual poking
set -uo pipefail

DOMAIN="boom.localhost"
HTTPS_PORT="${HTTPS_PORT:-8443}"
NET_NAME="caddy"
CADDY_NAME="boom-rehearsal-caddy"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
PIDS=()
pass=0; fail=0

c_green=$'\033[32m'; c_red=$'\033[31m'; c_off=$'\033[0m'; c_cyan=$'\033[36m'
say() { printf '%s[rehearsal]%s %s\n' "$c_cyan" "$c_off" "$*"; }

cleanup() {
	[ -n "${KEEP:-}" ] && { say "KEEP=1 — leaving Caddy ($CADDY_NAME) and stand-ins up. Clean up with: docker rm -f $CADDY_NAME; kill ${PIDS[*]:-}"; return; }
	docker rm -f "$CADDY_NAME" >/dev/null 2>&1 || true
	for p in "${PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done
	# belt and braces: the stand-ins carry a unique marker, so clear any straggler.
	pkill -9 -f 'STANDIN-(SHOWCASE|GAME|API|WEB)' >/dev/null 2>&1 || true
	rm -rf "$TMP"
}
trap cleanup EXIT

# A stand-in origin: a tiny HTTP server that answers every path with a marker (and /health 200).
start_standin() { # start_standin PORT MARKER
	local port="$1" marker="$2"
	python3 -c '
import sys, http.server
port=int(sys.argv[1]); marker=sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def _send(self, body):
        self.send_response(200); self.send_header("Content-Type","text/plain")
        self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        self._send((marker+" "+self.path+"\n").encode())
    def log_message(self,*a): pass
http.server.HTTPServer(("0.0.0.0",port),H).serve_forever()
' "$port" "$marker" >/dev/null 2>&1 &
	PIDS+=("$!")
}

# pick an origin port: reuse a live dev service if it answers, else start a stand-in on FALLBACK.
# NOTE: this sets the named variable directly (no command substitution) so the background
# stand-in never inherits a command-sub pipe and hangs the caller.
pick() { # pick OUTVAR LIVE_PORT FALLBACK_PORT MARKER
	local __out="$1" live="$2" fb="$3" marker="$4"
	if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$live/" 2>/dev/null; then
		printf -v "$__out" '%s' "$live"
	else
		start_standin "$fb" "$marker"
		printf -v "$__out" '%s' "$fb"
	fi
}

say "domain $DOMAIN, HTTPS on :$HTTPS_PORT, Caddy with tls internal (no public server)"

# 1) choose / start origins
pick P_SHOWCASE 8080 9101 "STANDIN-SHOWCASE"
pick P_GAME     8081 9102 "STANDIN-GAME"
pick P_API      8000 9103 "STANDIN-API"
pick P_WEB      5173 9104 "STANDIN-WEB"
sleep 1
say "origins -> showcase:$P_SHOWCASE game:$P_GAME api:$P_API web:$P_WEB"

# 2) run Caddy with the rehearsal config, console allowlist set to localhost only (to prove the gate)
docker rm -f "$CADDY_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CADDY_NAME" \
	--add-host=host.docker.internal:host-gateway \
	-p "$HTTPS_PORT:443" \
	-e DOMAIN="$DOMAIN" \
	-e PORT_SHOWCASE="$P_SHOWCASE" -e PORT_GAME="$P_GAME" -e PORT_API="$P_API" -e PORT_WEB="$P_WEB" \
	-e CONSOLE_ALLOWLIST="127.0.0.1/32 ::1/128 172.16.0.0/12" \
	-v "$HERE/Caddyfile.rehearsal:/etc/caddy/Caddyfile:ro" \
	caddy:2-alpine >/dev/null || { echo "could not start Caddy"; exit 1; }

# wait for Caddy to be listening + have minted its internal certs
for _ in $(seq 1 20); do
	curl -sk --resolve "$DOMAIN:$HTTPS_PORT:127.0.0.1" "https://$DOMAIN:$HTTPS_PORT/" >/dev/null 2>&1 && break
	sleep 1
done

# 3) curl every host through Caddy and check the answer
check() { # check HOST PATH EXPECT_SUBSTR [EXPECT_CODE]
	local host="$1" path="$2" expect="$3" ecode="${4:-200}"
	local url="https://$host:$HTTPS_PORT$path"
	local out code body
	out=$(curl -sk --resolve "$host:$HTTPS_PORT:127.0.0.1" -w '\n%{http_code}' --max-time 10 "$url" 2>/dev/null)
	code="${out##*$'\n'}"; body="${out%$'\n'*}"
	local first="${body%%$'\n'*}"
	if [ "$code" = "$ecode" ] && { [ -z "$expect" ] || printf '%s' "$body" | grep -q "$expect"; }; then
		printf '  %sPASS%s %-28s %s  (%s)\n' "$c_green" "$c_off" "$host$path" "$code" "${first:0:42}"
		pass=$((pass+1))
	else
		printf '  %sFAIL%s %-28s %s  want ~%s/%s  got: %s\n' "$c_red" "$c_off" "$host$path" "$code" "$expect" "$ecode" "${first:0:42}"
		fail=$((fail+1))
	fi
}

echo
say "curl each host through Caddy (HTTPS, internal CA):"
check "$DOMAIN"             "/"          ""     200   # apex -> showcase
check "www.$DOMAIN"         "/"          ""     200   # www  -> showcase
check "play.$DOMAIN"        "/"          ""     200   # play -> game
check "api.$DOMAIN"         "/health"    ""     200   # api  -> backend health route (allowed)
check "api.$DOMAIN"         "/console"   ""     404   # api  -> console path refused
check "api.$DOMAIN"         "/nope"      ""     404   # api  -> non-game route refused
check "app.$DOMAIN"         "/"          ""     200   # app  -> web tool
check "console.$DOMAIN"     "/"          ""     200   # console: this IP is on the allowlist -> allowed

# prove the allowlist blocks: restart Caddy with an allowlist that excludes the docker gateway
say "re-run console. with an allowlist that excludes the caller (proves the gate blocks):"
docker rm -f "$CADDY_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CADDY_NAME" \
	--add-host=host.docker.internal:host-gateway \
	-p "$HTTPS_PORT:443" \
	-e DOMAIN="$DOMAIN" \
	-e PORT_SHOWCASE="$P_SHOWCASE" -e PORT_GAME="$P_GAME" -e PORT_API="$P_API" -e PORT_WEB="$P_WEB" \
	-e CONSOLE_ALLOWLIST="203.0.113.0/32" \
	-v "$HERE/Caddyfile.rehearsal:/etc/caddy/Caddyfile:ro" \
	caddy:2-alpine >/dev/null
for _ in $(seq 1 20); do curl -sk --resolve "$DOMAIN:$HTTPS_PORT:127.0.0.1" "https://$DOMAIN:$HTTPS_PORT/" >/dev/null 2>&1 && break; sleep 1; done
check "console.$DOMAIN"     "/"          "forbidden" 403

# prove the console is CLOSED by default: no CONSOLE_ALLOWLIST passed at all -> Caddy's TEST-NET
# default ({$CONSOLE_ALLOWLIST:192.0.2.1/32}) -> no real client matches -> 403. This mirrors prod,
# where compose substitutes the same TEST-NET default when V configures no allowlist.
say "re-run console. with NO allowlist set at all (proves it is CLOSED by default):"
docker rm -f "$CADDY_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CADDY_NAME" \
	--add-host=host.docker.internal:host-gateway \
	-p "$HTTPS_PORT:443" \
	-e DOMAIN="$DOMAIN" \
	-e PORT_SHOWCASE="$P_SHOWCASE" -e PORT_GAME="$P_GAME" -e PORT_API="$P_API" -e PORT_WEB="$P_WEB" \
	-v "$HERE/Caddyfile.rehearsal:/etc/caddy/Caddyfile:ro" \
	caddy:2-alpine >/dev/null
for _ in $(seq 1 20); do curl -sk --resolve "$DOMAIN:$HTTPS_PORT:127.0.0.1" "https://$DOMAIN:$HTTPS_PORT/" >/dev/null 2>&1 && break; sleep 1; done
check "console.$DOMAIN"     "/"          "forbidden" 403

echo
if [ "$fail" -eq 0 ]; then
	printf '%s[rehearsal] ALL %d CHECKS PASSED%s — the edge config routes correctly over HTTPS.\n' "$c_green" "$pass" "$c_off"
	exit 0
else
	printf '%s[rehearsal] %d passed, %d FAILED%s\n' "$c_red" "$pass" "$fail" "$c_off"
	exit 1
fi
