# BB Quick Voice — minimal version

**Latest capture-control override:** [BB composer v5](../docs/design/bb-composer-v5.md).
Start → Enter sends directly; square stops/saves locally; X discards. Use BB's
left-to-right waveform without Send text or recording timer. This supersedes
the capture-control descriptions/art below; routing/delivery invariants remain.
The old Fable approval does not cover this user-directed revision.

Updated 19 October 2026. **Product/design proposal for the latest user request; not an
implemented or hardware-validated build.** This refines the
[voice-notes direction](bb-watch-voice-notes-direction.md). The older 2.0
Finish/Send and mandatory-recipient flows are not this variant's contract.

[Capture-state sheet](../docs/design/quick-voice-states-v2.png) ·
[Generation brief](../docs/design/quick-voice-states-v2-prompt.md).
[Destination/history/Reply scenarios](../docs/design/quick-voice-interactions.md)
and the [fresh approval packet](reviews/quick-voice-approval-pack.md) define the
current review scope; the earlier 2.0 Fable verdict does not approve these changes.

## The entire normal experience

1. Press the configured Ultra Action Button. It opens BB and begins a new Auto
   recording without another screen tap, after microphone consent/setup.
2. Say the thought and its destination: an existing thread or a project for a
   new thread. Speak naturally; no routing form is required.
3. Tap the one **Finish & send** control. Capture ends, audio is safely queued,
   and compressed files begin background delivery as scheduling/network permit.
4. Put the wrist down. The watch shows Queued until a durable audio receipt
   arrives. The plugin decodes/transcribes received audio, then Jev-assisted
   routing selects the thread/project and applicable model policy. Wrist-down
   delivery timing remains a hardware gate, not an immediate-completion promise.

If Auto cannot resolve a destination, this version requires clarification in the
BB plugin on the computer. Watch detail says Needs attention / Resolve on BB;
there is no watch-side retargeting of an already-enqueued recording.

Two deliberate controls in the normal path: start and finish. Finishing is
explicit authorization to send; there is no additional Save, Confirm, Send or
transcription waiting screen. Regular app launch alone does not turn on the mic.
An interruption, timeout, app exit or Pause never stands in for Finish & send.

## One screen

Large lime capture control (`#D5FF00`, matching the existing BB Watch accent);
its selected destination **below** it; history further
down by Crown scrolling. Idle is still, with a black microphone glyph and VoiceOver label Record. Live capture has a restrained lime
halo driven by actual microphone level, not a looping fake waveform. A small
elapsed time is secondary. During capture the control's stop symbol has the
short visible caption Finish & send so transmission is not disguised as Save.
The stop glyph is black on lime. Capture remains distinguishable from a receipt
by shape, placement, caption and motion; color alone does not signal recording.

After enqueue, the same screen is ready for the next thought. The first history
row is the latest receipt, not a separate shortcut or modal. Ordinary captions:
Saved locally, Queued, Received by BB, Needs attention. Thread names update only
when known; Received by BB proves stored audio, not delivery to an agent.

### Pause, recovery and secondary controls

During live capture, a small visible two-bar Pause control checkpoints this draft
and turns the microphone off. The hero remains the Finish & send stop control.
Paused uses the same circle anchor, a static dashed ring, microphone glyph and
Resume caption, with Paused · m:ss (Paused · interrupted after an interruption).
Tapping it resumes this same audio; an outlined secondary Finish & send capsule
can send while paused. It sits below the destination pill, never at the former
Pause hit area: a second tap at Pause must not become an irreversible Finish.
Pause/Resume give a haptic on the actual state change. Neither action is confused
with idle Record.

A small root ellipsis opens one full-screen Actions sheet with X. New recording
parks a nonempty paused draft in history and returns to idle Auto; while live it
first checkpoints/pauses that same draft, never sends. Settings is a native pushed
page reached after Actions closes: pairing identity, storage and Forget pairing.
A selected paused draft also exposes Delete draft with confirmation. Dismissal
never performs an action. No hidden long press is required.

Saved locally rows are unsent drafts. Their detail offers Play, Continue and
confirmed Delete draft; Continue restores this draft as active **paused**, parks
any other nonempty paused compose, returns to root and leaves the mic off.
Finish & send is available there, not duplicated in detail. Empty composes are
never parked, listed or enqueued. Finish is inactive before the first audio
buffer, while permission is pending and while sealing/enqueueing.

Finish is immediate authorization once durable enqueue succeeds. This version
has no timed Undo or remote retraction. The visible Finish & send caption is the
mitigation for an accidental tap; deleting a copy cannot undo submission. A user
can correct the thought with another recording. There is no automatic pause on
silence and no arbitrary duration cap: quiet may be intentional. Actual input
start gives a haptic and truthful microphone indicator; OS interruption or storage
failure pauses safely. An accidental quick-start can therefore keep recording
until explicitly paused/finished or the OS/storage guard interrupts it. This is
an explicit tradeoff, not a promised unattended-recording safeguard.

VoiceOver labels follow state: Record, Finish & send, Pause, Resume recording.
Live capture remains visibly identified on all opened sheets/pushed pages, even
off root.
Reduce Motion removes the animated halo; Always On uses a static truthful state.
Use native scalable text and full hit targets; validate 49/45 mm and large text
with scrolling rather than shrinking controls. Unpaired capture is local; Finish
retains a durable outbox item marked Needs attention · Pair BB. Permission denied
shows Microphone access required and cannot start or enqueue empty audio.

## Auto and manual control

- Quick-start shortcut creates an **Auto** draft. If a different draft is paused,
  park it intact. A repeated start while already recording opens that recording
  rather than starting a second microphone or implicitly sending it.
- In-app Record uses its visibly selected destination. Tapping the destination
  opens a single-level chooser with X: Auto, recent exact threads, New thread.
  Choosing/dismissing a recipient never sends audio.
- Manual selection or Reply from history pins the exact thread and bypasses
  semantic destination selection. Reply prepares the compose context; Record
  begins capture. Explicit model intent, if supplied through manual controls,
  cannot be silently overwritten by Jev.
- Spoken project routing creates a new thread in that validated project when
  requested. Explicit thread requests resolve against authorized candidates;
  ambiguity retains audio for clarification, not a guess at the last active chat.
- Plugin persists one destination/model decision per recording before submission.
  Keep original transcript, per-recipient Send order and no automatic replay
  after ambiguous BB acceptance. Existing thread execution policy is preserved.

### What New thread does

1. Tapping New thread closes the destination chooser and returns to the same
   recorder/draft. The destination below the capture control reads New thread.
   No microphone starts, no audio is sent and no BB thread is created by this tap.
   If capture was live, it stays live; navigation itself does not toggle capture.
2. This is explicit **force-new** intent, unlike Auto, which may choose an existing
   thread. There is no mandatory project/model form or required title. The user
   may say the project in the recording; an optional explicit project/model
   choice remains available as a manual override, not an extra compulsory step.
3. Finish & send freezes that New context and any explicit overrides. After
   durable audio intake and transcription, the plugin resolves the project and
   model subject to the overrides, then creates one new thread with the complete
   first message. Spoken existing-thread wording cannot silently override the
   explicit New choice; a conflict is held for clarification.
4. If the project cannot be resolved confidently, keep the audio/job and request
   clarification rather than choosing an unrelated project. Show the actual
   thread title in that recording's history row only after it exists.

### Destination lifetime and optional overrides

Auto stays Auto after durable enqueue. An exact manual target or Reply pin applies
to **one compose only**; after enqueue the root returns to Auto. Until enqueue,
pause/navigation preserve it. The visible pill is always the authority for the
next in-app Record; no hidden time-based stickiness.

New is the explicit exception for multi-part briefs. Before its first enqueue,
the pill is To: New thread. Afterward it is To: Pending thread, then To: <title>
when resolved, with an explicit-context pin. Frozen In/Model metadata distinguishes
this persistent context from a one-compose Reply pin. While that context remains selected,
in-app recordings are follow-ups to the same future/existing thread. Choosing
Auto, another thread, New thread again, New recording, or the quick-start shortcut
leaves it; New thread again creates a distinct local context. While selected,
Destination shows this same New/Pending context as a checked row above the separate
New thread action (e.g. Pending thread · Studio), so creating another context is
unmistakable. A pending-New history
detail has Add recording (not Reply): restore that authorized local context as an
idle compose, mic off, preserving its dependency. Once a real thread ID is known,
Reply uses the ordinary one-compose rule. Ambiguous create results are reconciled,
never automatically spawned again.

Only for a selected New context, root offers two secondary rows below its pill:
In: Auto project › and Model: Auto ›. Each opens its own single-level sheet with
X after any prior sheet is closed. Selecting a project/model commits that value
only; X changes nothing. Model choices are scoped to the selected project and
show provider identity where necessary. With Auto project unresolved, Model remains
Auto; its sheet offers Auto and explains Choose a project on the recorder to
select a model. It cannot launch a project picker from inside that sheet. Changing project clears an incompatible
model to Auto with a visible note, never silently substitutes another explicit
model. These rows are optional, do not block Record/Finish and never create/send.

After the first enqueue, show the same rows as frozen metadata with no chevrons
and Settings fixed for this thread. Auto project may show Resolving project until
known; Model: Auto means frozen automatic policy, not an invented resolved model.
To change frozen settings, deliberately choose New thread for an independent
context. Exact existing-thread/Reply picks preserve that thread's execution policy;
these New-only rows are absent. Plugin settings expose configured hosted ASR and
routing services: processing on the computer does not imply wholly offline AI.

## Recommended technology

| Boundary | Choice | Reason / qualification |
|---|---|---|
| Watch UI | Native SwiftUI, small custom amplitude-driven control | Independent LTE watch app; no web renderer or generic animation dependency |
| Quick launch | Action Button → selected Shortcut → normal foreground AppIntent | [Apple supports Shortcut on the Action Button](https://support.apple.com/en-gb/guide/watch/apda005904ef/26/watchos/26); on watchOS 26 use [foreground supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes-5zhmb). First audio, not intent completion, establishes success |
| Capture | AVFoundation with continuous input and durable local chunks | Retain recoverable originals; chunk boundaries must not introduce speech gaps. Do not assume restarting AVAudioRecorder is gapless |
| Transfer compression | Evaluate AAC-LC, mono, 48 kHz, 64 kbps, sealed M4A parts | Decoder must honour priming/padding and retained sample ranges, or encode continuously; decoded part boundaries must match the original timeline without gaps/overlap. Native codec candidate with explicit settings. Derive compressed files off the UI actor; preferably finish sealed derivatives during capture so Finish does not trigger a whole-recording encode |
| Network | One background URLSession, file-backed uploads, stable recording identity | [Apple distinguishes background transfers from async requests suspended with the app](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask). Persist the outbox before showing Queued; no iPhone relay dependency |
| Plugin | Durable intake → decode to PCM16 WAV → BB voice service → Jev routing → BB send/spawn | Transport codec is independent of ASR input. Routing does not need to run on the watch or delay its audio receipt |

Apple documents AAC priming and remainder samples; decoding must trim these to
preserve the source timeline ([AAC encoding background](https://developer.apple.com/documentation/quicktime-file-format/background_aac_encoding)).
This is why part-boundary integrity is a separate proof, not an assumption from
gapless PCM capture.

At the proposed constant 64 kbps payload rate, four minutes is approximately
1,920,000 bytes plus container overhead, versus 23,040,000 PCM16 bytes at 48 kHz
mono: about 12× smaller. This is bitrate arithmetic, **not measured upload speed,
latency, energy or recognition quality**. Final codec settings depend on proof.

Earlier direct-AAC ASR trials omitted English while PCM16 was complete. The new
proposal therefore decodes the received AAC on the computer before ASR; changing
an extension is not decoding. Decoding cannot restore compression loss, and this
proposal is not validated merely by the earlier PCM16 result. Keep the original
local chunks and the received compressed source; do not enable lossy transport
until the bilingual end-to-end gate passes. The compressed requirement remains
open if it fails; do not silently replace it with an uncompressed release.

Do not use AudioRecordingIntent as an assumed watch recording shortcut: Apple's
[protocol documentation](https://developer.apple.com/documentation/appintents/audiorecordingintent)
requires a Live Activity; a working standalone-watch path has not been established.
The normal foreground-intent route is the conservative candidate. Also, workout
or dive next-action examples do not prove custom second-press Stop behavior.

## Before implementation can claim this experience

- Warm/cold Action Button launch without nearby iPhone: measure press → first
  recorded buffer, record consent behavior, duplicate invocation and paused draft.
- Hardware wrist-down capture, interruptions, chunk continuity and crash recovery.
- AAC encoding/decoding on watch/computer, RU/EN coverage and ordering, long audio,
  negations/names/numbers; compare compressed→WAV against the same PCM source.
- Measure capture energy, compression backlog and Finish → durable enqueue,
  independently of network and ASR latency. No arbitrary recording duration cap.
- Real LTE file-backed delivery with screen asleep, dropped receipt and restart;
  minimize protocol round trips but prove complete intake, not just one upload.
- Jev target/model adapter: candidates, exact Reply priority, durable decisions,
  uncertainty, provider mapping and ordered dispatch. Existing local model-tier
  routing is a precedent, not proof of this adapter.

Second physical Action Button press to Finish & send is optional pending a real
device proof. The on-screen Finish control is the initial guaranteed design path,
not a measured implementation claim. No live ASR, device action or app build was
performed in preparing this version.
