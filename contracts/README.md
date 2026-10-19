# Voice terminal protocol v1 — Phase 0 PROPOSAL

Owner: Sol. Lead acceptance pending; Astra validated only the source-layout clarification. This does not close BLK-1,
BLK-2, BLK-3, TG3, TG4, TG13 or remote admission. Product/design 3.0 remain authoritative.
`voice-terminal-v1.schema.json` defines named `$defs`; select the appropriate
`#/$defs/manifest`, `request`, `partHeaders`, `response`, `pairing` or
`threadSnapshot` or `dispatchFact` when validating. Generated from `plugin/protocol.ts` using
`node --experimental-strip-types plugin/generate-contract.ts`. No notification
payload, history, transcript, execution or model fields are accepted from watch.

## Immutable identity and intake

One connection permanently identifies BB instance/account/watch; credential rotation
changes keyId, never connection/operation/order identity. Re-pairing without
verified continuity creates a new connection and freezes old work. A setup code
is short-lived, one-use, computer-issued; redeem retry must reconcile requestId
without reminting scope. Pairing alone never sends staged audio. Token material is
returned only on private authenticated setup, stored in watch Keychain and supported
plugin private secret configuration, never URLs/logs. Revoke denies further intake
and reads immediately; retained accepted work is a separate BB-side decision.
Rotation/repair/revocation exchanges are proposals only, NOT implemented routes.
Production authorization must bind authorized thread/project grants to the connection;
plugin's workspace-wide SDK access is not per-watch authorization.

Proposed endpoints below the SDK `/api/v1/plugins/voice-terminal/http/` prefix:

- POST `v1/intake`: strict JSON `request` (declare, seal, status, abandon).
- PUT `v1/part`: raw file-backed bytes; headers `x-vt-operation-id`,
  `x-vt-manifest-sha256`, `x-vt-part-index`. No base64/file path on wire.
- Both: `authorization: Bearer <per-watch token>`, `x-vt-key-id`,
  `x-vt-device-id`. TLS required beyond loopback. No plugin-wide token,
  master/session token, cookies or query credentials as fallback.

`declare` carries the exact frozen UTF-8 JSON manifest text as `manifestUtf8` plus
SHA-256 of those UTF-8 bytes. Keep/resend those exact bytes; JSON key-order changes
are conflicts. Parse and validate manifest separately. Hashes are lowercase hex;
IDs are opaque ASCII strings, integers <= 2^53-1. Unknown fields/versions reject.
Scope, operationId, intent, ordered audio parts, interruptions and order freeze
at Send. Part indices contiguous from zero; part hashes describe uploaded encoded
bytes, per-part source format/bytes/sha256/frames describe retained originals, NOT a promise that
lossy decoded audio is bit-identical. Segment IDs preserve intentional append
boundaries; stopped time adds no silence. `afterPartIndex=-1` marks missing audio
before the first part; other marks refer to actual part boundaries and are never
erased. Each part's `source` describes the exact retained PCM byte layout: sampleFormat
(float32 or int16, little endian), interleaved flag, rate, channel count, frame
count, byte count and SHA-256. Noninterleaved bytes mean channel-major planes,
each containing exactly frames samples; interleaved means frame-major samples.
Native must export precisely that layout before freezing, preserving its native
originals/mapping if a container or different layout was captured. No implicit
resampling, remixing or sample-rate assumption. Format may change between parts;
a format change must split a part, preserving chronology by index and segmentId.
Intentional Stop/REC starts a new segmentId with no gap/silence inserted; an
incompleteness mark survives any append, including differing formats. Source
bytes = frames × channels × sample width. `fixture-u8` is synthetic, never PCM.
`encoded` separately identifies uploaded representation, bytes and hash; an AAC
container owns its encoded rate/channels. Decode must yield an independently
validated playable timeline per part and mapping to original frames; source
frame counts alone cannot prove decoded duration or priming/padding correctness.
No decoded frame count/hash is invented in the frozen manifest. A production
`decoded-audio-v1` receipt's per-part playable/trim report remains a codec gate and
will require a schema revision BEFORE adoption. Conversion failure retains all
originals and never emits a production receipt. Full codec priming/padding/trim
semantics await compression proof.

Same scope+operationId and same manifest bytes reuse one intake. Different bytes,
sequence reuse or contradictory predecessor descriptions conflict without changing
the first identity. `part` verifies size/hash and reuses identical bytes; seal
requires all parts and one atomic persisted complete job+receipt. An unsupported
codec or missing part does not claim nonacceptance. Fixture profile only validates
synthetic bytes; real decoded audio is NOT accepted by this Phase 0 implementation.
A receipt has scope+operationId+manifest hash, stable receipt/job IDs, total bytes,
per-part source frame counts, part count, timestamp and validationProfile. Watch cleanup requires
`decoded-audio-v1` from an admitted production endpoint with locally matching
manifest/totals/identity; `fixture-bytes-v1` NEVER authorizes cleanup of real audio.
Complete receipt says nothing about ASR/routing/dispatch. All facts and bytes remain
in plugin SQLite; no expiry/reclamation is implemented.

## Order, fences and ambiguity

Sequence is monotonic per connection from 1. Each manifest includes every older
operation's immutable `{operationId, sequence, intent}` in `order.predecessors`,
including never-received operations. Receiver validates complete coverage of
1..sequence-1 and consistency against its ledger. This permits safe independent
exact T/U lanes while a missing earlier BB intent blocks every possible lane.
An accepted complete-audio receipt does NOT release same-recipient order: only
confirmed core submission or an explicit safe release does. Unresolved route or
ambiguous core acceptance keeps the barrier. Across separate connections no total
Send order is promised; production cross-device ordering policy remains open.

Phase 0 is bounded to 64 Send positions, 64 parts, 64KiB manifest text, 1MiB per
part and 8MiB per operation. These are fixture resource bounds, NOT G6 release
budgets. No arbitrary cap may be shipped as product duration policy. A compact
checkpoint for longer predecessor ledgers and measured quotas is a lead boundary
before production; never truncate predecessor lists to make a later send proceed.

`abandon` includes original manifest text/hash so it can fence a never-declared
identity and register predecessors atomically. Acknowledged fenced response is
persisted before reply; all later declare/part/seal for that identity stay fenced.
If seal already committed, abandon returns the original receipt, NOT cancellation.
A definitive target-unavailable rejection is generated only with a durable fence
and no job. Invalid requests, 401/404/409/500, network failure and absent status are
NOT definitive nonacceptance. Unknown identity returns `unknown` with
`definitiveNonacceptance:false`. Timeout/lost response: query same ID, retry same
immutable intake only; never invent a new ID for possibly sealed/accepted work.
Local deletion cannot release the ledger. A new BB-intent replacement requires
old definitive nonacceptance and an explicit user Send (atomic enqueue on watch).

BB-side release is a separate authenticated human recovery action that persists
a release record. No watch release route exists; no fixture release endpoint is
implemented. Production needs that action before TG4 closes. Sending to BB core
must persist one attempt before invoking SDK; crashes/ambiguous outcomes become
`unknown`, never automatically call send/spawn again. `pluginSubmission` metadata
is attribution, not a verified core idempotency key. No dispatch occurs here.

## Thread activity and Jev

`threadSnapshot` is a proposal for authorized title/excerpt/activity with immutable
scope/threadId, revision, observedAtMs and validUntilMs. It is not implemented.
Reject cross-scope responses and older revisions (revision ordering must be
specified by adapter); stale/unknown/source-unavailable renders neutral. Clock
skew/freshness windows and how to distinguish question/done from idle await TG2.
Only original bounded BB excerpt, never a summary, upload/ASR or receipt state.
Recent routing context stays computer-side, not in watch requests or diagnostics.

Existing Jev service is a model classifier prototype, not a BB route adapter.
Minimal proposed computer-side adapter (not an HTTP endpoint):
`decide({scope, operationId, transcript, frozenIntent, candidates, executionCatalog})`
→ `{kind:'existing',threadId,execution,confidence,evidenceRevision}` or
`{kind:'new',projectId,execution,confidence,evidenceRevision}` or
`{kind:'hold',reason}`. Candidate set contains only authorized bounded recent
SDK threads/original messages plus context timestamps; policy bounds and confidence
thresholds are configured/validated before live use, not borrowed from model
classification. Exact manual intent bypasses destination classification; spoken
conflict holds. Validate chosen IDs against the same authorization/catalog and
persist one decision before dispatch. New-thread creation/reconciliation and
existing-thread model policy remain explicit gaps. Jev never inherently knows BB
history. Use supported secret settings; do not reuse prototype fallback .env reads.
