# BB Quick Voice — minimal version

Updated 19 October 2026. **Product/design proposal for the latest user request; not an
implemented or hardware-validated build.** This refines the
[voice-notes direction](bb-watch-voice-notes-direction.md). The older 2.0
Finish/Send and mandatory-recipient flows are not this variant's contract.

[Four-state concept](../docs/design/quick-voice.png) ·
[Generation brief](../docs/design/quick-voice-prompt.md).

## The entire normal experience

1. Press the configured Ultra Action Button. It opens BB and begins a new Auto
   recording without another screen tap, after microphone consent/setup.
2. Say the thought and its destination: an existing thread or a project for a
   new thread. Speak naturally; no routing form is required.
3. Tap the one **Finish & send** control. Capture ends, audio is safely queued,
   and compressed files begin background delivery as scheduling/network permit.
4. Put the wrist down. BB receives the audio, decodes and transcribes it, then
   Jev-assisted routing selects the thread/project and applicable model policy.

Two deliberate controls in the normal path: start and finish. Finishing is
explicit authorization to send; there is no additional Save, Confirm, Send or
transcription waiting screen. Regular app launch alone does not turn on the mic.
An interruption, timeout, app exit or Pause never stands in for Finish & send.

## One screen

Large lime capture control (`#D5FF00`, matching the existing BB Watch accent);
its selected destination **below** it; history further
down by Crown scrolling. Idle is still. Live capture has a restrained lime
halo driven by actual microphone level, not a looping fake waveform. A small
elapsed time is secondary. During capture the control's stop symbol has the
short visible caption Finish & send so transmission is not disguised as Save.
The stop glyph is black on lime. Capture remains distinguishable from a receipt
by shape, placement, caption and motion; color alone does not signal recording.

After enqueue, the same screen is ready for the next thought. The first history
row is the latest receipt, not a separate shortcut or modal. Ordinary captions:
Saved locally, Queued, Received by BB, Needs attention. Thread names update only
when known; Received by BB proves stored audio, not delivery to an agent.

Pause/resume and parking an unsent thought remain secondary actions, outside
the default two-control path. They preserve interrupted/offline thoughts; no
automatic sending because the user stopped speaking or left the app.

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

An in-app follow-up still addressing the same pending New context resolves to
that same future thread. Tapping New thread again explicitly starts an independent
context. The dedicated quick-start shortcut still starts Auto as described above.
An ambiguous create result is reconciled, never automatically spawned again.

## Recommended technology

| Boundary | Choice | Reason / qualification |
|---|---|---|
| Watch UI | Native SwiftUI, small custom amplitude-driven control | Independent LTE watch app; no web renderer or generic animation dependency |
| Quick launch | Action Button → selected Shortcut → normal foreground AppIntent | [Apple supports Shortcut on the Action Button](https://support.apple.com/en-gb/guide/watch/apda005904ef/26/watchos/26); on watchOS 26 use [foreground supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes-5zhmb). First audio, not intent completion, establishes success |
| Capture | AVFoundation with continuous input and durable local chunks | Retain recoverable originals; chunk boundaries must not introduce speech gaps. Do not assume restarting AVAudioRecorder is gapless |
| Transfer compression | Evaluate AAC-LC, mono, 48 kHz, 64 kbps, sealed M4A parts | Native codec candidate with explicit settings. Derive compressed files off the UI actor; preferably finish sealed derivatives during capture so Finish does not trigger a whole-recording encode |
| Network | One background URLSession, file-backed uploads, stable recording identity | [Apple distinguishes background transfers from async requests suspended with the app](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask). Persist the outbox before showing Queued; no iPhone relay dependency |
| Plugin | Durable intake → decode to PCM16 WAV → BB voice service → Jev routing → BB send/spawn | Transport codec is independent of ASR input. Routing does not need to run on the watch or delay its audio receipt |

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
