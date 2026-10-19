# Native Phase 0 evidence — 19 October 2026

Owner: native implementation; lead owns integration and gate acceptance.
Scope: new `native/` and `proofs/watch/` only. No Git/index mutations or source
history inspection. This is a bounded implementation milestone, not product
completion or permission for full UI. Bead remains open under lead ownership.

## Environment and reproducible checks

- macOS host; Xcode 27.1 build 27A9275; Apple Swift 6.4 compiler in Swift 6 mode;
  watchOS 27.0 SDK, deployment minimum watchOS 26.0.
- Independent application `app.getbb.voiceprobe.phase0`, **Voice Probe**.
  Generic watchOS build with signing disabled; no signing/profile inspection.
  Subsequently, the lead granted one isolated synthetic simulator window; it is
  now released, with the owned simulator shut down.
- `native/README.md` contains exact generation/build/check commands.
- Revision evidence: `source-sha256.txt` hashes owned source files. No commit
  is made by this owner; lead serializes source integration.

| Check | Result | Evidence / limit |
|---|---|---|
| Swift host behavior checks | PASS | `host-checks.log`: real filesystem and actual child SIGKILL; no microphone |
| Unsigned generic watchOS build | PASS | `watch-build.log`; both arm64 and arm64_32, minimum 26.0 |
| Simulator build / isolated install / launch | PASS, narrow | `simulator-build.log`, `simulator-checks.log`; watchOS 26.1, ordinary empty launch + synthetic interrupted-draft restore only |
| Synthetic AAC encode/decode | PASS, narrow | `codec-host.json`; original retained, matching playable frame counts, correlation >0.99; no speech/ASR or watch encoding |
| Local synthetic HTTP sink | PASS, narrow | `fixture-host.log`; urllib PUT, not native URLSession execution |
| Native URLSession reconciliation | Compiled + ledger checks only | OS scheduling/delegate/process behavior NOT RUN |
| G3 / G4 / TG9 / TG10 / TG11 | NOT RUN | Exclusive hardware window not granted |
| Full product UI / protocol / codec acceptance | NOT IMPLEMENTED / NOT ACCEPTED | Explicit Phase 0 boundary |

The first sink trial found port 8765 occupied (401); the fixture server now binds
an OS-assigned loopback port and prints only after binding. No existing service
was stopped or reconfigured. The owned ephemeral fixture then passed and exited.

## Implemented evidence boundaries

- Original float PCM capture, one attempt/writer, bounded pending buffers, first
  usable input feedback, immediate short stop/seal, same-draft append, no silence
  insertion, stopped relaunch and interruption marks.
- Single-ledger atomic local staging with original operation identity, recipient
  and sequence. Unknown local write outcome blocks editing until serialized
  readback. No cleanup, rebind or network ownership transfer is implemented.
- File-backed background URLSession with durable body/task plan, stable session,
  `getAllTasks` reconciliation, task adoption/orphan rejection, HTTP observations,
  and WatchKit background refresh completion with explicit unresolved-write reporting. Default endpoint absent; only
  synthetic bodies can be requested by its explicit optional probe button.
- Foreground authenticated AppIntent/Shortcut entry with current SDK APIs.
  No generic URL scheme, direct workout/dive Action Button integration,
  notification context, ASR, provider key, agent send or custom second press.

Host tests protect observable ownership/data-loss risks: activation without audio,
short partial-buffer sealing, same draft across append/rate changes, stale input,
process restart/actual SIGKILL, durable sequence and enqueue, real filesystem
failure blocking/readback, adopted vs missing OS task records and no receipt from
HTTP success. They do not mock capture success or supply a production receipt.

The provisional native ledger is not the shared wire format. Sol's initial source
PCM hash/layout ambiguity was reported to lead; the revised per-part source
sample format/endian/layout/rate/channels/bytes/hash and per-part receipt frame
counts resolve that narrow issue. Exact frozen manifest-byte preservation fits a
file-backed JSON POST and raw file PUT. No protocol acceptance or production
transport wiring is inferred. Playable decoded frames/priming/padding reporting
still requires a schema revision before production receipt adoption.

## Apple API constraints

Installed SDK compile confirms AVAudioEngine input taps, current
AVAudioApplication permission API, watchOS asynchronous audio-session activation,
URLSession file upload and WatchKit refresh delegates are available. Compilation
proves declarations/type compatibility only.

- [AppIntent supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes): use foreground immediate on watchOS 26+. The SDK deprecates `openAppWhenRun` and `ForegroundContinuableIntent` at 26.
- [Apple Watch Action Button](https://developer.apple.com/documentation/appintents/actionbuttonarticle): direct next-action donation is associated with workout/dive sessions. This recorder uses the user-assigned Shortcut path instead, still awaiting actual Ultra 2 proof.
- [Background requests](https://developer.apple.com/documentation/watchos-apps/making-background-requests): background session lifetime differs from ordinary requests; response delivery may be deferred until activation. The article's download example is not proof of this upload chain.
- [Background transfers](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background): user-force-quit handling differs from OS termination; no unconditional transfer/relaunch promise.

## Remaining dependencies / next slice

Lead must grant the exclusive physical window and a fixture-origin handoff before
any installation/network configuration. G3/G4/TG9/TG10/TG11 and G6 budgets remain
open. Full UI, Threads, pairing/Keychain, accepted wire serialization, receipt
validation, production retry/abandon/order lanes and watch codec remain future
work after lead protocol/gate handoff. No user recordings or old app data were
read or modified.

Smallest next slice: instrument and run the independent capture/Shortcut probe
on the approved Ultra 2, then exercise a file-backed synthetic upload against a
lead-provided origin, including task creation and termination gaps. Stop if
capture or transport feasibility fails; do not unlock full UI through mocks.

## Independent review

One advisor pass found that a failed completion-observation write could be lost
while completing its WatchKit refresh, contradicting a durability claim. Fixed:
retain pending observations, retry after serialized disk readback, and explicitly
log unresolved persistence when releasing the OS budget on continued failure.
The durable original task plan survives; no success/receipt or new request is
inferred. A real filesystem-failure host check covers failed observation, failed
finish/readback, then successful persistence without replay. Physical delegate
ordering remains not-run. The advisor was called exactly once; the correction
passed the focused host check and both target builds.

## Isolated simulator follow-up

A new dedicated Ultra 2 simulator running watchOS 26.1 was used after the lead's
exclusive-window handoff. Ordinary launch created no mic attempt, PCM file or
outbox operation. A newly generated 480-frame synthetic interrupted capture was
seeded only into this isolated app's container while terminated. Relaunch kept
its draft ID, recovered its PCM hash/frame count, added the interruption mark,
restored the static waveform and showed red REC with a white filled circle.
The final stopped state was visually inspected (`simulator-stopped.png`). No
microphone, Shortcut/Action Button, simulator HTTP upload or live content was used.

Installation exposed a packaging defect that generic compilation did not detect:
a watch-only target needs `WKWatchOnly` and must not also declare the independent
companion-app key. Corrected project generation and re-install passed. The owned
app was terminated and owned simulator shut down; the pre-existing simulator and
app data were untouched. Exact simulator identity/processes and raw logs were
reported privately to the lead; no identifiers or user paths appear here.

The v2 order-checkpoint/pairing proposal was reviewed read-only. Native needs
Keychain successful write/readback before redemption, same requestId/token hash
through lost replies, fail-closed handling of inaccessible keys, and atomic
checkpoint persistence before compacting covered facts. Checkpoints cannot erase
local unknown/receipt/order identities. No v2 implementation or acceptance here.
