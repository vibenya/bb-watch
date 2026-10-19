# Native Phase 0 proof harness

Fresh Swift 6 / SwiftUI watchOS 26+ target. Provisional identity:
`app.getbb.voiceprobe.phase0`, display name **Voice Probe**. Watch-only (`WKWatchOnly`); no companion target,
URL scheme, pairing, production service, Keychain credential or existing app data
is used. Signing is disabled. Lead owns any eventual signing/install window.

From the repository root:

```sh
xcodegen generate --spec native/project.yml
swift run --package-path native probe-checks
python3 native/scripts/codec_probe.py
xcodebuild -project native/VoiceProbe.xcodeproj -scheme VoiceProbe \
  -sdk watchos -destination 'generic/platform=watchOS' \
  -derivedDataPath native/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

This command builds without running a simulator or touching a physical device.
A separately authorized isolated simulator launch/recovery check is recorded in
the proof report; its window is now released. Generated
project/build files are ignored; `project.yml` is the project source. Host checks
create only synthetic temporary stores and kill only their own child executable.
No microphone, network, user recording, transcription or agent is involved there.

## Capture probe

`Core/CaptureStore.swift` owns the local ledger; `WatchProbe/CaptureWorker.swift`
confines it to one serial writer. PCM is float32, little endian, frame-interleaved,
with the input sample rate/channel count retained independently per segment.
The tap copies input into a bounded eight-buffer mailbox. Per-buffer source sync
precedes ledger sync/rename. No draft or recording feedback exists before real
input is committed. Empty activation makes no draft. Stop seals even 480 frames;
REC creates another part in the same draft with no stopped-time silence. The
sealed prefix receives a SHA-256. Original files are never automatically removed.

Enter only **stages locally**: one snapshot replacement removes the editable
draft and adds its immutable operation, recipient and sequence/predecessors.
No transport consumes this outbox. The probe has no pairing or binding UI.
Ordinary launch restores with mic off. Active attempts recovered after termination
retain their committed prefix and acquire a missing-audio boundary. Extra tail
bytes and failed temporary writes are retained, never guessed into speech.
Corrupt source is marked damaged; unreadable whole-store metadata blocks input.
A failed/uncertain write blocks further mutation; Retry queues readback behind the
old writer. Command and attempt IDs reject stale callbacks. A bounded UI wait
cannot revoke a still-running disk write; it exposes blocked recovery instead.

Probe safety settings (not approved G6 release budgets): 32 MiB reserve, eight
pending buffers, 8 s activation, 3 s no-input stall, 10 s writer/restore UI bound,
0.4 s control re-arm. The native permission prompt is allowed to wait for its
user. Capture has no elapsed timer or intentional duration cutoff. Per-buffer
sync cost, full-part seal/recovery hashing, ledger growth, 32-bit integer/file
limits and storage/energy behavior still need measured release engineering.

`WKBackgroundModes: audio` is used only for real recording. No workout, silent
playback or extended runtime session is used. Wrist-down/inactive does not Stop;
actual background cancels pending activation, while established input is probed
until interruption, input loss or user stop. This is code, not proof of G3.

The tiny UI has a waveform, center mic/square/red REC, local staging arrow and
BB label. It is deliberately not the full recorder/Threads product: no discard,
Threads catalogue, issues sheet, imported recordings, history or playback.

## Explicit Shortcut entry

`StartVoiceProbe` uses `AppIntent.supportedModes = .foreground(.immediate)` and
local device authentication. A user-assigned Shortcut is the intended Ultra Action
Button entry. It requests mic permission from that invocation, then starts or
appends within the current context. Live/transient quick-start does nothing to
input or send. Deferred startup expires rather than starting much later.
New capture uses `.start`, append `.retry`, only after the first committed real
buffer; append posts an accessibility announcement. Actual haptic/VO distinction,
watch Shortcut discoverability, locked-device authorization and cold/warm first
press are **not run**. No custom second-press action is donated.

The SDK deprecates `openAppWhenRun` and `ForegroundContinuableIntent` at watchOS
26. The direct workout/dive Action Button protocols are not recorder shortcuts
and are not adopted. Generic URL entry is absent and cannot start recording.
`AudioRecordingIntent` is not used; its system-activity obligations are a separate
platform surface, not a background keep-alive solution.

## Background URLSession fixture probe

`BackgroundProbe` recreates a stable background session, uses
`uploadTask(with:fromFile:)`, persists a planned body/hash before creating the OS
task, persists its task identifier before `resume`, and calls `getAllTasks` before
adopting work. Same-ID suspended tasks may resume; a missing task becomes
`needs-reconciliation`, never a new request. Unidentified/contradictory tasks are
canceled without authorizing replay. Delegate completion is retained for persistence; a failed write gets one serialized
readback/retry before completing the WatchKit background refresh. Persistent
failure explicitly logs unresolved observation and blocks new uploads. The task
plan stays durable/uncertain; a later launch reconciles without resubmission. The
OS budget is released even on this unresolved path, never called durable success. An HTTP 200 is
never a receipt. No source cleanup exists.

No endpoint is configured by default. `scripts/fixture_server.py` binds only an
OS-assigned loopback port and prints its URL after binding. For a future authorized
simulator window, set `ProbeLoopbackFixtureURL` in the generated probe Info.plist
source to that exact URL and rebuild. The optional **Fixture upload** button sends
only fixed synthetic bytes. The transport class rejects non-loopback URLs.
This sink is not the plugin protocol and its response proves no durable audio
acceptance. A physical watch cannot reach the Mac through its own loopback:
the lead must hand off a dedicated authenticated fixture origin and adapt the
allowlist before a physical transport test. No production route is invented.

Apple documents OS deferral and user-force-quit limitations. No wake deadline,
LTE completion, taskDescription persistence, upload response delivery or complete
multi-step declare/part/seal/status chain is claimed from compilation.

## Offline codec probe

`codec_probe.py` generates short mono and stereo PCM16 tones with ordered
frequency boundaries, retains WAV originals, encodes separate AAC M4A candidates
and decodes to PCM16 with Apple's `afconvert`. It checks original hashes, playable
frames/rate/channels and waveform correlation. Explicit AAC rate is necessary;
the tool's implicit default changed the rate in the first exploratory run.
This is a host codec experiment, not a watch encoder or RU/EN speech-quality gate.
It is not connected to capture, the proposed shared schema or transport.

See [Phase 0 evidence](../proofs/watch/phase0.md) and
[physical acceptance steps](../proofs/watch/hardware-acceptance.md).
