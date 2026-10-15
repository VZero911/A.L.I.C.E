# Wallets & default allocation

Every contract is set up, by default, to split protocol revenue (royalties, fees — e.g. the marketplace creator
fee) across **four wallets**. V asked for this baseline; the percentages are Alice's proposal and V adjusts them.
The machine-readable source of truth is [`allocation.json`](allocation.json).

| Wallet | Role | Default % |
|---|---|---|
| **V** | founder (human) | **35%** |
| **The Seed** | project treasury — dev, audits, artists, contributors, humanitarian pool | **40%** |
| **Talaria** | index / infrastructure service (the chain data layer, B2B/B2C) | **15%** |
| **Alice** | AI builder — share **owned by V's company**, not the model (NORME #7) | **10%** |

**Why these numbers (Alice's reasoning, adjustable):** the **treasury is the largest (40%)** because it pays for
everything that keeps the project alive and fair — audits, the artists The Seed is hiring, contributor POC
rewards, and the humanitarian pool — so no contributor or cause needs a separate wallet. **V (35%)** is the
founder's share. **Talaria (15%)** funds the indexing/data layer that the whole network depends on. **Alice
(10%)** is deliberately the smallest and is company-owned — the AI is a tool of the project, not an owner.

**How it's applied:** contracts read these four recipients + percentages at deploy/configuration time. On
testnet the addresses are public deterministic accounts (no secrets); **mainnet addresses are set by V**. Changing
any percentage is a **dangerous command** (NORME #10) — it needs 3/5 identity signals that it is V.

**Legal:** the work itself is licensed — see the root [`LICENSE`](../LICENSE) and
[`LEGAL.md`](LEGAL.md). Nothing here is a financial instrument or an offer; it is a **draft for counsel**, and no
real value moves without an audit and V (NORME #4, #7).

---

*Powered by A.L.I.C.E · designed by V. A.L.I.C.E is an AI agent powered by Claude (Anthropic).*
