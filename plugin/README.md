# Voice terminal Phase 0

Offline fixture proof only; not installed, admitted, production-ready or codec
validated. Starts with no credentials; every request denies until an explicit
future provisioning handoff. No pairing endpoint, background worker, ASR, routing,
core dispatch, thread read/activity API or cleanup is implemented.

From `plugin/`:

```sh
npm ci
npm test
npm run check
npm run schema
node --experimental-strip-types generate-examples.ts
bb plugin types --check .
bb plugin build .
```

Requires Node 22 with TypeScript stripping. Runtime source uses Zod and SDK-owned
SQLite. SDK 0.6.37 is pinned. better-sqlite3, hono and cron-parser are local
SDK test-harness peers only; no frontend or new server runtime. Hono 4.13.13 is a
patched test dependency; this does not claim the installed BB host uses that
version. No dependency or source from another watch implementation was used.

`contracts/README.md` is the proposal; `proofs/plugin/phase0.md` is the evidence
and handoff. Never install/reload or run live calls from the commands here.
