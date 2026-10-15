#!/usr/bin/env node
// Authorization gate — "only V (or V's Alice) may run dangerous commands" (V, 2026-10-05).
// A dangerous command must score at least 3 of 5 identity signals that the actor is V / V's master Alice.
// Fewer than 3 -> BLOCK before executing (exit 2). This is defense-in-depth IN FRONT of the system's own
// auto-mode classifier (which already hard-blocks merge, self-modification, unsafe-agent creation regardless).
//
//   node cloud/auth_gate.mjs check "<command or action class>"      -> score signals, exit 0 allow / 2 block
//   node cloud/auth_gate.mjs signals                                 -> print the current signal reading
//
// The five signals (each 0 or 1), read from the environment the caller sets from real checks:
//   1 ACCOUNT   AUTH_ACCOUNT == V's account uuid (from get_session creator / userEmail).      env AUTH_ACCOUNT
//   2 PERMRULE  the explicit settings permission rule for this action class is present.        env AUTH_PERMRULE=1
//   3 MASTER    origin is the master node (v-pc) or the designated cloud session, not unknown. env AUTH_MASTER=1
//   4 WALLET    a fresh valid signature from V's wallet (or Alice master key) over a challenge. env AUTH_WALLET_SIG=1
//   5 OOB       a fresh out-of-band ack from V (push-notification confirm / one-time code).     env AUTH_OOB=1
//
// Dangerous classes (always gated): merge to main/dev, deploy to production, move real on-chain value,
// change the master config / budget / this policy, delete repos or data, rotate keys, grant permissions.
// Public repo: no default account id. V sets V_ACCOUNT in the environment; without it the ACCOUNT signal never scores.
const V_ACCOUNT = (process.env.V_ACCOUNT || '').trim();
const THRESHOLD = Number(process.env.AUTH_THRESHOLD || 3);

const DANGEROUS = [
  /\bgit\s+merge\b/, /\bgit\s+push\b.*\b(main|master)\b/, /\bgit\s+reset\s+--hard\b/, /\bgit\s+push\s+--force/,
  /\brm\s+-rf\b/, /\bdeploy\b/, /\bboom-host\b/, /\bmainnet\b/, /\btransfer\b/, /\bwithdraw\b/, /privateKey|PRIVATE_KEY/,
  /\bcreate_trigger\b/, /permissions/, /settings\.json/, /\bdelete\b/, /\bdrop\s+(table|database)\b/,
];

const signals = () => {
  const acct = (process.env.AUTH_ACCOUNT || '').trim();
  return {
    ACCOUNT: V_ACCOUNT && acct === V_ACCOUNT ? 1 : 0,
    PERMRULE: process.env.AUTH_PERMRULE === '1' ? 1 : 0,
    MASTER: process.env.AUTH_MASTER === '1' ? 1 : 0,
    WALLET: process.env.AUTH_WALLET_SIG === '1' ? 1 : 0,
    OOB: process.env.AUTH_OOB === '1' ? 1 : 0,
  };
};
const score = (s) => Object.values(s).reduce((a, b) => a + b, 0);

const cmd = process.argv[2];
if (cmd === 'signals') {
  const s = signals();
  console.log(`identity signals: ${score(s)}/5 — ${Object.entries(s).map(([k, v]) => `${k}=${v}`).join(' ')} (need ${THRESHOLD})`);
  process.exit(0);
}
// default: check
const action = process.argv.slice(3).join(' ') || process.argv[2] || '';
const isDangerous = DANGEROUS.some((re) => re.test(action));
const s = signals();
const n = score(s);
if (!isDangerous) {
  console.log(`not a gated dangerous action — allowed (signals ${n}/5)`);
  process.exit(0);
}
if (n >= THRESHOLD) {
  console.log(`DANGEROUS action allowed: ${n}/5 identity signals (>= ${THRESHOLD}) — ${Object.entries(s).filter(([, v]) => v).map(([k]) => k).join(', ')}`);
  process.exit(0);
}
console.error(`BLOCKED (auth gate): "${action.slice(0, 80)}" is a dangerous command and only scored ${n}/5 identity signals (need ${THRESHOLD}). Not proven to be V. See cloud/SECURITY.md.`);
process.exit(2);
