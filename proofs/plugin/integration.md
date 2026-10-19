# Bounded offline integration handoff — v2 proposal

Only local/synthetic evidence is claimed. Parent owns acceptance, integration and
closure. No commits/index actions or native files were modified in this milestone.
No installation/reload of a real plugin, live SDK content read, provider/Jev/ASR or
send/spawn, remote/tunnel/settings/account change or device action occurred.
Public evidence contains no private task/thread routes, user paths, credentials,
actual transcripts or titles. Existing task metadata retains ownership routing.

## Files and architecture

- `contracts/voice-terminal-v2.md`: current checkpoint/control-plane/computer-only
  routing proposal, native obligations and production gaps; schema and synthetic
  DTO examples next to it. Initial `v2-boundary-proposal.md` was sent to parent
  before implementation and shared with the native owner. Narrow native review
  confirmed no structural blocker; neither that nor this proof freezes protocol.
- `plugin/order.ts`: scope+epoch bound durable prefix checkpoint, exact-byte request
  reconciliation and prefix-wide barriers. Only the wire tail compacts; unresolved
  server facts/unknown/fence/release/attempt knowledge remain.
- `plugin/control.ts`: private operator RPC logic, one-use codes, token-hash
  redemption/repair/revocation/current-policy checks. `protocol-v2.ts`: strict DTOs,
  including Keychain readback transaction, checkpoint+covered sequence commit and
  staged explicit opt-in. No native Keychain or user interaction is claimed.
- `plugin/routing.ts`: SDK/stub Jev adapter, bounded original context/catalog choices,
  exact-target conflict path, persistent choice/evidence and one-attempt facts.
  No real mutation/ASR/job worker or network transport. Hold is not a ready state.
- `plugin/store.ts`: shared SDK-owned SQL/migration entry. The original five v1
  migration statement strings are retained unchanged; new tables append. No custom
  production filesystem storage. `server.ts` defaults to unavailable identity and
  operator authority and only registers explicit v2 HTTP paths/local RPC.
- `v1-fixture-server.ts`: isolated old handler registration for original v1 tests;
  no automatic compatibility/fallback in the current default server. Original v1
  schemas/examples and earlier Phase0 evidence are historical, not current wire.
- `integration.test.ts`, `integration-fixtures.ts`, `v2-restart-fixture.ts`: local
  deterministic SDK harness/SQLite fixtures and separate-process recovery.
  `generate-v2.ts`: machine schema/examples. No new dependency was added.

## Installed boundary and authority disposition

BB reports 0.46.0; exact SDK pin remains 0.6.37. Declarations and hashes are in
`sdk-boundary.md`; that initial evidence remains applicable. New relevant signatures:

- SDK L18483 `ExperimentalPluginRpcCaller` is `{kind:'plugin',pluginId:string}` or
  `{kind:'client'}`. L18490 handler context contains only `experimental_caller`.
  Comments explicitly classify app, CLI, agents and core as client.
- L22953 `bb.rpc.register(contract,handlers,options?)` uses local-auth RPC; L22996
  `PluginCliContext` contains optional cwd/threadId/projectId/signal, no operator
  identity/assertion. Testing API L1265 accepts an injected experimental_caller
  when driving real registered RPC handlers. Fixture caller is NOT host auth proof.
- L22240 string setting descriptor `secret?:true` stores secrets privately and never
  returns them to frontend; L22303 `settings.define` plus handle `get()` is used
  only with a synthetic SDK-harness secret in the injected router. Default router
  is absent and does not read a real setting/key.
- SDK read calls: `threads.get({threadId})`, `defaultExecutionOptions({threadId})`,
  `events.list({threadId,order:'desc',limit:'2',types:[...]})`,
  `message({threadId,seq,before:0,after:0})`, `system.executionOptions({providerId})`.
  Actual `ThreadEventRow` L4232 has id/threadId/seq/createdAt/type/data;
  ThreadMessageResponse L15215 has original conversation message with source seq,
  createdAt, threadId, text and role. Catalog/model defaults L10294/L4063 supply
  real execution fields; existing execution is retained, not changed by Jev.

Parent authorized inspection of current installed `server/dist/start-server.js`:
L193945 caller registry verifies a per-load plugin token, and no header becomes
client; invalid presented token rejects. L194825 RPC invokes localAuthProblem then
resolves that registry. L194211 delegates to browserRequestProblem. The latter
L177479–177495 checks Origin IF present and JSON for mutations at this layer;
it returns null otherwise. This is NOT positive operator/session authorization.
No actual upstream session/gateway proof was obtained, so no end-user/operator
identity is inferred. No private core source API is imported or invoked.

Production operator source and verified current-account adapter remain BLOCKED.
Smallest proposed bridge: an authorized BB UI/CLI operator workflow records explicit
intent; a reviewed trusted operator adapter calls the supported RPC with its host-
verified plugin identity and supplies current identity/scoped policy. It must prove
session/gateway/owner permissions at its own supported boundary, and deny watch
credentials/anonymous calls. No independent authentication infrastructure or body
role field was invented. Default authority returns null; default denies EVERY
privileged action. No auth:none issue/release endpoint exists.

## Commands and outcomes

Environment: Node v22.23.1, Darwin arm64, SDK0.6.37, better-sqlite3 12.10.0.
Content revision: `integration.sha256`; earlier `implementation.sha256` records the
previous accepted Phase0 source snapshot, not the changed current source.

| Check | Result |
|---|---|
| `node --experimental-strip-types plugin/generate-v2.ts` | PASS, strict v2 schema and synthetic DTOs generated/validated |
| `npm test --prefix plugin` | PASS, 22/22 including 8 original checks; raw output `integration-results.tap` |
| `npm run check --prefix plugin` | PASS, strict TypeScript noEmit |
| `bb plugin types --check plugin` | PASS, exact SDK0.6.37 pin matches host |
| `bb plugin build plugin` | PASS, backend bundle/map/SDK metadata; no install |
| `git diff --check -- plugin contracts proofs/plugin` | PASS, no whitespace errors/index mutation |
| `npm install --package-lock-only --ignore-scripts --offline --prefix plugin` | PASS, metadata synchronized, no new package; audit reports 0 vulnerabilities |
| Independent advisor_review | Exactly one pass completed; oversized-context mismatch fixed and regression verified below |

Relevant new behavior evidence:

1. Explicit v2 rejects v1 envelopes. Default authority denies all operator callers;
   fixture operator context accepts only its approved actor. Client/other plugin,
   no-key/wrong-device/wrong-token, absent verified identity and switched account
   deny. No anonymous provisioning/release HTTP route is registered.
2. Device-chosen synthetic token: concurrent same request yields same key/response;
   a DIFFERENT request cannot reuse that code before expiry. Exact persisted retry
   survives expiry, SDK reload and separate OS-process reopen; contradictory ID/hash
   conflicts, expired NEW requests fail, credential count remains one, raw token
   never appears in SQL. Pairing creates zero jobs and returns explicit-opt-in policy.
3. Failed code attempts and global budget persist even on denial; TTL, five repair
   wrong-device attempts and 20-new-attempt/minute cap exercise distinct guards.
   Current thread/project grant revocation fences new exact intake. Operator revoke
   disables keys. Same-device repair keeps connection+epoch and prior intake while
   rotating/revoking key; missing authority cannot grant continuity.
4. 130 sequential immutable Send intents, 129 complete later fixture receipts with
   only a short checkpoint reference each; early BB source is deliberately missing.
   Its unresolved barrier persists across EVERY later checkpoint/receipt and reload.
   Checkpoint needs intent facts, not earlier audio or job completion; no lifetime64
   cap. Later known independent exact U lanes bypass earlier exact T safely.
5. Forged/cross-scope/cross-epoch/changed-hash refs, gaps, different facts under same
   request ID and concurrent conflicting sequence allocation reject. Same exact
   checkpoint request returns original ack. Different raw bytes (even added newline)
   under that ID conflict. Injected checkpoint SQL failure rolls back ALL prefix
   facts/request receipt; no ack exists until retry succeeds.
6. Separate-process v2 fixture persists SQL + a synthetic client exact-file record,
   then reopens at code-expired time: original redemption/checkpoint replies return,
   no key remint or missing-source barrier release occurs, an intentionally unfinished
   transaction rolls back. This is local process-exit SQL proof with an SDK-shape
   file-backed DB fixture, NOT actual BB process restart, native Keychain/background
   transaction or power-loss proof. The client record is a simulation of the DTO
   obligation; native owner must wire/verify real atomic storage.
7. Computer-only context uses supported stubbed SDK reads and bounded original text.
   Concurrent/repeated routing persists ONE decision with current policy revision,
   confidence, context timestamps/sequences/text hashes and combined evidence hash.
   SDK source/provider/parse/freshness/ambiguity/confidence failures hold. Jev unknown
   thread/project/model cannot widen grants; new-thread policy holds. Exact target
   uses conflict assessment ONLY, never destination chooser. Policy changes during
   decision prevent route success; cached decisions and attempt reservation recheck
   current authorization.
8. Valid BB route-to-T removes the universal unknown-destination barrier so known U
   proceeds; T remains blocked by retained unknown core attempt after simulated
   accepted-source byte reclamation and reload. Non-operator release denies without
   changing that barrier. Explicit operator release clears ORDER only and preserves
   original attempt as reconcile-only. No SDK send/spawn calls occur.
9. Canonical checkpoint hash vectors were independently computed with Python hashlib
   and compact JSON arrays and asserted at the protocol boundary. Native has explicit
   ASCII-array seed/step encoding; no object-key serialization guess is required.

Fixture logs contain no source/key content and no real SDK/transport service was
called. The SDK's call recorder in routing fixtures contains ONLY synthetic data;
only test results/counts/hashes are public. Test authoring protects actual HTTP,
RPC/current-policy, transactional/lifecycle, ordering and untrusted-output boundaries;
no new test-only production bypass or duplicate source-text assertion was added.

## Open gates and next lead check

- **BLK-1/TG3 OPEN:** v2 checkpoint/native DTO/route adapter proposal needs lead
  acceptance and actual shared protocol integration. Server metadata growth/terminal
  compaction/quota policy is not solved by wire checkpoints; no silent fact eviction.
- **BLK-2/TG4 OPEN:** private operator authority/current identity assurances are injected
  fixtures; actual trusted operator workflow, release semantics and durable real-host
  evidence remain required. No supported authenticated-human API was assumed.
- **BLK-3/G1a/G1b and native G4 NOT RUN:** default production authority/admission closed;
  no install/provisioning/network/device action. Earlier remote procedure remains a
  staging checklist only and must be revised for reviewed v2 adapters before use.
- **Codec/TG13/ASR OPEN:** per-part source chronology retained, production decoded/
  playable/trim report still needs next schema revision and native codec evidence.
  No actual decoder/ASR call or decoded receipt was implemented.
- **Jev calibration/new creation/core mutation OPEN:** transport is injected stub;
  provisional 0.9/size/freshness budgets are hard fixture policy, not validated
  confidence or SLA. No complete ASR worker, catalog revalidation immediately at
  real dispatch, idempotent core acceptance/reconciliation or new-thread creation.
- **Pairing native/TG2/G6 OPEN:** Keychain successful readback, staged opt-in, background
  file transaction, original activity/peek freshness, capacity and hardware remain
  native/lead evidence. Schema flags and synthetic client files cannot prove them.

Next lead check: review v2 schema/examples + canonical hash/native transaction
requirements and operator/current-identity adapter plan; consolidate native codec
feedback before any production decoded receipt/schema adoption. Approve another
explicit bounded handoff only after that review. This session stops at this
milestone; no bead closure, deployment or whole-plugin readiness claim.

## Advisor disposition

One review after implementation/checks identified a concrete contract mismatch:
the router sliced long original messages/titles even though v2 requires oversized
context to hold. Corrected at the SDK context boundary: reject title >128 or message
>1024 before constructing the candidate or invoking Jev; preserve a `context-limit`
hold, no attempt reservation. Added a fixture with a trailing correction beyond
the old truncation boundary plus an oversized title. It proves zero Jev calls,
no core attempt and durable hold. Reverification: 22/22 tests, strict TypeScript,
SDK pin check, backend build and scoped whitespace checks PASS. No second review
loop was run, as requested. All production blockers remain open.
