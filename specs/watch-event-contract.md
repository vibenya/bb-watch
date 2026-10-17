# BB Watch event bridge contract

Design proposal, 2026-10-17. This document specifies a headless BB plugin and a
native watch adapter. No plugin, event delivery, push service or new delivery
guarantee is implemented by this document. Existing HTTP compatibility remains
necessary until the vertical slice below passes its acceptance checks.

## Verified building blocks

Inspected installed BB server bundle `bb-app/server/dist/start-server.js` and
its authoring references. These are version-sensitive source observations, not
stable public API guarantees; recheck against installed SDK declarations before
implementation.

| Source anchor | Observation |
| --- | --- |
| `emitThreadEvents` (208490), `emitThreadActive/Idle/Failed` (208511–208530) | Plugins receive current thread DTOs. `experimental_thread.events` includes the latest thread sequence, not event bodies; idle includes `lastAssistantText`. |
| `pendingThreadEvents` (40968–40974) | Event-appended notifications are coalesced. The SDK reference describes one-second updates. Listeners alone are not a durable replay queue. |
| `eventsListQuery` (192808), `timelineQuery` (192830) | Event reads have `afterSeq`, `beforeSeq`, limit and order. Timeline supports `afterSequence` and content-loading options. These are different cursors; do not interchange them. |
| `http.experimental_websocket` (204467), `registerPluginRoutes` (194350) | Plugin HTTP and WebSocket handlers exist under `/api/v1/plugins/<id>/http/<path>`. HTTP route paths are exact matches. Reload can invalidate sockets. |
| `localAuthProblem`, `tokenAuthProblem` (194211–194235) | Plugin route auth is distinct from a claim of watch pairing compatibility. Token mode checks a plugin token; local mode uses browser request checks. Neither proves scoped per-watch authorization. |
| Hermes bridge `server.ts`, `bb.events.on("thread.idle")` and `thread.failed` handlers | A bridge can forward completion/failure from BB lifecycle hooks. Its outbound envelope slices body to 3,500 characters; it does not supply the watch's live activity or full-text synchronization contract. |

The Hermes bridge is a useful lifecycle example, not a protocol to copy. It
filters notifications by presence/settings; the watch must synchronize its
selected thread even while BB is open. No personal notification enrichment is
needed. See [shared Chats contract](chats-watch-integration.md) for canonical
visibility, family, pin and child-thread behavior.

## Ownership and authentication

BB remains authoritative for thread state, messages, questions and delivery
acceptance. The plugin projects that state, maintains a bounded replay journal
and exposes a narrow transport. The watch owns recording, durable drafts,
recipient choice, rendering and playback. Neither side implements a terminal.

A connection identity includes server installation, authenticated principal and
paired device. Bind stored cursors, drafts and mutation IDs to that identity;
a changed identity cannot resume or send the former identity's work. Preserve
exact recipient child IDs independently of family grouping.

Before exposing a route, verify the existing mobile credential against the
actual host authentication path, including WebSocket upgrade and revocation.
If the installed SDK cannot provide this identity, add a supported authenticated
adapter or a scoped device pairing mechanism first. A plugin-wide token is not
a substitute for per-device authorization. Never put credentials in URLs. Scope
snapshot/replay/subscriptions to authorized threads and purge revoked server
subscriptions. This is an implementation gate, not an established capability.

## Version 1 wire proposal

The following paths and fields are proposed, not existing BB endpoints. Use
exact plugin-relative paths, query/body IDs, runtime schemas and a versioned
capability handshake. Reject unsupported protocol versions explicitly.

| Route | Purpose |
| --- | --- |
| `GET /snapshot?threadId=…` | Coherent selected-thread projection plus replay cursor; list bootstrap remains separate. |
| WebSocket `/events` | Client sends `{version:1, threadId, cursor}` after authentication; server sends projection updates, heartbeats or `resetRequired`. |
| `POST /submissions` | Persist an explicitly authorized text/recording submission intent; return stable operation receipt. |
| `GET /submission?operationId=…` | Reconcile receipt without replaying the mutation. |

Each projection has `version`, `serverEpoch`, `cursor`, `threadId`,
`projectionRevision`, `sourceSequence`, `observedAt`, `status`, `activity`,
`latestReply` and `interactions`. A reply has a stable message ID, revision,
`turnId` when known, complete original text and completion state. Missing text
is explicitly `loading` or `unavailable`, never silently an empty final reply.
Large originals use a version-bound paginated content resource; the visible
completion watermark cannot imply that missing pages are locally available.
Summaries, if later added, are separate derived objects referencing the original
revision. Activity is a bounded display label derived from current provider
items, not arbitrary tool arguments, transcripts or sensitive paths.

Serialize projection construction per thread. Read source sequence and relevant
status/question revisions before and after assembling status/timeline/interactions
and retry changed snapshots with a bounded budget. Sequence alone does not cover
every lifecycle or question change. A transactional core snapshot or a verified
consistent-read boundary is required before claiming atomic source coherence;
separate HTTP reads in the current native client do not provide it. If a stable view cannot be produced, retain the previous
projection and report syncing; never splice unrelated revisions together. A
terminal status must carry the corresponding final reply or an explicit pending
content state. Question-load failure is an independent availability field; it
does not erase messages. Thread selection uses a generation token so a delayed
response cannot overwrite the newly selected thread.

Transport freshness is separate from agent status. Until a snapshot is loaded,
show `Syncing`; after disconnect retain cached content with stale indication.
`Ready` requires a current idle snapshot with no reply; `Done` requires the
complete latest reply for that snapshot. Receipt of a submission alone is not
proof that the agent is working. Activity may change while status stays active.

## Replay, startup and bounded resources

Register source listeners before startup reconciliation. Reconcile tracked
threads from BB, then publish serialized projections; live events overlapping
that reconciliation must not lower a revision. Core lifecycle callbacks are
hints to read canonical state, not the durable journal itself.

Persist projection and journal entry atomically before sending. A journal
cursor is an opaque plugin epoch plus increasing offset, distinct from BB's
per-thread source sequence. Snapshot capture and replay handoff must share a
watermark so changes during connection cannot fall between them. The watch
atomically persists projection plus cursor and deduplicates repeated entries.
Acknowledge only after persistence; an acknowledgment means cached, not rendered.

Retain a bounded journal (initial proposal: 24 hours and 10,000 entries, whichever
limit arrives first). An expired cursor, changed epoch or missing upstream
history returns `resetRequired`; fetch a fresh snapshot and replace its cursor.
Never pretend gaps were replayed. On plugin restart reconcile before declaring
freshness. Throttle/coalesce superseded activity updates; preserve final replies,
question changes and operation receipts in canonical state even after journal
pruning. Bound socket buffers; disconnect a slow consumer with a recoverable
reason rather than grow memory. Dispose listeners/sockets on unload.

## Mutation receipts and ambiguity

Persist `operationId`, connection identity, exact destination, payload digest
and phase before any core mutation. Reusing an ID with a different destination
or payload fails. Repeated identical requests return the same receipt. Phases
are `stored`, `preparing`, `dispatching`, `accepted`, `failedBeforeAcceptance`
and `acceptanceUnknown`. Accepted receipts include canonical thread/message or
request IDs only when BB confirms them; do not fabricate missing IDs.

A plugin ledger alone does not make core dispatch exactly once: the process
can die after BB accepts but before the ledger records the receipt. The installed
bundle contains `clientRequestId` machinery, but end-to-end deduplication and
lookup for every required create/send/interaction path remain unverified.
Before automatic retry, prove core idempotency and reconciliation through a
fault-injection contract test. Otherwise mark the ambiguous operation
`acceptanceUnknown`, reconcile by canonical request ID if available, and do not
repeat dispatch automatically. Preserve the local audio and recipient order.

Upload/transcription must not share the selected-thread refresh lane. Track
upload, transcription and dispatch separately; only a fully assembled ordered
transcript is eligible for dispatch. New-thread creation needs its own durable
receipt and ambiguity handling before message delivery. Interaction commit must
recheck canonical question revision and use atomic conflict detection; a voice
clarification is not a fabricated option selection. Preserve the ten-second
local cancel deadline across restart.

## Foreground and background

Use the event connection while the app is active; reconnect with the saved
cursor on activation and reconcile the selected thread immediately. Keep a
bounded HTTP fallback for a host without the plugin. Display which data is
stale without making recording depend on connectivity.

Do not promise an always-running watchOS socket or a refresh deadline while
suspended. Background notification delivery is a separate APNs capability with
pairing, entitlement and physical-device verification still required. A push is
a wake/open hint, never the authoritative message; fetch the original on resume.
No notification payload contains full private conversation text by default.

## Implementation phases and acceptance targets

All numbers below are proposed targets, not measured results. Record network,
foreground/suspended intervals, server version and sample count with results.

1. Verify auth/capabilities and implement a read-only plugin slice with one
   selected thread. Replay/snapshot fixtures cover reconnect, duplicate event,
   cursor expiry, reload, final-before-text race, long text and thread switching.
   Authenticate/revoke both HTTP and upgrade paths before any external exposure.
2. Integrate native foreground projection/cache. On a reachable host, target
   p95 ≤3 s from BB event commit to visible activity/final reply in 30 transitions
   on Wi-Fi and separately LTE. Reopen target p95 ≤3 s to a fresh snapshot after
   network availability, over 30 trials; report suspended time separately.
   Require zero stale-thread overwrites and exact original reply text across
   repeated reconnects, including originals over 3,500 characters.
3. Implement durable submission receipts and fault-inject every boundary around
   core acceptance. Require zero silent loss and no automatic replay after
   ambiguity. Exactly-once delivery remains unavailable until core evidence
   proves it. Measure upload/transcription/dispatch separately; choose a latency
   budget from representative recordings rather than inventing one.
4. Implement and measure background notification behavior on physical standalone
   LTE hardware. No bounded background delivery claim before that evidence.

Use random correlation IDs and monotonic stage durations for diagnostics;
record server observation, device receipt, cache commit and UI application as
separate milestones. Compare wall clocks only with measured offset/uncertainty.
Log event kinds, byte counts and durations, never message/audio content, tokens,
private URLs or raw device identifiers. Deterministic fixture verification does
not authorize sending live prompts. Source inspection and this contract complete
the design step only; plugin implementation and hardware acceptance remain open.
