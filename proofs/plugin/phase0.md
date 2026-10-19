# Plugin Phase 0 handoff — 19 October 2026

Owner: plugin implementation lane; integration and gate acceptance remain with
the lead. The worker handed off without commits or index changes. Work tracking
and private session routes are recorded outside this public report.
Only `plugin/`, `contracts/` and `proofs/plugin/` changed. Native/watch files untouched.
This is a bounded local implementation milestone, NOT protocol freeze or BLK closure.
Content revision is recorded in `implementation.sha256` (uncommitted source digests).

## Delivered

- `contracts/voice-terminal-v1.schema.json`, strict named JSON Schema definitions,
  `voice-terminal-v1.examples.json`, synthetic examples, and `README.md` semantics.
  Pairing/scope, immutable source+encoded parts/incompleteness, order/predecessors,
  declare/part/seal/status, complete receipt, fence/nonacceptance/unknown, activity
  freshness and internal dispatch ambiguity facts are proposals. Version 1 is a
  DRAFT; incompatible production codec/order changes require a reviewed revision.
- `plugin/server.ts`, narrow HTTP handlers; `intake.ts`, supported SQLite intake
  with immutable manifest checks, BLOB parts, one atomic job+fixture receipt,
  persistent acknowledged fences and conservative read-only barrier calculation.
  No job worker/core dispatch. `fixture-bytes-v1` only; actual AAC seal rejected.
- `plugin/protocol.ts`, runtime validators/schema source, generation commands,
  Node tests and synthetic fixture data; pinned SDK/dev tools and lockfile.
- `sdk-boundary.md`, exact installed declarations/versions and honest Jev gap;
  `remote-admission.md`, staged lead-owned remote procedure, NOT RUN.

Astra disposition via parent: per-part sample format/endian/interleaving/rate/channel
layout resolves the narrow original-source hash and route-change ambiguity. This
is NOT protocol acceptance. Source format and encoded representation remain
separate; per-part sourceFrameCounts are never cross-rate duration or decoded
fidelity evidence. Playable/trim report and conversion recovery remain a codec
schema revision and hardware/quality proof before production acceptance.

## Commands and results

Environment: BB 0.46.0, SDK 0.6.37, Node v22.23.1, Darwin arm64,
better-sqlite3 12.10.0. Current source digests are the reproducible revision.

| Command/check | Actual result |
|---|---|
| `bb --version` | PASS: 0.46.0 |
| `bb plugin types plugin`; `bb plugin types --check plugin` | PASS: exact SDK pin 0.6.37 matches host |
| `npm install` (SDK + local harness peers/tools, no BB plugin install) | PASS; lockfile pinned. Only Zod runtime dependency; official SDK needs SQL/Hono/cron test peers. Hono test peer updated to patched 4.13.13 after audit flagged 4.11.9. Does not change installed BB host. |
| `npm test --prefix plugin` | PASS: 8 tests, 0 failures; raw output `test-results.tap` |
| `npm run check --prefix plugin` | PASS: strict TypeScript noEmit |
| `npm run schema --prefix plugin`; `node --experimental-strip-types plugin/generate-examples.ts` | PASS: JSON outputs generated and examples validated by runtime schemas |
| `bb plugin build plugin` | PASS: local backend bundle+map+SDK metadata emitted to ignored `plugin/dist/`; no install/reload |
| `git diff --check -- plugin contracts proofs/plugin` | PASS: no whitespace errors; no Git index mutation |
| `npm audit --prefix plugin --omit=dev` | PASS: 0 vulnerabilities in runtime dependency set |
| independent `advisor_review` | PASS: exactly one review after implementation/checks; no actionable defect in bounded Phase 0; production gates remain open |

The seven behavior tests plus one public-API scanner cover:

1. Missing/wrong token, wrong device, revoked credential, other connection/account
   status isolation and cross-scope declaration denial. Every denial occurs in
   handler auth, not fake host auth. No receipt or job leaks.
2. Out-of-order and duplicate parts, invalid bytes, missing-parts seal, concurrent
   duplicate seal, deliberately discarded/lost receipt reconciliation, one stable
   receipt/job and bytes after SDK host reload; abandon-after-seal returns receipt.
3. Acknowledged abandon before declaration, reload, late declare/part/seal stays
   fenced; exact unavailable target rejection persists fence with no job; unknown
   identity is explicitly NOT definitive nonacceptance.
4. Immutable exact intent, conflicting sequence reuse, missing predecessors,
   malformed source layout and forbidden extra watch context cannot alter intake;
   real AAC candidate cannot receive a fixture complete receipt.
5. Never-received earlier BB intent blocks a later exact T even after its receipt;
   acknowledged fence releases it; known independent exact U proceeds; same T
   remains blocked by an accepted-audio or simulated core-unknown predecessor.
   No actual route resolution or core submission is claimed.
6. Separate OS processes write then reopen real WAL SQLite: committed source,
   receipt and fence survive, a deliberately uncommitted ghost job rolls back,
   original seal returns original receipt. Child uses official fake HTTP host plus
   a file-backed fixture replacement for `storage.database()`; production source
   uses only `bb.storage`, never a host filesystem path. This proves local SQL
   process-exit/reopen behavior, not actual BB restart, host power loss or watch.
7. Injected SQL write failure at job insertion yields 503 with NO receipt/job;
   source and identity remain and same-ID seal succeeds after fault removal.
8. SDK public-import scanner finds no private dependency/import violations.

Test authoring gate: these own intake HTTP/auth/transaction/lifecycle/order
boundaries, not copies of private predicates. Credible regressions are duplicate
job creation, scope leakage, lost bytes/receipt, late-seal resurrection, missing
barriers or false acceptance after failed persistence. No test-only runtime export
or bypass was added. Fixture provisioning inserts synthetic credential hashes in
test DB only; it is not a hidden production pairing API. Logs remain empty in
checked fixture flows; SDK call recorder stays empty (no content/provider access).

## Limits / blockers / next boundary

| Boundary | Status | Required next evidence/action |
|---|---|---|
| BLK-1 / TG3 | OPEN; local fixture subproof passed | Lead accepts protocol; explicit bounded computer-side route adapter, durable decision and production unresolved-order behavior. Full predecessor history currently fixture-capped at 64; checkpoint/compaction must preserve released/source-reclaimed facts without truncation or a product 64-send cap. |
| BLK-2 / TG4 | OPEN; local fence/nonacceptance subproof passed | Production pairing grants/current target authorization and a BB-side authenticated release action for never-received/unknown work; demonstrate real host durable acknowledgements/races. No release endpoint implemented. |
| BLK-3 / G1a/G1b | NOT RUN, remote admission unknown | Lead concrete isolated install/provisioning/network handoff and actual native remote denial+complete chain proof. SDK auth:none is not outer gate evidence. |
| Core idempotency/reconciliation | UNVERIFIED / NOT RUN | No SDK operation-id dedupe/reconcile contract established. Future worker records attempt before one send/spawn; ambiguous crash/response remains unknown, no automatic replay/new ID. Current code makes no mutations to BB core. |
| Jev route/model adapter | Missing BB adapter; existing model classifier signature verified | Computer-only authorized bounded recent SDK context, secure secret setting, calibrated candidate/confidence/execution policy and persisted choice. No key/config/provider calls. |
| Pairing / rotate / repair / revoke | Schema/policy proposal only | One-use expiring setup, scoped credential issuance and secure provisioning; same-identity continuity, current account isolation, revocation/rate-limit proof. Fixture tests only existing grants/revoked denial. |
| Codec / TG13 | NOT RUN | Per-part originals and incompleteness preserved locally, but real decode/playable trim/priming/padding report needs reviewed schema revision and bilingual quality evidence. No ASR/live audio used. |
| TG2 activity/peek | Schema only / NOT RUN | Authorized original SDK excerpt/status mapping, monotonic revision semantics, clock skew and freshness budgets. Never derive activity from transfer/ASR. |
| G4, G6, device/background | NOT RUN here | Native/lead own physical transport and storage/freshness/quotas measurements. Fixture limits are not product duration/quota decisions. |

Next action: parent reviews bounded protocol/SQLite milestone, consolidates Astra
feedback and defines explicit next handoff; Sol stops here. Next check: preserve
open BLK-1..3 and production codec/order/auth gates; review protocol revision and
admission/provisioning design before installation or live calls. Do not close the
bead, ship the whole plugin or spend time on unavailable hardware in this thread.

No install/reload of a real plugin, network/tunnel/account/settings mutation,
credential read, user content read/log, live prompt, agent spawn/send, Jev/ASR call,
device action, migration, publication or deployment occurred.

Advisor disposition: “No actionable defect found in the bounded Phase 0 implementation; production gates remain explicitly open.” No code changes required after review.
