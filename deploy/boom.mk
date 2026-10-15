# deploy/boom.mk — the go-live targets, as a Makefile include.
#
# WHAT THIS GIVES V
#   make boom DOMAIN=example.org                          -> prints what to buy + the DNS records + the one command
#   make boom DOMAIN=example.org HOST=root@203.0.113.10   -> provisions the VPS, ships The Seed, HTTPS on the domain
#   make boom DOMAIN=example.org HOST=root@... DRYRUN=1   -> prints every step, changes nothing
#   make boom-rehearse                                    -> local proof (Caddy + tls internal, no server)
#
# HOW "make boom DOMAIN=..." MAPS TO boom-host
#   The A.L.I.C.E Makefile ALREADY has a `boom` target (the cloud node: tools, The Seed up, snapshot,
#   report). That target must NOT be edited here. The lead wires the delegation in the main Makefile
#   like this (one line added to the existing `boom` recipe, guarded by DOMAIN):
#
#       include deploy/boom.mk
#       boom:
#               # ... the existing cloud-node recipe stays exactly as it is ...
#       ifdef DOMAIN
#               @$(MAKE) boom-host DOMAIN=$(DOMAIN) $(if $(HOST),HOST=$(HOST)) \
#                   $(if $(CONSOLE_ALLOWLIST),CONSOLE_ALLOWLIST=$(CONSOLE_ALLOWLIST)) $(if $(DRYRUN),DRYRUN=1)
#       endif
#
#   So: no DOMAIN -> `make boom` is unchanged (cloud node only). DOMAIN set -> after the cloud-node
#   work, `boom` delegates to `boom-host`, which runs deploy/deploy.sh. DOMAIN with no HOST is the
#   "what to buy" plan; DOMAIN+HOST is the real go-live.
#
#   NOTE: the current main Makefile already defines a `boom-host` that calls cloud/deploy/deploy.sh
#   (an earlier, single-domain, IP-first version). This file's `boom-host` calls THIS dir's richer
#   deploy.sh (apex showcase + play./api./app./console. subdomains, fresh non-root user, AAAA
#   records, local rehearsal). The lead keeps ONE of them: to adopt this one, delete the old
#   `boom-host` recipe from the main Makefile and `include deploy/boom.mk` instead. Two targets with
#   the same name make `make` warn and keep the last — so do not leave both.
#
# Variables (override on the command line):
#   DOMAIN   the public domain (required for every go-live call)
#   HOST     ssh target of the server, e.g. root@203.0.113.10 (omit for the plan)
#   DRYRUN   =1 to print the plan/steps and change nothing
#   plus the env knobs deploy.sh reads: SEED_DIR, APP_DIR, DEPLOY_USER, SSH_PORT,
#   CONSOLE_ALLOWLIST, SKIP_BUILD (see deploy/deploy.sh header).

.PHONY: boom-host boom-rehearse

boom-host: ## Go live: provision a VPS, ship The Seed, HTTPS on DOMAIN. DOMAIN=example.org [HOST=root@ip] [CONSOLE_ALLOWLIST="ip ip"] [DRYRUN=1]
	@DOMAIN="$(DOMAIN)" HOST="$(HOST)" CONSOLE_ALLOWLIST="$(CONSOLE_ALLOWLIST)" bash deploy/deploy.sh $(if $(DRYRUN),--dry-run)

boom-rehearse: ## Local proof the edge works with no server: Caddy (tls internal) for boom.localhost, curl every host
	@bash deploy/rehearsal.sh
