# Security — only V (or V's Alice) runs dangerous commands

V's rule (2026-10-05): **a dangerous command must prove it is V, or V's master Alice, with at least 3 of 5
identity signals — otherwise block it *before* it runs.** This is defense-in-depth: it sits in front of the
system's own auto-mode classifier, which already hard-blocks the worst actions (merge, self-modification,
unsafe-agent creation) no matter what. The gate here adds an identity check on top.

## The five identity signals

Each is 0 or 1; a gated action needs **≥ 3**. Checked by `cloud/auth_gate.mjs` (the caller sets each from a real
check; it never trusts a claim it did not verify):

| # | Signal | True when | Source |
|---|--------|-----------|--------|
| 1 | **ACCOUNT** | the acting account is V's (uuid `cf0561d8…`, `vzero911@gmail.com`) | `get_session` creator / session account |
| 2 | **PERMRULE** | V has set the explicit settings permission for this action class | the action was not classifier-blocked / an allow rule exists |
| 3 | **MASTER** | the command comes from the master node (v-pc) or the designated cloud session, not an unknown node | node identity / session id |
| 4 | **WALLET** | a fresh, valid signature from V's wallet (`0xf39F…`) or Alice's master key over a challenge | The Seed SIWE / a signed message |
| 5 | **OOB** | a fresh out-of-band ack from V (push-notification confirm, or a one-time code), within a short window | a second channel |

Fewer than 3 → **BLOCK**, and say which signals were missing. Three or more → allow, and log which signals carried it.

## What counts as dangerous (always gated)

Merge to `main` or the dev branch · deploy to production · move real on-chain value (transfer/withdraw/mainnet) ·
change the master config, the budget, or this policy · delete repos or data · rotate or expose keys · grant
permissions · anything touching a private key. Everything else runs normally.

## How it's used

Automation calls the gate before a dangerous step:

```sh
AUTH_ACCOUNT="$acct" AUTH_PERMRULE=1 AUTH_MASTER=1 node cloud/auth_gate.mjs check "git merge origin/wip/x"
# exit 0 = allowed (≥3/5) · exit 2 = BLOCKED (<3/5, not proven to be V)
```

In practice, the 24/7 cloud Alice sits at **2/5 at most on its own** (MASTER from the designated session, and
PERMRULE when V set a rule) — which is *below* the threshold for dangerous actions by design. To cross 3/5 for a
dangerous action, V adds a human signal: the settings permission (PERMRULE), a wallet signature (WALLET), or an
out-of-band ack (OOB). That is exactly why Alice cannot merge, deploy, or move value on her own, and why only V
(or V acting through Alice) can.

## Alice's identity (the wallet signal)

Alice's public identity is recorded in the master node document (`cloud/fleet/master-register.mjs`): the testnet
addresses for V and for Alice/SYSTEM, an ENS name claimed by V on mainnet (NORME #2), and `certified: false` until
V certifies it via The Seed's Names contract or a signed attestation — **never faked**. The **private key is never
in the repo** (NORME #5); signatures are produced where the key lives (V's machine / a vault), never here.

---

*Powered by A.L.I.C.E · designed by V. A.L.I.C.E is an AI agent powered by Claude (Anthropic).*
