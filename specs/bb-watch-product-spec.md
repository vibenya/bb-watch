# BB Watch — voice terminal

Version 3.0 · 19 October 2026 · **Consolidated behavioral contract; not implemented or hardware validated.**

This is the canonical product specification. [Design](../design.md) describes its
presentation; the [transition/error contract](bb-watch-transition-contract.md)
defines event ordering and recovery. The previous [2.0 product contract](archive/bb-watch-product-spec-2.0.md)
and design iterations are historical. Their reviews do not approve this revision.
Installed source remains 0.2.0 with [contract 1.2](archive/bb-watch-product-spec-1.2.md).

## 1. Job and product boundary

When I have a thought or want to reply to an agent, I want to record it and send
it from my watch, so I can return to real life with little screen interaction.
The routine is **record → send → record → send**. Read messages in full BB and
ordinary notifications; the watch is not another workspace or chat reader.

The product comprises a standalone native watchOS voice terminal and a BB plugin
on the computer, an external input adapter like a Telegram connector. The watch
owns capture, recoverable original audio, recipient intent and durable delivery.
The plugin owns audio intake, decoding/transcription, Jev-assisted destination /
model selection and BB submission. Provider keys and ASR calls stay off the watch.
Computer-side orchestration may use configured hosted services; it is not a claim
of fully local inference. The computer may be asleep or unreachable; the product
does not claim to wake it or require a nearby iPhone.

**Audio acceptance, transcript acceptance and thread activity are different facts.**
The plugin's durable complete-audio receipt ends the watch's transfer ownership;
it does not mean that ASR, routing, an agent turn or the agent task succeeded.

## 2. Two watch surfaces

1. **Recorder:** input controls and exactly one lower thread/context component.
2. **Threads:** one sheet for context selection, with optional inline expansion
   of the current thread's short original activity/message excerpt.

No recording history, playback, delivery-detail page, separate Reply, New-thread
wizard, project/model form, conversation reader, answer speech, agent summary page
or question-choice workflow. New tasks/projects/models are requested in speech
or configured in full BB. Native permissions, first pairing, discard confirmation
and exceptional actionable alerts are allowed; they are not everyday navigation.

The ordinary recorder has no Recording title, Received by BB / Resolve on BB
copy, Send label, elapsed recording timer, fake percentage or decorative halo.
Rare failures may use short English recovery copy; icon-only normal UI must not
make errors inexplicable. Audio duration may exist internally for integrity checks.

## 3. Record, stop, append, send

| Stable compose state | Visible controls | Intent |
|---|---|---|
| Empty | Dominant lime microphone | Begin a fresh draft |
| Recording | Real left-to-right waveform; X / filled square / lime curved Enter | Discard / stop-save / send directly |
| Stopped | Static waveform; X / **red REC with contrasting filled-circle glyph** / same Enter | Discard / append / send directly |

The initial microphone remains lime. After Stop, the center button is red classic
REC, never microphone, Play or a second send control. REC appends to the **same**
draft ID, preserving all previous audio and its context. Starting a new input
segment cannot overwrite an earlier part. Intentional stopped time is not speech
and must not turn into a fabricated silent recording segment.

Square stops input and checkpoints locally without sending. Enter finishes and
queues directly from live or stopped state; a separate pause/confirmation is not
required. Curved Enter matches BB's return-arrow send vocabulary; a checkmark or
up arrow is not an equivalent action glyph. X checkpoints/stops before asking
to discard nonempty audio; rejecting discard leaves the same draft stopped.

Pending activation/first input, checkpoint, append activation and finalization
are explicit transient states, not fake stable states. No waveform or start
haptic claims recording before actual input. No Send before the first
usable audio; the initiating gesture cannot also send. Stop, REC, Enter, X and
context selection cannot race into two owners or duplicate operations. The
transition contract defines the guard and recoverable outcome for each event.
Every transient has a bounded safe exit. Local restoration never waits for
network receipt reconciliation; one corrupt old operation cannot trap the whole
app in a spinner. If safe local storage/ownership cannot be established, expose
short actionable recovery with input blocked, not a false ready state or an
automatic destructive reset. Preserve source and drain old owners before retry.

For a paired connection, Enter freezes audio, exact routing intent, pairing
identity and Send order into one durable outbox operation. Without pairing, Enter
only stages local audio with BB routing intent: it cannot upload. After setup,
an explicit Send confirmation binds those staged items to the displayed
connection; entering the pairing code alone never flushes them. Already bound
work is never rebound through that confirmation. **Only durable enqueue frees compose** for the next
thought. A failure before that boundary restores retained stopped audio; a crash
across it reconciles identity, never offers the same audio as a fresh unsent send.
Returning to ready is not a delivery-success claim. ASR, routing and network wait
never block the next fresh recording after enqueue. No silence, dismissal,
interruption, backgrounding, context switch or app exit implicitly sends.

Ordinary launch restores context/draft with mic off. An explicitly configured
quick-start starts or appends within the visible context after authorization /
permission; during active capture it reveals that capture, never sends or starts
a second mic. Appending a retained thought is deliberate behavior: the visible
context and stopped waveform identify it, and actual capture gets its own haptic.
No custom second physical Action Button press is assumed proven.

## 4. The sole lower thread/context component

For a bound thread: actual title, activity icon and disclosure affordance. These
icons represent actual BB idle/working/question/done/failure state, not audio
upload, ASR or receipt. Stale/unknown data is neutral, never fabricated Done.
The same component remains in place across recorder states.

For unbound routing: **BB** plus a routing glyph, not Auto, New or an unrelated
last-used thread. A later route/receipt never switches the current context. A
resolved target can be selected through Threads or an authorized notification
link; it is not silently adopted while another recording is being composed.

Context is either unbound BB routing or an exact authorized thread ID, scoped to
the paired BB instance/account. A manually chosen or notification-linked thread
persists across repeated record/send until explicitly changed, including quick
start. Jev must not silently override it. Spoken conflicting routing is held for
resolution rather than sent to a different chat. In unbound mode, spoken thread /
project intent is resolved against authorized candidates; ambiguity is not a
permission to guess the last active thread or create an unrelated project.

## 5. Threads, context changes and reply links

Tap the sole row to open one sheet with visible Close X. The current context,
recent authorized threads and BB routing choice are available. Tap another choice
to commit it and dismiss; current-row disclosure expands a bounded original BB
excerpt inline. Expanding, collapsing and Close never start capture/send.
No nested sheet, extra reader route or hidden-only gesture is required.

Opening/closing the sheet preserves context, input ownership, draft and focus.
Selecting a different context checkpoints/stops current audio before committing
the switch, retains the stopped draft in its original context and restores any
existing stopped draft in the destination. **One editable draft per context**;
returning to that context exposes its red REC and Enter. Same-context selection
is not a duplicate-draft action. The sheet indicates retained drafts without a
recording-history page. A failed checkpoint cannot silently finish the switch.

An inbound reply link opens this same recorder for its exact authorized thread;
it is not implicit authorization to record, send, discard, retarget existing
audio or grant broader permissions. It follows the same context/draft rules.
Duplicate, stale, deleted, unavailable and cross-pairing targets have bounded
truthful recovery, never title matching or fallback to a different recipient.
A link during finalization cannot modify an already frozen operation.

Phone notification URLs are not assumed to launch a standalone watch remotely.
Watch launch/URL routing, payload identity, auth and cold/warm behavior require
actual integration proof. No existing scheme/notification support is invented.

## 6. Durable delivery and computer-side processing

A stable recording/operation identity survives retries, app/process death,
background-session reconciliation and lost receipts. The plugin accepts frozen
**routing intent**, including unbound BB, before ASR determines a final target.
Audio intake is idempotent for the same immutable operation; querying/retrying
its same identity cannot create another processing job.

The receipt proves complete validated audio, immutable manifest/identity and a
recoverable plugin job. Uploading all bytes or obtaining an arbitrary HTTP 200 is
insufficient. The received compressed representation is not falsely described as
bit-identical PCM original. Retain local originals until verified receipt. After
that receipt, local audio is eligible for bounded automatic storage reclamation;
unsent, unaccepted and uncertain audio never is. Keep a durable receipt/order
ledger when bytes are reclaimed. The plugin retains accepted source through
unfinished or failed processing; expiry cannot strand an active recovery job.
Deduplication/order/abandonment facts outlive bytes. Unknown acceptance is never
treated as canceled/unsent. Quota/reserve thresholds are measured release gates.

Compression is required for the intended delivery path. AAC-LC sealed M4A is a
candidate, not an accepted default: earlier direct-AAC trials lost English; the
new candidate decodes on the computer to PCM16 before BB ASR. Validate RU/EN,
names/numbers/negations, duration/frame order, decoder priming/padding and part
boundaries against the same PCM source. No lossy release before that gate; no
silent replacement by an uncompressed release or general speed claim.

The plugin retains received source, ordered complete ASR results and one durable
routing/model decision per operation. A failed segment cannot disappear or make
partial text appear complete. Existing-thread policy and explicit exact IDs are
preserved. Jev candidate authorization, confidence, project/model mapping and
new-thread creation/reconciliation need verified contracts, not an assumed router.

Persist Send sequence at enqueue. Preserve order where jobs share an actual
recipient, including late ASR/routing and unresolved BB jobs. An earlier unbound
job that might address a later job's target is an ordering barrier until resolved
or explicitly released on BB. Known independent recipient lanes can progress
independently. Do not promise both unrestricted independent progress and strict
order while an older destination is unknown. Neither barrier blocks recording.

Idempotent audio intake is distinct from the BB mutation boundary. Without a
verified core idempotency/reconciliation contract, ambiguous send/spawn acceptance
stops automatic replay and requires reconciliation on BB. A lost audio receipt
is reconciled under its original ID, never a fresh recording or extra agent turn.

## 7. Failures without a history application

The [transition/error contract](bb-watch-transition-contract.md) is normative for
permission/setup, activation, no input, storage, interruption, checkpoint, resume,
finalization, transport, receipt, auth, routing and core-acceptance recovery.
Normal UI remains two surfaces; exceptional short native recovery prompts may
refer to the affected context. Older pending/failed operations must remain
noticeable/actionable while a new context records; they cannot be overwritten by
the latest operation or hidden in a context no longer in the recent list. A fixed
input-owned issue indicator remains accessible during recording. It opens the
same Threads sheet with a conditional Issues row expanded. Only exceptional
items appear there; neither successful nor ordinarily progressing sends form
a history. Rare issue/setup text is allowed inside that explicit recovery UI.
After verified complete-audio receipt, ASR/routing/dispatch problems belong only
to full BB; the first release does not mirror them on the watch.

Input/capture faults and durable outbox issues belong to input recovery, never
the thread activity glyph. Recovery is bound to the affected operation/context;
a late error cannot steal focus, interrupt a healthy capture, select a recipient
or retry another job. Never create a new ID for audio whose seal or acceptance may have occurred.
Check again reconciles its original ID. Deleting a local copy in this state
warns both that unreceived audio may be lost and received audio may still send;
it preserves the unknown ledger and ordering barrier. No blind Send again. New audio capture must not be held
until slow network, ASR or an agent completes.

App interruption or storage pressure stops/checkpoints; reactivation restores
stopped/red REC, not automatic capture. Wrist-down and normal backgrounding alone
must not be interpreted as user Stop; legitimate background recording is a
hardware gate. Termination recovery preserves committed parts/aligned prefixes,
marks interrupted/incomplete audio honestly and does not silently submit missing
speech. Preserve known interruption/incompleteness and affected boundaries in
the immutable audio manifest through plugin processing; full BB can explain
missing audio. Intentional Stop alone is not incomplete. Appending does not erase
a known gap or fabricate replacement silence. Exact wire fields require proof.
No arbitrary duration cap; finite limits and low-space recovery are real.

Account/pairing changes freeze old-identity work without cross-account rebinding.
Unpaired capture may be locally saved, but its eventual binding/send requires
explicit authorized setup; entering a pairing code is not authorization to flush
all old drafts. Deleting drafts, revoking pairing and retargeting queued operations
have separate consequences. Original audio is never deleted to clear a badge.

Migration preserves legacy delivery meaning: previously accepted/unknown work is
not a fresh outbox item, and import never sends. Legacy BB prompt acceptance is
not proof of this plugin's complete-audio receipt; do not use it to auto-delete
old source audio under the new receipt cleanup rule. Truly unsent imported audio
requires a deliberate identity/target choice and explicit Send.

Pairing is plugin-owned with a short one-time setup code and revocable per-watch
scope, not a full workspace/master token. Keys remain in Keychain or supported
private plugin storage. Audio/transcripts/titles/credentials and sensitive URLs
never enter diagnostic logs or public artifacts. Diagnostics use scoped operation
IDs, state, error codes and stage timings; scene/identity values are current at
each event, not reused startup snapshots. Full BB names the configured hosted
transcription/routing services without implying offline-only processing.

## 8. Visual, motion and accessibility contract

Black/white neutral BB controls with lime start/Enter and red stopped REC. Waveform
represents actual input progressing left-to-right; it freezes/dims when stopped.
Keep X, center square/REC and Enter at stable positions. Microphone/record glyph,
color, waveform and accessible names agree; red alone is not the state signal.

Transitions must not move irreversible actions into the old hit area of a safe
action. An old touch, delayed callback or repeated tap cannot activate the next
state's action. Haptics/announcements reflect actual completed transitions, never
optimistic recording, enqueue, acceptance or thread activity. Long activation or
network work is represented honestly without fake progress/ETA.

Use short content/opacity transitions, stable focus and no decorative motion.
Reduce Motion has immediate/static equivalents; Always On never suggests live
input when none exists. VoiceOver labels Record, Stop and save, Continue recording,
Send recording, Discard recording and thread status. Dynamic Type, hit areas,
Crown scrolling and contrast are verified on supported real watch sizes; concept
images are not HIG/platform acceptance evidence.

## 9. Observable release acceptance

| ID | Given / when | Required observable result |
|---|---|---|
| P01 | Authorized empty compose → tap mic / quick-start | One mic owner; first real input establishes recording, no premature meter/haptic |
| P02 | Permission pending/denied or activation/no-input failure | No empty send or fake capture; retry returns to the same prior draft |
| P03 | Recording → square → red REC → Enter | Same draft, ordered old+new audio, no duplicate message or mandatory pause before send |
| P04 | Live → Enter; repeat tap/held gesture | One durable operation; next capture only after enqueue, initiating gesture never sends twice |
| P05 | Stop/resume/finalize/write/restore failure, timeout or crash at enqueue | Bounded truthful recovery without network-gated startup; retained audio has one owner, no editable copy of queued audio or destructive reset |
| P06 | Queue pending → new recording/send | New input remains usable; older delivery does not alter its target or microphone |
| P07 | Open/Close Threads, same/different context, checkpoint failure | No implicit send; same-context no duplicate; changed context retains/restores stopped drafts |
| P08 | BB unbound versus exact chosen target | One lower row, truthful glyph; only BB may semantic-route; exact target cannot be silently overridden |
| P09 | Delayed/stale/unknown/question/done thread update | Source-correct icon and focus stability; no upload/ASR stage disguised as agent working |
| P10 | Authorized reply link, cold/warm/duplicate/stale/revoked link | Same recorder/context; no automatic mic/send, wrong target fallback or discarded draft |
| P11 | Device offline/computer asleep, partial upload/lost receipt/relaunch | Same operation resumes/reconciles; no iPhone dependency or wake/ETA promise |
| P12 | Idempotent intake retry versus ambiguous BB send/spawn | One intake job; no automatic replay of an ambiguously accepted core mutation |
| P13 | Multiple contexts/jobs; old failure arrives during new recording | Affected job remains discoverable and recoverable without stealing capture/focus or a history page |
| P14 | ASR/provider/routing failure after durable audio receipt | Received source retained; no re-dictation/re-upload or false transfer failure; correct BB-side recovery |
| P15 | Earlier unbound/failed ASR then later exact/known independent recipient | Enforced Send-order barriers and independent safe lanes; no arrival-order submission |
| P16 | Four-minute RU/EN and longer segmented source; boundary/crash/interruption | Complete chronological source/text or explicit incomplete recovery; no silent middle omission |
| P17 | Screen asleep/background/force quit then restart | Measured hardware behavior; original/task/receipt reconciliation, no guessed termination reason |
| P18 | Low space or checkpoint truncation; confirmed/canceled discard | Preserve committed audio; no automatic deletion to recover capacity or badge; explicit incomplete status |
| P19 | Revocation/re-pair/account switch | Old work isolated, no credential/target rebinding or automatic flush |
| P20 | No history/playback/New forms; only record/thread surfaces | Current spec/design and all transitions reachable without resurrecting removed routes |
| P21 | Reduced Motion/Always On/VoiceOver/large text | Truthful state, stable native hit targets/focus and accessible red REC/Enter distinction |
| P22 | Fresh build/migration with real saved legacy audio | Neutral import preserves audio/delivery state; import never sends or deletes; no uninstall as repair |

Transition-contract scenario IDs supplement P01–P22. They are design acceptance,
not passing runtime tests. Measure first-buffer, stop/checkpoint, enqueue, watch
receipt, ASR and core acknowledgement separately; set release budgets from actual
device/network evidence, not inferred ASR samples or animation duration.

## 10. Before implementation/release claims

- Own per-watch authorization and scoped remote plugin admission, including
  actual file-sized bodies and account/host/instance checks.
- Real continuous capture, stopped/append continuity, interruption/crash and
  wrist-down behavior on standalone Ultra 2; measured storage and energy budgets.
- Compressed transport → decode → ASR quality/boundaries for RU/EN and long audio.
- Complete background declare/parts/seal/receipt under LTE, lost response, relaunch,
  force quit and plugin restart; OS may defer networking, no completion deadline.
- BB exact target/status/peek APIs, durable Jev routing/model and dispatch ledger,
  ordered unbound/exact jobs, new-thread unknown-acceptance reconciliation.
- Actual notification-to-watch context launch/auth and stale/duplicate-link cases.
- Storage/retention/quotas, actionable older outbox failures and safe legacy import.

The [2.0 engineering plan](bb-watch-architecture.md) is an inherited safety/platform
baseline, not an implementation plan for 3.0. Update/review its changed routing,
compression, notification and recovery contracts before a clean rewrite. The
current task changes documents only; no worktree, Astra implementation, device
installation, provider call or runtime gate completion is implied.
