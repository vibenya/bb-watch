# v2 bounded offline integration boundary — proposal

This revision is incompatible with v1. v1 fixtures remain explicitly versioned;
v2 never treats v1 envelopes as v2. No production protocol freeze or gate closure.

1. **Order checkpoint.** A connection has immutable random orderEpoch. A persisted
   opaque checkpoint is bound to full identity+epoch and a contiguous prefix of
   immutable `{sequence, operationId, intent}` facts, independent of audio arrival,
   routing or core outcome. A bounded request extends a prior checkpoint with at
   most 64 uncovered facts; an exact idempotency requestId returns the original
   persisted checkpoint after lost reply/restart. A manifest carries that checkpoint
   plus only uncovered facts; no 64 lifetime-Send limit. Server retains all unresolved,
   unknown, fence, decision/submission and release facts; checkpoint is NOT a release.
   Barrier query reads the durable prefix ledger, not just manifest's short tail.
   Unknown BB blocks all possible targets until resolved/released; once resolved to
   T, U is independent while T stays blocked. Server metadata outlives source bytes.
2. **Pairing.** Native generates a cryptographically random device token in Keychain
   BEFORE redemption and persists the same requestId/token/code transaction locally.
   Only token SHA-256 is sent/stored with one-use code redemption; private server
   reply binds keyId, scope, epoch and grants, never remints a credential. Lost reply
   retries same request identity/hash, so no recoverable raw token in server DB.
   Explicit staged-audio opt-in is a separate connection-bound native action; pairing
   never flushes. Operator-issued expiry/attempt budgets, current identity/grants,
   continuity/rotation/revocation and release are fail-closed control-plane policy.
3. **Operator and identity blocker.** SDK RPC caller is only `client` vs authenticated
   pluginId; client includes app, CLI AND agents. CLI context has cwd/thread/project,
   no authenticated-human identity. Therefore client/local alone cannot authorize
   issuing codes or order release. Default server registers no such public route.
   Offline handlers will require an injected operator authority and verified current
   instance/account adapter, and exercise real SDK RPC handlers with fixture caller
   contexts. Production authority source is missing until reviewed host signatures
   prove authenticated operator ownership. No body-provided role/identity is trusted.
4. **Computer-only Jev.** Worker-facing function loads accepted fixture job + frozen
   intent, current scoped policy, bounded SDK thread list/original message events and
   execution catalog. Inject Jev transport; no live call/default network implementation.
   Exact target is binding; semantic conflict holds. Validate Jev choices within
   candidates+grants+catalog; errors/ambiguity/stale policy hold. Persist one decision
   with confidence/context revision before any hypothetical core mutation. Untrusted
   transcript/history is data, not authority. New creation is held pending explicit
   project policy. One-attempt/core-unknown ledger is modeled with no send/spawn.

Fixture budgets are explicit per request/resource, not release latency/storage or
confidence calibration. Native sequence allocation+outbox enqueue is one transaction;
concurrent sends serialize locally. Same sequence with different immutable facts
conflicts on server. Unsynced audio/operations and all unknown acceptance stay retained.
