# Voice terminal bounded offline integration

Proposal only; not installed, remotely admitted, production-ready or codec validated.
Default server registers explicit v2 paths with unavailable identity/operator adapters,
so all privileged actions and pairing/current-account access fail closed. The old
v1 HTTP implementation is isolated as `v1-fixture-server.ts` for its original tests.
There is no ASR/job worker, live Jev transport, core send/spawn, native wiring or
production source cleanup. No operator provisioning/release auth:none HTTP routes.

From the repository root:

```sh
npm ci --prefix plugin
npm test --prefix plugin
npm run check --prefix plugin
node --experimental-strip-types plugin/generate-v2.ts
bb plugin types --check plugin
bb plugin build plugin
```

Requires Node 22 TypeScript stripping. SDK0.6.37 remains pinned. Only Zod is a
runtime dependency; SQL/Hono/cron are the official local test-harness peers. Production
source uses SDK-owned SQLite and supported private settings; fixture restart helpers
use disposable file-backed SQL to prove process persistence. No new dependency
was added for the integration milestone.

See `contracts/voice-terminal-v2.md` for checkpoint/pairing/native DTO obligations,
current-policy/operator trust gaps and computer-only routing. Evidence and gates:
`proofs/plugin/integration.md`. Never install/reload or perform live calls from here.
