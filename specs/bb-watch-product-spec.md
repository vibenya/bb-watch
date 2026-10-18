# BB Watch — voice delivery interface

Version 2.0 · 18 October 2026 · **Reviewed product contract; not implemented.**

This specification supersedes 1.2 for the next implementation. Existing application
code is not a reference implementation. [Design](../design.md) defines navigation;
[architecture and gated plan](bb-watch-architecture.md) record independent
[Fable review](reviews/bb-watch-v2-fable-review.md) and lead validation.
Approval covers the documented Phase 0 proofs; runtime gates remain unproven.
Version 1.2 is archived for the
installed build; it must not leak requirements into the fresh implementation.

## 1. Job and boundary

When I have a thought for an agent, I want to record it on my watch and send it
to the right BB thread, so I can return to real life without watching a spinner,
keeping my wrist raised, or opening my phone.

The product comprises a small independent watchOS voice recorder/delivery client
and a BB plugin on the computer. The plugin is an external-input adapter, like
a Telegram connector. BB remains the workspace, conversation and agent runtime.
The watch is not a second BB workspace. It owns capture, local originals,
recipient intent and transfer. The plugin owns durable audio intake, transcription
and submission to BB. A hosted ASR service may be called by the computer; audio
must never go directly from the watch to an ASR provider.

**The watch's success boundary is a durable BB audio receipt**, not completed
transcription or agent output. Receiving an HTTP response, uploading all bytes,
accepting a transcript and completing an agent task are distinct facts.

## 2. Actors and first release

- User with an Apple Watch Ultra 2, independently connected over LTE/Wi-Fi.
- Paired BB plugin with a reachable BB computer; no nearby iPhone requirement.
- BB's configured transcription service and the selected existing/new thread.
- The computer may be asleep/offline. The watch safely queues audio until it
  can reach the plugin. No claim that this product wakes a sleeping computer.

Included: native full-screen recorder; pause/resume; autosave; explicit Send;
thread selection; New with project and optional model override; durable outbox;
file-backed background transfer; receipt reconciliation; minimal recording
history with local audio replay/delete; desktop intake/transcription/status UI;
recovery without replaying an ambiguously accepted agent message.

Excluded from the watch: transcript generation/editing; provider API keys;
agent-thinking views, conversation reader, live task summaries, question-choice
workflows, answer speech and a miniature BB sidebar. These are deliberate changes
from 1.2. Thread/model selection is a delivery affordance, not workspace management.
No automatic recording, automatic Send, autoplay, notifications or audio discard on dismissal.

## 3. Everyday behavior

1. Launch to one full-screen recorder. After the system microphone permission
   has been granted, one conspicuous Record control starts capture, including
   offline/unpaired. No project/model prerequisite. Pending activation is honest;
   microphone denial/unavailability shows a recoverable state, never a fake meter.
2. A compact recipient row names the current target or says `Choose thread`.
   It is visible before Send; during recording it identifies this draft's target.
3. Recordings checkpoint locally. Pause stops input; resume continues the same
   draft. Wrist-down capture must continue with the legitimate recording audio
   session; OS interruption, storage stop or termination preserves finalized
   parts and returns as `Paused · interrupted`, with the cause when known. An
   incomplete capture is never silently presented as finished. Actual wrist-down
   and not-frontmost capture are hardware gates, separate from transfer APIs.
4. Send is explicit and available during recording or pause. It finishes capture,
   freezes recipient and immutable audio manifest, and queues delivery durably.
   Without a complete recipient, Send first pauses capture and opens the required
   chooser (Threads, or Project for New without a project). Selection returns to
   the paused recorder for a final explicit Send. Choosing a target never sends.
5. After durable enqueue, the recorder is immediately ready for another thought.
   A compact latest-delivery row links to the outbox; no modal progress lock.
6. Wrist down, screen dimmed and ordinary app backgrounding do not require the
   user to resume ASR or keep the recorder open. The OS may defer networking;
   local audio and transfer identity persist. No promise of an OS scheduling ETA.
7. `Received by BB` means the plugin durably holds the complete validated original,
   its exact recipient intent and a recoverable processing job. ASR may start
   later and may fail. This cannot turn back into a watch upload failure.
8. The plugin transcribes complete audio in ordered groups within the voice
   service's verified size/time envelope, preserving completed results across
   retry/restart. A failed group cannot silently disappear or cause submission
   of incomplete text. The complete text becomes one logical message to the
   exact target. BB-side errors are handled on BB; no re-dictation or re-upload
   just because ASR failed.
9. One active compose ID restores the same paused draft on return. Other autosaved
   unsent drafts may remain in history. An explicit secondary `New recording`
   action parks the current paused draft; `Continue` restores a chosen older
   draft. Neither action sends or deletes anything, nor starts the microphone.
   Users can save several thoughts while unpaired with no available recipient.

## 4. Recipient rules

- Use a small recent-threads list with search on demand and a `New thread` row.
  Preserve exact child-thread IDs. Do not replace a selected child with a family.
  Hidden/archived/deleted/unavailable recipients are not silently substituted.
- A cached target remains selectable offline, with freshness explained when
  relevant. BB validates authorization and availability before processing.
- Existing thread: show its actual title; do not require choosing a model.
- New: choose a project; `Project default` is a valid model choice. Optional
  overrides come only from the plugin's verified catalog. No required title.
- New is local intent. Selecting New returns to the recorder; Project and Model
  each use a separate single-level sheet. Picking a value commits only that
  choice; Close commits nothing. No wizard or extra `Use target` step.
- The real thread is created at the plugin's first dispatch of the New context,
  with full initial transcript and a durable context correlation marker. Mapping
  a found thread back to its context is not proof that its first prompt was
  accepted: an ambiguous spawn is reconciled or blocked, never blindly repeated.
- The current compose context has a stable ID. A follow-up to a pending New
  context goes to the same future real thread. Choosing `New thread` explicitly
  again creates an independent context. No fabricated server thread IDs.
- Once enqueued, recipients and New configuration are frozen. Later draft target
  changes cannot mutate an already pending context; an explicit independent New
  is required for a different project/model. Background receipts never move UI.
- Retargeting an enqueued item requires confirmed nonacceptance or a durable
  abandoned-operation fence from BB before creating a replacement operation.
  Missing acknowledgements and best-effort cancellation are insufficient. Keep
  original audio/identity while acceptance is unknown; received items are repaired
  on BB, never silently sent somewhere else.
- Per-recipient Send order is preserved, including audio that finishes uploading
  out of order. Separate existing threads and independent New contexts progress
  independently. A failed earlier ASR may be explicitly skipped/repaired on BB;
  no silent reordering of later messages.

## 5. Navigation and visual behavior

The [design contract](../design.md) must enumerate every exit and return path.
One full-screen recording surface, native list navigation and focused system
sheets; no custom stack of rounded pseudo-phone screens. Short English UI copy.
Black base, white text, sparse lime accent, red only for capture controls.

A sheet has an ordinary visible Close (X). It closes that sheet, returns to the
same parent/draft/scroll position and never starts or resumes recording, selects
a value, sends, deletes, or navigates to a different root. Sheets have no navigation hierarchy and no Back. Picker selection commits one
chosen value and returns to the recorder. Dismissal without selection leaves
values unchanged. Recordings/detail/settings use native pushes and Back pops the
actual invoking path. No microphone button masquerades as dismissal; the chooser
is opened by its visible row, without a custom swipe shortcut.

Recorder mode, icon changes, captions, haptics and accessibility labels agree.
One small truthful stage caption is allowed for ambiguous transfer/failure states;
no giant status word, fake percentage, meaningless waveform or looping pulse
that implies live input when none exists. Short opacity/content transitions,
Reduce Motion, Dynamic Type, VoiceOver and Always On are part of acceptance.
At default text size on 49 mm and the supported smaller watch size, the first
recorder viewport shows recipient, recording/pause/resume and available Send
without scrolling. Optional New fields and history do not push primary controls
out of view. Larger accessibility text scrolls naturally with the Crown.

## 6. Ownership and receipts

| Fact | Owner and observable evidence | Watch presentation |
|---|---|---|
| Audio checkpointed | Watch durable draft and finalized original parts | Saved locally |
| Explicit Send persisted | Watch immutable manifest + recipient + operation ID | Queued |
| Transfer scheduled/in progress | OS task + reconciled acknowledged bytes | Waiting / Sending |
| Plugin holds all audio | Durable receipt with recording ID, validated manifest/hash, target/context and job ID | Received by BB |
| ASR pending/running/failed | Plugin durable job, retained original | Detail only, no main-screen dependency |
| Transcript accepted as BB input | Verifiable dispatch acknowledgement or reconciled core record | Detail only |
| Dispatch acceptance unknown | Plugin retains operation and pauses automatic dispatch | Needs attention on BB |

Do not translate `Received by BB` to agent `Done`. Duplicate receipt/status
queries are safe. An upload receipt lost in transit is reconciled by the stable
recording ID. A retry of the same recording cannot create a new BB processing job.
There is one processing job per recording: the receipt's `jobId` equals its
`recordingId` and remains stable through transcription retries.

The plugin may not claim exactly-once thread mutation without verified BB-side
idempotency/reconciliation. It must durably mark the dispatch boundary, preserve
actual acknowledgements, and stop replay after ambiguous acceptance. This is a
release-critical capability/limitation, not an undocumented retry policy.

## 7. Failure, storage and recovery

- No arbitrary duration limit. Chunked originals support long speech and crashes;
  finite storage/network limits are explained honestly. Low space stops capture
  safely with a useful message and keeps all already finalized parts.
- A four-minute bilingual recording must remain complete and ordered. Interruptions
  cannot silently omit a middle segment or submit a partial transcript as complete.
- Partial upload, lost receipt, URLSession task loss, OS termination, process death,
  restart, pairing revocation and plugin reload have explicit recovery states.
  The OS may not resume a user-force-quit app without relaunch; the app must not
  pretend it can reliably detect why it cold-started. Every cold start reconciles
  task and server receipts before recreating any upload.
- The watch retains originals until a verifiable durable plugin receipt; a later
  automatic cleanup requires a documented retention policy, never mere HTTP 200.
  First release defaults to explicit local deletion, outside the primary flow.
- Delete is separate from Close. An unsent draft can be deleted after explicit
  confirmation. Enqueued audio is retained until receipt or a confirmed durable
  abandon; no acknowledged parts does not prove that no data was received.
  A received local copy can be deleted with an explicit non-retraction label;
  deleting desktop audio or a dispatched prompt is a separate BB action.
  Uncertain acceptance cannot be presented as safely canceled or unsent.
- Audio retention/deletion never removes the deduplication fact or permits an
  old signed/in-flight operation to become a fresh processing job. Receipt and
  abandonment tombstones outlive the audio according to a documented policy.
- ASR failures retain desktop audio and completed results. Retry occurs on the
  computer and does not re-upload or create an extra agent turn. Corrupt/truncated
  audio is rejected before a success receipt; compatible complete chunks remain.
- Re-pair/account switch freezes old-account work and explains it. No cross-account
  migration/rebinding of queued audio, credentials or cached thread choices.
- Server size/codec/concurrency/retention limits and storage-full behavior are
  documented and enforced without turning a technical per-file limit into an
  arbitrary maximum recording duration. No hidden public audio URLs.

## 8. Pairing, privacy and identity

Pairing belongs to the plugin: the computer presents a short one-time code;
exchange returns a revocable per-watch credential limited to this interface,
plus verified instance and intake-host identity. The exact remote admission/auth
protocol must pass the architecture's proof gate. Do not assume a core mobile
session or plugin-wide master token provides the required per-watch scope. Keys
remain in Keychain and supported private BB/plugin storage.
No raw credential files, ASR keys or full workspace tokens in the watch UI/logs.

Pairing identifies the actual BB instance/account and intake host, not just a
friendly label. Upload/status calls enforce device authorization and target
ownership. Audio, transcripts, user titles and sensitive URLs are excluded from
diagnostic logs and public build artifacts. The desktop plugin names the configured voice service and clearly explains
hosted ASR when selected: orchestration on the computer does not imply local
inference or prevent audio from reaching that configured service. Raw voice is not an instruction to
change routing, credentials, approval policy or the processing pipeline.

## 9. Measurable acceptance for the first complete release

| ID | Observable acceptance |
|---|---|
| V01 | After system microphone consent, a user starts recording in one tap without choosing a thread, model or connection; denied/unavailable microphone has a truthful recovery state. |
| V02 | Pause/resume creates one coherent ordered recording; explicit Send during either state retains all finalized parts. |
| V03 | Every single-level picker X dismisses without target/audio mutation; selecting commits one value; native Back on pushed pages returns to the actual invoker. Search or replay cannot steal the recording mic without an explicit pause. |
| V04 | No watch process/transport request performs ASR or calls an ASR provider. With provider unavailable, audio still obtains a BB durable receipt. |
| V05 | On real Ultra 2, explicit Send then wrist-down completes delivery when the OS/network permits; status reconciles after reopening without another Send. Record actual timing and OS deferral. |
| V06 | Interrupted upload and lost receipt recover under the same recording ID; one audio intake/job exists and originals stay intact until receipt. |
| V07 | Four-minute Russian/English audio is durably received complete, transcribed on the computer in correct segment order, and becomes one BB message; reported duration/frame count detect omissions. |
| V08 | Computer asleep/offline shows queued local audio; making BB reachable resumes under the same operation ID. No nearby iPhone is needed. |
| V09 | Two sends to one target stay in Send order; a slow/failed target does not block a different target. |
| V10 | Follow-ups to pending New resolve to one real thread; explicit independent New creates a separate context. Wrong-account or unauthorized targets never receive audio. |
| V11 | Plugin restart recovers originals, completed ASR groups and receipts; ambiguous send/spawn never automatically duplicates a message. Deletion/retention cannot erase deduplication or abandonment fences. |
| V12 | Recorder is ready for another draft after enqueue; an explicit secondary action also parks an unsent draft without Send/delete. Restoring a draft is deliberate; receipts cannot alter its target. |
| V13 | Largest supported Dynamic Type is usable by Crown scrolling; primary controls are reachable; VoiceOver, Reduce Motion and dimmed display match actual state. |
| V14 | Every picker has visible Close and no Back; each pushed page has native Back. Primary recorder controls fit the default viewport, without a decorative phone frame, dead regions or hidden-only actions. |
| V15 | Revocation and account switch do not leak/rebind old queued recordings; neither diagnostics nor distributed artifacts contain private audio/transcripts/credentials. |
| V16 | A fresh source checkout builds both plugin and watch; deterministic lifecycle/failure checks and actual-device transfer evidence distinguish implementation from completion claims. |

Before setting performance targets, measure enqueue responsiveness, uploaded
bytes, foreground/background receipt latency, desktop ASR and core acknowledgement
separately. Release evidence includes four-minute real-network wrist-down cases;
a simulator upload or tiny foreground recording is not equivalent acceptance.
No spinner-only success claim and no general latency promise from two samples.

## 10. Approval and clean implementation boundary

Current stage: spec/design/architecture review only. Fable must critique product
scope, every navigation path, watchOS HIG, accessibility, background feasibility,
plugin/API assumptions, failure recovery and the implementation plan. The lead
must verify claims against actual SDK/types and resolve review findings.

Only after the package is agreed should an isolated rewrite worktree be prepared
and Astra started with the new approved documents, verified public contracts and
owned assets. Preserve the current released checkout, app data, signed artifact
and source history. Remove legacy implementation only inside that rewrite
worktree. Do not pass old source, incident transcripts, old prompts or legacy
designs to Astra as reference. A neutral migration requirement for existing
recordings is a product contract, not permission to silently delete user data.

Open release gates: plugin transport/auth SDK feasibility; dispatch dedup/reconcile
contract; runtime proof of New creation reconciliation; recording-background capability;
measured local/desktop storage limits; tested neutral migration/recovery contract. These
are explicit go/no-go gates in the implementation plan. A reviewed plan may
start bounded Phase 0 proofs; full implementation cannot build around a failed
or unresolved platform/auth/dispatch contract.
