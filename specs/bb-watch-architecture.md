# BB Watch 2.0 — architecture and gated implementation plan

**Pending extension:** the [voice-notes direction](bb-watch-voice-notes-direction.md)
adds Auto destination/model routing and pinned Reply. This architecture's complete
target-at-intake assumption must be revised and reviewed before that extension
is implemented; the existing review does not validate it.

Status: **reviewed for gated Phase 0; runtime gates unproven.** Companion to the
[product spec 2.0](bb-watch-product-spec.md), [design 2.0](../design.md) and the
[review](reviews/bb-watch-v2-fable-review.md). Platform facts cite the installed
BB 0.46.0 and plugin SDK 0.6.37 declarations; anything not verified is a Phase 0
go/no-go gate. Approval of this plan authorises running the gates, not a claim
that any gate has been measured; G1b, G2, G3 and G4 are runtime release
blockers until their reports exist.

## 1. Shape

Two deliverables, one job: the watch captures and delivers raw audio to an exact
BB target in the user's Send order; the computer-side plugin stores it durably,
transcribes it with BB's configured voice service, and submits one message per
recording to the exact thread.

```
Apple Watch Ultra 2 (LTE/Wi-Fi)                     Computer running BB
┌──────────────────────────────┐   HTTPS, file-backed   ┌──────────────────────────────┐
│ Recorder → sealed PCM parts  │ ── background upload ─▶│ plugin "bb-watch"            │
│ DurableStore (drafts, outbox)│ ◀── JSON receipts ──── │  intake routes + SQLite blobs│
│ Uploader (background session)│                        │  worker: ASR groups → send   │
│ Chooser cache (targets)      │ ◀── bounded lists ──── │  ledger, inbox page          │
└──────────────────────────────┘                        └──────┬───────────────────────┘
                                                               │ bb.sdk (in-process)
                                                        ┌──────▼───────────────────────┐
                                                        │ BB core: threads, projects,  │
                                                        │ system.transcribeVoice →     │
                                                        │ configured voice service     │
                                                        └──────────────────────────────┘
```

Choices that bound everything else:

- **Original = the watch's sealed parts, linear PCM16 mono, headerless.** No
  codec on the watch; a part is valid at any whole-frame length; recovery keeps
  the aligned prefix and preserves the raw file. The sample rate is a Phase 0
  decision: 16 kHz is the proposal (1,920,000 bytes per minute, about 1.83 MiB);
  the only existing bilingual ASR evidence is 48 kHz PCM16, so 16 kHz needs its
  own quality and converter proof (gate G2); 48 kHz is the fallback.
- **Parts seal at 60 seconds of audio or at Pause/Send.** A four-minute
  recording is four parts; a failed part is retried alone.
- **Send order is a fact recorded at Send**, carried in the manifest and enforced
  by the plugin per recipient lane; arrival order is never used for order.
- **The plugin stores part bytes as SQLite BLOBs** in its own database, in the
  same transaction as manifest and receipt rows, with full synchronous
  durability. No undocumented plugin file directory, no file/database crash
  window.
- **Watch success = sealed receipt from the plugin** (`received`), nothing later.
- **One automatic dispatch attempt per operation, with human reconciliation
  after ambiguous acceptance.** The intake transport retries its idempotent
  steps (declare, parts, seal) freely; dispatch to core is attempted once across
  restarts; every crash window without a positive core acknowledgement is
  `unknown`; nothing is replayed automatically.
- **Receipts and tombstones outlive audio.** Recording, ledger and part rows are
  never deleted; only bytes expire.

## 2. Ownership and types

### 2.1 Watch (Swift 6, SwiftUI; watchOS 26 minimum, current supported Xcode, per lead)

| Type | Owns | Must not |
|---|---|---|
| `Recorder` (actor off main) | `AVAudioSession` (`.record`), `AVAudioEngine` input tap, `AVAudioConverter`, `PartWriter`; the single live microphone | touch network or UI state; run while playback or dictation is active |
| `PartWriter` | frame-aligned appends to `NNNN.pcm.partial`; periodic `synchronize()` checkpoints; seal (aligned copy, hash, `NNNN.pcm`) | rewrite a sealed part; modify a raw partial on recovery |
| `DurableStore` (actor) | `drafts/<draftId>/` (parts, `draft.json` with committed lengths), `active.json` (`activeDraftId`, context, target), `outbox/<recordingId>/` (`manifest.json`, `state.json`, parts), `sendSeq` counter, `targets-cache.json`, pairing identity (non-secret) | store the device key (Keychain) or audio outside the container; delete audio without an explicit user action |
| `Uploader` (actor) | one background `URLSession` (fixed identifier, delegate); file-backed upload tasks with `taskDescription = "<recordingId>/<step>"`; wake-task completion | hold bytes in memory; create a task without a persisted step intent |
| `AppModel` (`@MainActor`) | UI projection: recorder mode (`idle`, `starting`, `recording`, `paused`), active draft, target, latest delivery, lists | perform I/O inline |
| `ChooserCache` | last `GET /targets` with `fetchedAt`; search passthrough only while not recording | invent targets |
| `Diagnostics` | bounded ring: state names, task ids, HTTP status, byte counts | audio, transcripts, titles, URLs with codes |

Identities: `draftId` (local), `activeDraftId` (restored on cold start),
`recordingId` (frozen at Send; server key), `contextId` (local New context, kept
until the next explicit `New thread`), `sendSeq` (per-device monotonic, assigned
at Send), `supersedes` (previous `recordingId` when the same audio is re-sent
after a confirmed abandon).

### 2.2 Plugin `bb-watch` (TypeScript, headless server plus one page)

| Module | Owns |
|---|---|
| `routes.ts` | routes under `/api/v1/plugins/bb-watch/http/…`, bearer verification, ownership checks, body caps, rate limits |
| `store.ts` | SQLite schema, append-only migrations, durability pragmas, quota accounting |
| `intake.ts` | manifest/part validation, seal, receipt, abandon tombstones |
| `order.ts` | recipient lanes, predecessor rules, context-to-thread aliasing |
| `worker.ts` | `bb.background.service("watch-worker")`: ASR groups, dispatch |
| `ledger.ts` | dispatch intent and acknowledgement rows; reconciliation checks |
| `targets.ts` | bounded projection of projects, recent threads, search, project-scoped execution catalog |
| `cli.ts` | `bb watch pair`, `bb watch revoke <deviceId>` (operational helpers) |
| `app/` | inbox page (required in the complete release): recordings with state, exact thread link, `Retry ASR`, `Reconcile`, `Abandon`, `Delete audio`, and the guarded `Send again` |

The plugin never writes to the host filesystem and never reads `experimental_dataDir`.

## 3. Watch lifecycle

### 3.1 Capture

1. Record → mode `starting`: activate the session, install the tap, open the
   next `*.pcm.partial`. The first delivered buffer flips to `recording`; only
   then the start haptic plays and the meter shows. If activation throws or no
   buffer arrives within a bounded wait (value chosen in Phase 3 from observed
   devices, not assumed), mode returns to the previous state with
   `Microphone unavailable` or `Microphone access needed`; the existing draft is
   untouched.
2. Each buffer: convert, append whole frames. Disk guard before every bounded
   write using a free-space value refreshed at most once per second; below the
   reserve (gate G6) capture stops safely with a message and all sealed parts
   plus the committed prefix are kept.
3. Checkpoint: every 5 seconds of audio `PartWriter` calls `synchronize()` and
   records the committed length in `draft.json`. The committed prefix is the
   durability claim; bytes after it may be lost on power loss and are recovered
   when present.
4. Seal at 60 seconds of audio or at Pause/Send: synchronize, copy the
   frame-aligned prefix to `NNNN.pcm`, hash, record `{index, bytes, sha256}`.
   Recovery after a crash: for a `*.pcm.partial`, take the largest frame-aligned
   length; seal that prefix; keep the raw partial under `recovered/` until the
   draft is deleted.
5. Pause → stop the tap, seal. Resume → new part. Send → stop, seal, freeze.
   `New recording` (secondary action while paused) parks the draft: it stays in
   `drafts/`, `activeDraftId` is cleared, history shows `Unsent · Continue`.
   `Continue` from history parks any current paused draft explicitly and
   activates the chosen one. One live microphone at all times; replay and
   dictation search are unavailable while recording; Record stops playback.
6. `Info.plist` declares `UIBackgroundModes: audio`. Capture while not frontmost
   is **gate G3** (separate from upload gate G4); until proven the UI promises
   nothing.
7. Interruption or termination: sealed parts and the committed prefix stay; the
   draft is restored `Paused · interrupted`, with the cause when the app saw the
   interruption and without one after a cold start.

### 3.2 Send and enqueue (one atomic `DurableStore` step)

Send requires a complete target: an exact thread, or a New context with a
project. A New context without a project opens the Project picker instead.
Once a context's first recording is enqueued, its project and execution choice
are frozen for every later draft in that context; the Project/Model rows show
the frozen values and do not open pickers; a different choice requires an
explicit new `New thread`.

`manifest.json` (JSONC for explanation; the file itself is strict JSON):

```jsonc
{
  "recordingId": "…", "createdAt": "…", "sentAt": "…", "supersedes": null,
  "format": { "codec": "pcm_s16le", "sampleRate": 16000, "channels": 1 },
  "target": { "kind": "thread", "threadId": "thr_…" },
  // or: { "kind": "new", "contextId": "…", "projectId": "proj_…",
  //       "execution": null }            // null = project default
  // or:   "execution": { "providerId": "…", "modelId": "…" }
  "order": {
    "sendSeq": 42,
    "predecessors": [ { "recordingId": "…", "recipient": "thread:thr_…" } ]
  },
  "parts": [
    { "index": 0, "bytes": 1920000, "sha256": "…" },
    { "index": 1, "bytes": 1920000, "sha256": "…" },
    { "index": 2, "bytes": 1920000, "sha256": "…" },
    { "index": 3, "bytes": 1920000, "sha256": "…" }
  ],
  "totalFrames": 3840000   // 240 s at 16 kHz; sum(bytes) = totalFrames × channels × 2
}
```

Validation at declare and again at seal: every `bytes` is a whole number of
frames (`channels × 2`), `sum(bytes) == totalFrames × channels × 2`, indices are
`0…n−1` without gaps, and the stored part sizes and hashes match the manifest.

`order.predecessors` lists every earlier enqueued recording of this device that
is not yet `received`, with its recipient key (`thread:<id>` or
`context:<id>`), so the plugin can hold a successor for a predecessor that has
not arrived yet. The list is bounded by the outbox size. Then move the sealed
parts, write `state.json` `{phase: "queued", acked: []}` and clear `activeDraftId`.

### 3.3 Delivery state machine (per recording, persisted)

```
queued ─▶ declaring ─▶ uploading(acked ⊂ parts) ─▶ sealing ─▶ received
   │           │               │                      │
   └───────────┴───────────────┴── failed(reason) ◀───┘      Retry reuses recordingId
                                       │
                           cancelling ─┴─▶ cancelled      only on confirmed `abandoned`
                                                            → Delete / Send to another thread
```

| Step | Request | Body file | Success |
|---|---|---|---|
| declare | `PUT /recordings/{id}` | manifest JSON | 200 `{state}`; 409 `target_unavailable`, `execution_unavailable`, `supersedes_not_abandoned`; 507 quota |
| part i | `PUT /recordings/{id}/parts/{i}` with `X-Part-SHA256`, `Content-Type: application/octet-stream` | sealed part | 200; 409 hash mismatch or `abandoned` |
| seal | `POST /recordings/{id}/seal` | empty JSON | 200 receipt `{recordingId, jobId, state: "received", receivedAt}` (`jobId` equals `recordingId`: one job per recording); 409 `missing_parts` or `abandoned` |
| cancel | `DELETE /recordings/{id}` | — | 200 `{state: "abandoned"}`; 409 `{state}` once received or later |

**Cancel and re-target.** `Cancel delivery` is allowed before `received`. The
watch shows `cancelled` only after the plugin answers `abandoned`; while
unreachable the item stays with `Can't cancel while BB is unreachable`.
`Send to another thread` is offered only in `cancelled`; it creates a new
`recordingId` with `supersedes`, which the plugin accepts only if the superseded
row is `abandoned`. Absence of an acknowledgement is never non-acceptance.

### 3.4 Background session lifecycle

- One `URLSessionConfiguration.background(withIdentifier:)` session, delegate
  set, `sessionSendsLaunchEvents` enabled, bounded `timeoutIntervalForResource`,
  at most four live tasks, response bodies read up to 16 KiB.
- Every task is created only after its step intent is persisted in
  `state.json`; `taskDescription` carries `<recordingId>/<step>` so an orphan
  can be matched after relaunch.
- Delegate events arrive either directly (app running) or after a wake through
  `WKURLSessionRefreshBackgroundTask`. On a wake: match the task's session
  identifier to the owned session, recreate the session with the same
  identifier so the delegate receives pending events, persist each outcome,
  and complete the wake task once after `urlSessionDidFinishEvents`
  ([WKURLSessionRefreshBackgroundTask](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask)).
- On launch and foreground: `getAllTasks` reconciles live tasks against
  persisted steps; a step without a live task is rescheduled; a task without a
  step is cancelled.
- Transient failure while not frontmost: the step returns to `queued` with an
  attempt counter; the app schedules a bounded background refresh with a
  preferred date (backoff; at most three automatic attempts) and also retries on
  the next foreground reconciliation. The OS decides when a refresh runs; no
  ETA is shown ([Making background requests](https://developer.apple.com/documentation/watchos-apps/making-background-requests),
  [Life cycles](https://developer.apple.com/documentation/watchkit/life-cycles)).
  Unstructured tasks are never used as a runtime grant.
- 401 → `failed(unauthorized)`, pairing marked stale, no automatic re-pair.

### 3.5 Reconciliation (launch, foreground, task completion)

For each outbox recording not terminal: `GET /recordings/{id}` → merge the
acknowledged part set; create missing steps; `received` or later marks it
received without another Send; `abandoned` marks it cancelled; 404 after
`declared` → re-declare. The seal is idempotent by `recordingId`, so a lost seal
response cannot create a second job. Force quit is not detectable; a cold start
reconciles. When a status answer carries `threadId` for a context, the watch
records `contextId → threadId` and uses the thread key for later order chains.

### 3.6 Targets

`GET /targets?limit=30` returns `{serverLabel, projects[], threads[], asOf}` and,
per project, the execution catalog (§4.4). The watch caches it, shows `as of
<time>` when older than one hour, allows offline selection, and validates at
intake. `GET /targets?q=` is search, reachable only while not recording.

## 4. Plugin intake contract

### 4.1 Routes

All routes except `POST /pair` require `Authorization: Bearer <deviceKey>`,
verified in the handler (constant-time compare of the SHA-256 against a
non-revoked device row). Every recording route then checks
`recording.device_id == device.id`; a mismatch or unknown id answers 404 so
that another paired device learns nothing. `auth: "none"` is used because the
handler verifies its own credential, the SDK's documented pattern; the static
plugin token never reaches the watch.

| Route | Purpose |
|---|---|
| `POST /pair` `{code, deviceName}` | body ≤ 1 KiB and a global rate limit enforced before reading; one-time code, 10-minute TTL, five attempts then burned; returns `{deviceId, deviceKey, serverLabel, serverInstanceId}` |
| `GET /me` | identity for Settings and reconciliation |
| `GET /targets` | bounded projection (§4.4) |
| `PUT /recordings/{id}` | declare; validates target, execution pair, format, order list, quota, `supersedes`; idempotent for an identical manifest; an existing id in any state returns that state and never a new job |
| `PUT /recordings/{id}/parts/{i}` | `Content-Length` required and ≤ 8 MiB, counted and hashed while streaming, aborted above the cap; BLOB and row in one transaction; idempotent; 409 after `abandoned` |
| `POST /recordings/{id}/seal` | all parts present → `received`; idempotent; 409 after `abandoned` |
| `GET /recordings/{id}` | state, acknowledged parts, `threadId` when known, error reason |
| `DELETE /recordings/{id}` | `declared`/`receiving` → `abandoned`; an unknown id creates the tombstone and answers `abandoned`; `received` or later → 409 with the state |

### 4.2 Pairing, identity and the two ingress proofs

`bb watch pair` or the inbox page mints a code and prints the BB handle. Watch
Settings has `BB address` (handle; apex `getbb.app` default, editable) and
`Code`. The pairing response's `serverInstanceId` (generated once, kept in kv)
and `serverLabel` are the paired identity shown in Settings. Revocation by
`bb watch revoke <deviceId>` or the page; revoked keys get 401.

Two separate proofs: **G1a** the plugin's own authorisation on loopback (routes
answer 401 without the key, 404 across devices, 200 with the key); **G1b**
remote admission through the BB remote-access URL for a non-browser client
with raw bodies, including the body cap and idle timeout. If G1b fails, the
plan **blocks**: the resolution is a scoped ingress or core capability (plugin
wire path admission without a browser session, or core-issued scoped client
credentials), proposed to the BB maintainers. The watch never holds a core
mobile session or workspace token, and the BB port is never exposed through a
separate public proxy.

### 4.3 Storage (plugin SQLite, append-only migrations)

```sql
device(id TEXT PK, name TEXT, key_sha256 TEXT UNIQUE, created_at INT, revoked_at INT NULL);
pairing_code(code_sha256 TEXT PK, expires_at INT, attempts INT, used_at INT NULL);
context(id TEXT PK, device_id TEXT, project_id TEXT, provider_id TEXT NULL, model_id TEXT NULL,
        thread_id TEXT NULL, created_at INT);
recording(id TEXT PK, device_id TEXT, state TEXT, manifest_json TEXT, supersedes TEXT NULL,
          target_kind TEXT, thread_id TEXT NULL, context_id TEXT NULL, send_seq INT,
          declared_at INT, received_at INT NULL, transcript TEXT NULL,
          error TEXT NULL, audio_expired_at INT NULL, updated_at INT);
predecessor(recording_id TEXT, predecessor_id TEXT, recipient TEXT, PRIMARY KEY(recording_id, predecessor_id));
part(recording_id TEXT, idx INT, bytes BLOB NULL, size INT, sha256 TEXT, received_at INT, PRIMARY KEY(recording_id, idx));
asr_group(recording_id TEXT, idx INT, from_part INT, from_frame INT, to_part INT, to_frame INT,
          text TEXT NULL, error TEXT NULL, PRIMARY KEY(recording_id, idx));
ledger(recording_id TEXT, phase TEXT, thread_id TEXT NULL, evidence TEXT, at INT);
```

`recording.state`: `declared → receiving → received → transcribing → transcribed → waiting_order → dispatching → core_submitted | needs_attention | abandoned`.
Durability: on the handle from `bb.storage.database()` the plugin sets
`PRAGMA synchronous = FULL` and verifies it reads back as FULL at every load
(fail the plugin into `needs-configuration` otherwise); WAL stays as BB
configured it; a checkpoint runs after each seal. A receipt is returned only
after the committing transaction has returned. Rows in `recording`, `predecessor`,
`ledger` and `part` are permanent; retention sets `part.bytes = NULL` and
`audio_expired_at` after `retention_days` (default 7) past `core_submitted`;
nothing expires in `needs_attention`. `abandoned` is a tombstone that rejects
later parts and seals.

Quota is two bounded checks, no new subsystem:

- **Logical retained bytes** = `SUM(part.size WHERE bytes IS NOT NULL)` plus
  the bytes reserved by admitted but incomplete recordings (`declared`/`receiving`
  manifests, `sum(parts.bytes)` minus bytes already stored). Declare reserves the
  manifest total and part upload consumes it inside the same transaction, so
  concurrent declares and parts cannot oversubscribe; a reservation is released
  on `abandoned`. `max_intake_bytes` (gate G6; proposal 2 GiB) bounds this sum;
  507 at declare and at part upload. Retention (`bytes = NULL`) lowers the sum
  and frees capacity for reuse; receipt, order and tombstone rows stay.
- **Physical headroom** = free space on the data volume minus the current WAL
  file size must exceed `min_disk_headroom` (gate G6) before a declare or part
  write; allocated database size is never used as the logical quota, since
  freed pages are reused rather than returned.

### 4.4 Targets projection

`projects.list` → `{id, name}`; `threads.list({archived: false, includeHidden: false, limit: 30})`
sorted by `updatedAt` desc → `{id, title ?? titleFallback, projectId, updatedAt}`;
`threads.search` for `q`. Execution catalog per project: the project's default
execution options plus the provider/model pairs the SDK reports as available for
that project's provider and host; the exact SDK calls (`projects.defaultExecutionOptions`,
`providers.models` with host routing) and their arguments are verified in Phase 1,
and the watch only ever sends a `{providerId, modelId}` pair from that catalog or
`null`. At declare and again at dispatch: `threads.get` must return a thread that
is neither archived nor deleted; an execution pair must still be in the catalog;
otherwise `target_unavailable` or `execution_unavailable`.

## 5. Worker: order, transcription and dispatch

### 5.1 Lanes and Send order

A lane is `thread:<id>` or `context:<contextId>`. When a context resolves to a
thread, the context lane is aliased to the thread lane: its pending recordings
join the thread lane and are ordered with direct-thread recordings by
`send_seq`. Two rules decide when a recording may dispatch:

1. **Already-received earlier recordings.** Within a lane, a recording of a
   device dispatches only after every recording of the same device in that lane
   with a lower `send_seq` that the plugin already holds is `core_submitted` or
   `abandoned`, whatever its ASR or dispatch progress. These do not appear in
   the successor's predecessor list (the list covers only recordings not yet
   received at Send time); the plugin orders them from its own rows.
2. **Not-yet-received earlier recordings.** Every entry of `order.predecessors`
   whose recipient aliases to the same lane must be `core_submitted` or
   `abandoned`; an entry that has not arrived keeps the successor in
   `waiting_order` even though the plugin has never seen it.

A predecessor in `needs_attention` blocks the lane until repaired or abandoned
on the computer. Recordings of different devices in one lane are ordered by
plugin admission time. Lanes run concurrently (bounded, proposal four), so a
slow or failed recipient does not block another (V09). Transcription is not a
mutation and may run in any order; only dispatch waits.

### 5.2 Transcription (streamed, bounded)

1. Groups are built from stored parts in index order without loading the whole
   recording: a group ends when adding the next part would exceed
   `asr_group_bytes` (gate G2; proposal 16 MiB at 16 kHz, under the installed
   25 MiB cap) or at the last part. The group boundary is moved back to the
   lowest-energy 20 ms window within the last two seconds of its final part;
   the remainder starts the next group. Memory is bounded by one group plus one part.
2. For each group in order: wrap as WAV in memory, call
   `bb.sdk.system.transcribeVoice({file, signal})` with a signal bounded by the
   measured envelope, persist `asr_group.text` before the next group.
   Completed groups survive restart, reload and `Retry ASR`; processing always
   resumes at the first group without text. A group failure sets
   `needs_attention(asr)`; provider calls are bounded to one per group per
   attempt, with no automatic repeat beyond one retry per load.
3. Transcript = group texts joined with one newline. Empty → `needs_attention(empty)`.

### 5.3 Dispatch

Input: `[{ type: "text", text: transcript, mentions: [] }]`, mode `auto`, no
permission, reasoning or service-tier fields (BB's hooks and project defaults
apply unchanged). The transcript is never rewritten.

- Existing thread: `ledger(intent)` → `threads.send({threadId, mode: "auto", input})` → on a `sent` or `queued` result `ledger(core_ack, evidence)` → `core_submitted`.
- New context without a thread: `ledger(intent)` → `threads.spawn({projectId, environment: {type: "project-default"}, input, providerId?, model?, pluginMetadata: {contextId, recordingId}})` → `context.thread_id` → `ledger(core_ack, "spawned:<threadId>")` → `core_submitted`. Later recordings in the lane use `threads.send`.
- `core_submitted` means core acknowledged the message; provider acceptance,
  turn outcome and "done" are BB's and visible in the thread.
- The `ledger(intent)` row is the single automatic attempt for that recording
  across restarts; a second automatic attempt is impossible by construction.

### 5.4 Reconciliation after a crash or reload

For each recording with `ledger(intent)` and no `ledger(core_ack)`:

1. Spawn case: `threads.list({originPluginId: "bb-watch", includeHidden: true})`
   plus `experimental_listPluginMetadata` → a thread carrying `{contextId}` is
   adopted as the context's thread identity so later recordings go there. This
   identifies the thread only; it does not prove the first prompt was accepted.
2. The recording becomes `needs_attention(acceptance_unknown)` with the thread
   link and transcript on the inbox page. Absence of a message in any bounded
   scan never proves non-acceptance.
3. Page actions: `Reconcile` (re-run step 1), `Abandon` (tombstone; the user
   decided the message is not needed), and `Send again`, which requires an
   overt confirmation naming the duplicate risk and writes a new intent row.

No dispatch hook, provenance block or `pluginSubmission` tag is part of this
plan: none of them proves provider acceptance, and absence of their evidence
proves nothing.

## 6. Error handling matrix

| Failure | Watch | Plugin | User sees |
|---|---|---|---|
| Mic permission denied | Record disabled state | — | `Microphone access needed` |
| Activation fails or no first buffer | previous mode, draft kept | — | `Microphone unavailable` |
| Interruption / OS ended capture | seal committed prefix, restore paused | — | `Paused · interrupted` |
| Low storage | stop capture, keep parts | — | `Storage full, recording saved` |
| Network absent | tasks wait | — | `Queued` |
| Plugin unreachable (refused, 502/503) | `queued` with attempt count; bounded refresh + foreground retry | — | `Waiting for BB` |
| 401 | freeze, pairing stale | — | `Pairing needed` |
| 409 `target_unavailable` / `execution_unavailable` | `failed(target)`; cancel offered | — | `Thread unavailable · Cancel delivery` |
| Cancel while unreachable | stays | — | `Can't cancel while BB is unreachable` |
| Confirmed `abandoned` | `cancelled` | tombstone | `Cancelled · Send to another thread / Delete` |
| 409 hash mismatch | re-upload once, then failed | reject part | `Needs attention` |
| 507 quota | `failed(quota)` | — | `BB storage full` |
| Predecessor missing or failed | — | `waiting_order` | watch: `Received by BB`; page: waiting on `<predecessor>` |
| ASR failure | — | `needs_attention(asr)`, lane blocked, groups kept | page: `Retry ASR` |
| Send/spawn error or crash before `core_ack` | — | `needs_attention(acceptance_unknown)` | page: thread link, `Reconcile`, guarded `Send again` |
| Plugin reload mid-upload | stored parts stay; next task resumes | routes re-register; worker rescans | nothing |

## 7. Security and privacy

- Device key: 32 random bytes, base64url, shown once in the pairing response,
  stored in the watch Keychain, hashed at rest on the computer. HTTPS only; the
  watch rejects redirects. Pairing codes are hashed at rest and burned after use
  or five failures; the pair route is rate-limited and size-limited before any
  body is read.
- Ownership: every recording route checks the device; a device key authorises
  only its paired BB instance; targets are validated through `bb.sdk` at declare
  and at dispatch.
- Raw voice is data, never an instruction: the plugin never parses transcripts
  for routing, settings or approvals.
- Logs record identifiers, states, sizes and statuses; never audio, transcript,
  titles, keys or URLs with codes.

## 8. Retention, deletion and migration

- Watch: originals stay until the user deletes them; `received` and unknown
  items offer `Delete local copy` labelled "does not retract". No automatic
  cleanup in the first release.
- Computer: §4.3 retention, visible and editable in plugin settings; receipts,
  order rows and tombstones never expire.
- Migration is a neutral data contract, not code reuse. The lead exports the
  previous build's recordings into `legacy-export/manifest.json` with, per
  recording, `{id, createdAt, sampleRate, channels, codec, parts: [{file, sha256}],
  delivery: "unsent" | "received" | "unknown", destinationLabel}`. The new app
  imports them as history items that keep their delivery state: `unsent` →
  `Unsent · imported`, `received` → `Received · imported`, `unknown` →
  `Acceptance unknown · imported`. Imported audio is never sent automatically and
  never becomes an active draft; the source is never deleted.
- Hard install gates: a verified user-data backup (exported count and hashes
  match the device container) and same-bundle-identifier compatibility of the
  new build with the existing container, both before the first install.

## 9. API capability table

| Need | Status | Evidence / note |
|---|---|---|
| Raw-body HTTP routes in a plugin | **Existing, verified** | `bb.http.route` with Hono context; wire path exempt from origin check |
| Per-device revocable credential | **Proposed plugin protocol** | `/pair` + `device` table; SDK offers only a static plugin token |
| Plugin own authorisation on loopback | **Gate G1a** | handler-verified bearer under `auth: "none"` |
| Remote admission of plugin routes for a non-browser client | **Blocker, gate G1b** | `bb connect` URL exists; admission and body cap unproven; failure blocks and needs a scoped core capability |
| Durable plugin storage with migrations | **Existing, verified**; synchronous mode set and verified by the plugin | `bb.storage.database()`, `migrate()` |
| Transcription with BB's configured service | **Existing, verified; limits lead-verified** | `system.transcribeVoice`; 25 MiB, 70 s deadline; hosted by default |
| Send to exact thread; create thread with first message and provider/model | **Existing, verified** | `threads.send`, `threads.spawn` (`providerId`, `model`, `input` required) |
| Idempotent send/create | **Requires core extension**; mitigated by single intent + human reconciliation | no key field; `sent` has no message id |
| Find plugin-created threads by metadata | **Existing, experimental** | `pluginMetadata`, `threads.list({originPluginId})`, `experimental_listPluginMetadata` |
| Project-scoped execution catalog | **Existing; exact calls verified in Phase 1** | project default execution options, `providers.models` with host routing |
| Recent/visible threads, search, projects | **Existing, verified** | `threads.list/search`, `projects.list` |
| Audio attachment in the thread | **Not in v1** | `projects.attachments.upload` (25 MB, no delete) + `localFile` |
| Inbox page | **Existing, frontend bundle** | navigation panel slot |
| Background file-backed upload on watchOS | **Apple-stated; timing gate G4** | background `URLSession`, delegate, refresh task |
| Capture while not frontmost | **Apple names audio-recording apps; gate G3** | `UIBackgroundModes: audio` |
| Relaunch after user force quit | **Not stated for watchOS; treated as unknown** | cold-start reconciliation |

## 10. Acceptance mapping

| ID | Architecture | Proof (deterministic unless marked device) |
|---|---|---|
| V01 | §3.1 | UI test: launch → Record in one tap, offline; denied-permission state |
| V02 | §3.1 parts and checkpoints, §3.2 manifest | unit: pause/resume/send → ordered parts, frame sum, recovery of an aligned prefix |
| V03 | review §4.2 | UI test: X/swipe/pick effects; search only after Pause; replay blocked while recording |
| V04 | watch has no ASR path | code grep + network capture; ASR off → still `received` |
| V05 | §3.3–3.5 | device: Send, wrist down, receipt time, OS deferral recorded |
| V06 | §3.5, §4.1 idempotent steps | fault test: dropped seal response → one job |
| V07 | §5.2 | fixture 4 min RU/EN → one message, coverage, group order, resume after reload |
| V08 | §3.4 waits, §3.5 | computer off → `Queued`; on → same recordingId received |
| V09 | §5.1 | (a) successor uploaded before its predecessor arrives → `waiting_order`; (b) predecessor received first but with slow or failed ASR while the successor uploads and transcribes fast → successor waits; (c) context resolved to thread T while a direct send to T with a higher `send_seq` arrives → ordered by `send_seq`; in all cases another lane proceeds |
| V10 | §5.3 contexts, §4.4 | one spawn per context; wrong key → 401; cross-device id → 404, no bytes stored |
| V11 | §4.3, §5.4 | kill plugin at each state → no duplicate; unknown shown; tombstone rejects a late seal |
| V12 | §3.1 parking, §3.2 atomic enqueue | UI test: receipt during a new draft leaves its target; parking and Continue |
| V13 | design accessibility | simulator: largest Dynamic Type, VoiceOver, Reduce Motion |
| V14 | review §4.2 | screenshot audit of every surface |
| V15 | §7, §8 | revoke → 401 freeze; artifact scan |
| V16 | §11 | fresh clone builds plugin and watch; per-phase checks |

Dispatch and reconciliation checks use an SDK test fixture or a dummy transport
(`@get-bb/plugin-sdk/testing`); no live agent prompt is sent by a test. A real
end-to-end prompt happens only as a user-initiated acceptance run.

## 11. Phased plan with checks

### Phase 0 — go/no-go gates

Spikes live in the rewrite worktree under `proofs/` with scripts and a report,
so they are reproducible by the implementer; no separate product folder.

| Gate | Check | Go |
|---|---|---|
| G1a own auth | plugin route on loopback: no key → 401; other device's recording → 404; key → 200 | all three |
| G1b remote admission | same route through `https://<handle>.getbb.app` with 2 MiB and 20 MiB octet-stream bodies, no browser session | 200 both, measured cap and idle timeout recorded; otherwise **block** |
| G2 ASR | `bb voice transcribe` on OS-TTS bilingual sources of 60, 240 and 600 s, cut into the chosen groups at 16 kHz PCM16 mono and at 48 kHz | wall time per group inside the deadline; coverage not below the 48 kHz reference; sample rate chosen |
| G3 capture | spike with `UIBackgroundModes: audio`: 5-minute recording through wrist down, Crown press, another app | sealed parts hold the full duration; otherwise spec text changes |
| G4 delivery chain | spike implementing the production-shaped declare → parts → seal protocol (§3.3) against the G1b route in the chosen format: a four-minute fixture (four 60-second parts) and a long fixture; Send, then wrist down; intermittent network; relaunch; force quit; a deliberately dropped seal response. Generic 2 MiB and 8 MiB single transfers stay as a baseline | every part, the receipt and the job start observed while the wrist is down; enqueue → durable receipt latency and every wake/step boundary recorded; dropped seal → the same receipt; force-quit behaviour recorded, not promised. An unacceptable chain, or no receipt while asleep, fails the gate and revises the protocol before any UI work. The measured envelope goes into the gate report; no latency number is set in advance |
| G5 catalog | SDK calls for project-scoped execution options and provider/model pairs; `threads.spawn` with `providerId` + `model` on a fixture | exact arguments and result shapes documented |
| G6 limits | free-space reserve, part cap, quota, retention, activation wait from G1–G4 | numbers in settings defaults |

B1–B4 of the review close here or change the spec.

### Phase 1 — plugin intake

Routes, pairing, storage with durability pragmas, validation, status,
tombstones, order rows, targets projection, `bb watch pair/revoke`. Checks:
unit tests with `@get-bb/plugin-sdk/testing` for code TTL/attempts/rate limit,
body cap, hash mismatch, idempotent declare/part/seal, quota including WAL,
abandon and supersede rules, cross-device 404; live upload of fixture parts.

### Phase 2 — worker, dispatch, inbox page

Lanes and predecessor rules, streamed ASR groups with persisted cache,
single-intent dispatch, reconciliation, inbox page. Checks: fault injection at
every state with a dummy transport → no duplicate, unknown shown; successor
before predecessor → waits; V07 fixture; `Retry ASR` resumes at the first
missing group after a reload.

### Phase 3 — watch app

DurableStore, Recorder/PartWriter, Uploader, AppModel, root, Threads sheet,
pickers, Recordings, detail, Settings. Checks: core unit tests (parts,
checkpoints, recovery, manifest, state machine, reconcile merge, parking,
frozen context), URLProtocol contract check per route, simulator UI tests for
the walkthrough table, accessibility pass.

### Phase 4 — device acceptance

Ultra 2 runs for V05, V07, V08, V11 with recorded timings; artifact scan for
V15; gate report updated. Release decision by the lead only.

## 12. Clean-room packet for the rewrite

- **Worktree**: `git worktree add ../bb-watch-v2 --detach`, then
  `git checkout --orphan v2` inside it and remove the inherited tree. `main` and
  the released checkout stay untouched; nothing is deleted from them. The
  shared `.git` history remains reachable, so this is process isolation for
  clean design, not a security boundary.
- **Builder brief** (copied): the approved `specs/bb-watch-product-spec.md`,
  `design.md` and `specs/bb-watch-architecture.md` with their supersession and
  review-stage paragraphs removed; a neutral `AGENTS.md`; `assets/` with owned
  artwork and a rights note; `fixtures/` with OS-TTS bilingual audio;
  `proofs/` with the Phase 0 scripts and report; `contracts/README.md` pinning
  BB 0.46.0, SDK 0.6.37 and the verified facts of §9.
- **Excluded**: the review document, `native/`, `docs/`, `specs/archive/`,
  `output/`, prior findings documents, transcripts, prompts, device or thread
  identifiers.
- **Neutral `AGENTS.md`**: build from the brief only; SDK types via
  `npm pack @get-bb/plugin-sdk@<pinned>`; never consult prior implementations;
  checks per phase; no device install without the lead; no deletion of user
  data; migration only through §8; no live agent prompts in tests.
- **Session start**: the lead prepares the worktree and brief first, then
  starts a fresh implementing session with `bb thread spawn --environment
  <absolute worktree path>` (the installed CLI accepts a prepared unmanaged
  workspace path), with no fork, source thread or history attachment.

## 13. Decisions recorded from the lead

1. Minimum watchOS 26 with the current supported Xcode for the packet.
2. Inbox page is part of the complete release; CLI is an optional helper.
3. Message mode `auto`; no permission, reasoning or tier overrides from the watch.
4. Defaults to be fixed after gates: part seconds (60), part cap (8 MiB), quota,
   retention days, free-space reserve, ASR group size, activation wait, sample rate.
