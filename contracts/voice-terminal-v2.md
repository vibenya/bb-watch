# Voice terminal v2 — bounded offline integration PROPOSAL

No production freeze or gate closure. This is incompatible with v1. Current default
server registers only `/v2/` intake paths; the old v1 server is a named fixture
module, never a fallback. v1 JSON examples remain historical. Generate v2 named
JSON Schema definitions and synthetic DTO examples with:

```sh
node --experimental-strip-types plugin/generate-v2.ts
```

Select the relevant `#/$defs/...` in `voice-terminal-v2.schema.json`. Watch input
accepts frozen audio/BB-or-exact intent only. No history, notification payload,
transcript, model, permission or caller-role field is accepted from the watch.
Source/encoded part semantics and the OPEN codec/playable/trim revision from v1
remain unchanged. All complete receipts here are `fixture-bytes-v1`; real AAC is
rejected. `decoded-audio-v1` is a reserved proposal, not an implemented codec path.

## Order checkpoint and native transaction contract

Each connection has one immutable random `orderEpoch`. Sequence is a safe positive
integer, allocated atomically with the watch's immutable Send enqueue. Key rotation
or same-device authorized repair retains connection+epoch. A new connection has a
new epoch and never imports/rebinds old possibly accepted work. No total Send order
is promised across unrelated connections/devices.

POST `/v2/checkpoint` under the plugin HTTP prefix receives `checkpointRequest`:
original requestId, epoch, prior checkpoint or null, 1–64 consecutive immutable
intent facts. A fact is `{sequence,operationId,intent}`; no audio arrival, completed
job or route decision is required. The server validates full scope from the
credential/current authority, epoch, prior persisted opaque checkpoint, no gaps,
no reused sequence/operation with contradictory identity/intent. The server stores
facts, a prefix chain hash, opaque checkpoint ID and exact-request-bytes hash in
one synchronous SQLite transaction BEFORE replying. Checkpoint IDs are opaque
lookup references, not bearer authorization or self-signed permission.

Hash encoding is explicit and language-independent: UTF-8 compact JSON arrays,
no whitespace; IDs/kinds/hashes are restricted ASCII, integers are base-10 safe
integers without exponent/fraction. Seed is SHA-256 of
`[2,instanceId,accountId,connectionId,deviceId,epoch]`. Each fact extends with
SHA-256 of `[previousHash,sequence,operationId,kind,threadIdOrNull]`; BB uses null.
No object-key order, Foundation JSONEncoder default or general canonical JSON is
assumed. Independent Python reference vectors for fixture identity/epoch:
seed `24399099af51db916d35cf7af05ccbb03f86ccfb32644316abdfbff2395941f5`;
first missing-bb fact `34b713fb8329bb2eb561eb55a4a879c268f036552e44eb7f4a55a71bdb69675f`.
These are covered by the protocol test and generated synthetic examples.

Forged,
other-scope, other-epoch or altered references fail closed.

A v2 manifest carries `order:{epoch,sequence,checkpoint,predecessors}`. The list
contains only consecutive facts uncovered by that checkpoint and is bounded to
64 per manifest/request. Sequence must equal checkpoint.throughSequence + tail
length + 1. More pending history is acknowledged in multiple bounded checkpoint
requests, without uploading old audio. There is NO 64-lifetime-Send bound. A
checkpoint extension from an older prefix is permitted when its full tail fits;
identical overlapping facts reconcile, contradictory facts conflict. Old frozen
manifests remain retryable under their original exact identity/hash/checkpoint;
never rewrite an already frozen Send to exploit a newer checkpoint.

Native requirements (proposal reviewed for feasibility, not wired/proven here):

1. Persist exact request bytes in a protected file and original requestId before
   creating a background task. Lost reply/task/relaunch retries that exact file,
   not reconstructed/rekeyed data. Same request ID with different bytes conflicts.
2. Validate response scope/epoch, original requestId, covered sequence and chain
   hash against local consecutive facts. Atomically persist checkpoint AND covered
   sequence BEFORE reducing references in subsequently enqueued manifests. The
   local `checkpointCommit` DTO describes that commit. A late/unrelated response
   cannot advance coverage. Crash before commit retains old checkpoint + full tail;
   crash after commit restores the same checkpoint/coverage.
3. Keep complete local operation, unknown, receipt and order ledgers. Watch
   unsynced/unreceived audio stays retained. A checkpoint acknowledges intent facts
   only: it releases NO order barrier and authorizes NO audio cleanup.
4. Concurrent Enter operations serialize local sequence allocation/outbox enqueue.
   Server unique sequence/op constraints reject conflicting concurrent histories;
   it never guesses order from upload arrival. A successor may arrive/upload/seal
   before a missing predecessor because its intent is retained in the prefix.

Server barrier calculation reads ALL earlier durable facts (including checkpointed
ones), never just a manifest's short tail. An unresolved BB predecessor blocks all
possible same-connection targets. A persisted validated route to T lets known U
progress while T still waits for source/core acceptance. Audio receipt alone does
not clear T. Fences, explicit operator order release, or confirmed core submission
are distinct durable facts. Unknown/attempting core submission remains a barrier
and cannot be replayed. Part/source reclamation never deletes prefix/decision/
fence/receipt/release/attempt metadata. Only fixture SQL deletion of already
accepted source was exercised; no production retention/cleanup service exists.

This proposal compacts the WATCH wire tail, not all server history. Server metadata
still grows with immutable facts/dedupe tombstones; unresolved knowledge is not
silently evicted. Measured G6 capacity, safe terminal-range metadata compaction and
operator recovery under finite storage are still production work. SQLite-full or
checkpoint failure yields no ack and no coverage advance; local audio/ledgers
remain and new recording obeys real local storage limits. Pressure is a retriable
resource condition, not an arbitrary product duration/lifetime-Send cap.

## Pairing, identity, policy and operator ownership

An injected `Authority` supplies current verified instance/account identity +
revision, current scoped thread/project policy and concrete operator authorization.
It is an internal trusted adapter, never a body role. Default implementation returns
no authority and all privileged actions/current-identity access fail closed.
No setup code, identity or grant is inferred from fixture strings in that default.

The SDK RPC caller distinguishes host-verified plugin identity from `client`.
`client` includes app, CLI, agents and core; it is NOT an authenticated operator
assertion. Actual local Origin/JSON middleware also does not attest operator intent.
A supported authenticated BB operator UI/CLI workflow plus a trusted gateway to
this adapter may be sufficient; no human-attestation API is invented. The actual
session/gateway ownership source remains unverified and must be supplied/reviewed
before production. No independent password/login/token authority was added.

Only local-auth SDK RPC `v2.operator` handles issue-code, revoke and release-order,
and every handler ALSO calls the injected operator authority. No auth:none
operator/issue/release route exists. Offline fixtures use host-verified synthetic
plugin caller context and a fixture-approved actor, reject `client`/other plugins,
and do not prove the outer local/gateway middleware. The default handler denies
all callers. Release requires an explicit `confirmed:true`, reason and affected
scope+operation; it persists actor/time/release ID. It only releases order. It does
not change receipt, route or core-attempt identity, nor permit a fresh mutation of
that operation. Late intake of a released missing operation remains held from
core-attempt reservation; no replay is created.

Operator issue-code grants a 12-hex-character one-use code for 60 seconds (fixture
security budgets, not measured production policy). Only code hash is stored.
Issuance reply loss requires an EXPLICIT new operator request/code; it does not
recover a raw code or silently recreate setup. The old unseen code expires. Repair
issuance explicitly names an active connection of this verified account; redeem
must match that same device. Connection revocation prevents continuity; explicit
new enrollment is a separate operator decision. Repair rotates key, revokes old
keys, preserves connection/epoch/old operations and intersects enrollment with
current grants. An account/instance change or missing authority freezes access;
old audio is never rebound. Same-ID exact redemption of a revoked key is denied.

Before ANY redemption request, native generates a cryptographically random token
in Keychain, successfully READS IT BACK, compares its SHA-256, and durably records
`pairingTransaction`: requestId, device, Keychain reference, hash, exact request
file/hash. Keychain inaccessible means freeze that SAME transaction. Never mint
another token, reconstruct a contradictory body or silently open another connection.
The flag in the DTO represents a native obligation; TypeScript fixtures do not
prove Keychain behavior or entropy. Raw token never travels to the server: redemption
sends only its SHA-256 + code + device + requestId over approved TLS. Native later
uses the original token as per-watch bearer; server compares hashes in constant time.
The paired reply echoes token hash/requestId and binds exact scope/keyId/epoch/grants.
Native verifies/persists that reply against its existing transaction before use.
No raw server token recovery or master/session/plugin-wide credential fallback.

Exact persisted redemption retries reconcile the original response/key after code
expiry or server restart, without reminting and without consuming NEW-attempt
budget. Contradictory same-ID attempts conflict and count as new failures. New
attempts cannot reuse an expired/used code. Per-code failure limit 5 (including
repair wrong-device attempts) and per-instance budget 20 NEW attempts/minute are
SQL-persisted; failures do not roll back their counters. Flood/denial-of-service
policy, stronger setup-code format/UX and measured rate limits remain production
review, not an admission claim. No real code, token or key was used/read here.

Current identity and scoped policy are re-read for authorization and again across
async boundaries. Credential-time grants cannot override current project/thread
revocation. Current grants intersect enrollment, and thread/project mapping must
match. Unknown identity/policy fails closed. These source assurances are injected
fixtures; an actual supported current-account adapter remains required.

Pairing NEVER sends staged audio. Reply declares `explicit-send-opt-in-required`;
`bindingOptIn` requires displayed connection+epoch, staged IDs and explicit user
confirmation. Native owns the atomic staged-to-bound enqueue; already bound,
received or unknown work cannot be included/rebound, and stopped drafts are not
silently swept in. Fixtures prove pairing creates zero jobs, not native user
confirmation/Keychain wiring.

## Computer-only routing and one-attempt boundary

`Router.decide(scope,operationId,completeOrderedTranscript)` is an INTERNAL future
worker interface, not a watch HTTP API or fake ready status. It requires an accepted
fixture job, frozen v2 manifest and current authorized identity/policy. No ASR/cache
worker is implemented. Caller must eventually supply one complete ordered ASR
result, preserving original incompleteness; partial text is not accepted as complete
by an invented provider endpoint.

Supported SDK calls, all stubbed in tests: `threads.get` for at most 4 explicit
authorized thread IDs, `defaultExecutionOptions`, bounded descending `events.list`
for 2 original-message anchors, `threads.message` with before/after 0, and
`system.executionOptions({providerId})`. Context is computer-side original bounded
text/title with source sequences/timestamps, not notifications/provider transcripts.
The policy's authorized candidate order bounds the set; it is not a claim to
search every BB thread. Fixture max age 5 minutes, future skew 5 seconds, title128,
message1024 and transcript6000 characters are provisional budgets, not release
calibration. Oversized/stale/malformed/unavailable context/catalog results hold.
No raw original context/transcript/title/key is stored in diagnostics or public
artifacts; durable evidence includes the hash, per-thread updatedAt, per-original-message
sequence/createdAt/text hash, decision/policy revision and observation time. Private SDK call recorder contains synthetic fixtures only.

Injected `JevTransport` has `choose(data,privateSecret)` and
`assessExact(data,privateSecret)`, no default network implementation. Secret access
uses SDK `settings.define({jevApiKey:{type:'string',secret:true}}).get()` only in
an injected fixture router. Default server never reads that setting. No actual
Jev/provider key, SDK content or network call was made. A future concrete transport
must use the existing Jev model/state/questions→answers service contract; these
internal methods are NOT claimed existing Jev HTTP endpoints.

All transcript/history/title data is untrusted quoted JSON data, never permission
to expand candidates, projects, execution, grants or invoke a tool. Jev output is
strictly parsed; chosen thread/project must be a current authorized candidate and
model/provider in the current SDK catalog. Existing resolved execution is retained
including permission/reasoning/service tier; a different model/provider is held.
Exact manual target invokes ONLY conflict assessment, never destination choice;
spoken conflict or uncertain assessment holds. Provider/parse/error/ambiguity and
confidence below provisional 0.9 hold, never choose a last-active target or fallback
model. Synthetic confidence scores prove policy branches, not real calibration.
New-project/thread selection is validated then HELD pending explicit creation and
reconciliation policy. The required future policy must name an authorized existing
project, allowed environment/execution and one durable creation intent; ambiguous
spawn acceptance cannot create another thread. No new-thread mutation occurs here.

One decision (including hold) is persisted per connection/operation with confidence,
evidence hash, policy revision and time. Concurrent calls share one in-process
promise; SQL insert-if-absent preserves the first durable decision across retries.
A changed policy makes a stored choice unavailable/held without deleting history
or reclassifying into a fresh operation. No automatic retry clears a persisted hold;
explicit BB recovery/revision policy is still open.

`CoreAttemptLedger.reserve` is a local FACT recorder, not dispatch. It requires an
existing valid decision/current authorization/no barrier and persists one attempt
ID BEFORE any hypothetical mutation. A repeat returns reconcile-only, with the same
record. Startup turns unfinished attempting into unknown, never retries. Explicit
order release does not delete that fact or permit another attempt. No code calls
SDK send/spawn; no core idempotency or definitive acceptance is inferred from
pluginSubmission metadata. Real submission, reconciliation, new-thread creation,
provider/ASR workers and downstream failure recovery remain BLOCKED/NOT RUN.
