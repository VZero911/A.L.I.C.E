# A.L.I.C.E — key pieces (security gate · wallet allocation · go-live). `make help` lists the targets.
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Go-live (boom-host / boom-rehearse) and the DOMAIN delegation live in deploy/boom.mk.
include deploy/boom.mk

.PHONY: help auth wallets

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

auth: ## Authorization gate: is an action allowed? 3/5 identity signals for dangerous commands. make auth A="git merge ..."
	@node cloud/auth_gate.mjs check "$(A)"

wallets: ## Show the four-wallet protocol allocation (V · The Seed · Talaria · Alice)
	@node -e 'const a=require("./economics/allocation.json");for(const [n,w] of Object.entries(a.wallets))console.log(String(w.pct).padStart(3)+"%  "+n)'
