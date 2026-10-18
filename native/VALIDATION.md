# Observed long-recording issue and v2 boundary — 2026-10-18

A real multi-minute recording remained in watch-side transcription. Diagnostics
showed slow segment requests and background/foreground transitions; bounded logs
do not establish exactly where every timeout occurred. Current source uses an
ephemeral session and does not provide a durable background audio intake protocol.
A manual computer-side recovery preserved the audio, reused completed segments,
and obtained verified acceptance in the selected thread. This recovery is not a
successful test of a shipped v2 plugin and does not repair the current background
implementation. The proposed v2 specification moves ASR to BB and requires real
wrist-down file-transfer evidence before release. No source change is claimed here.

# Glance release validation — 2026-10-18

Version 0.2.0 (2), Xcode 27.1, watchOS 26+ target; watchOS 26.1 Ultra 2 simulator.
Final `./native/check.sh` passed after the prior-question/New isolation fix:
12 core tests, HTTP catalog/default/create plus transport invariants, Chats,
source-backed presentation, ordered original audio checkpoints, PCM16 transcription
cache/auth/cancellation/identity/cleanup, bounded diagnostics, strict Swift 6,
watchOS build and ad-hoc signed simulator build.

Eleven isolated DEBUG simulator scenarios passed across final focused runs.
Continuous same-launch request transitions show transcription → sending → actual
new ID/receipt → activity → reply; microphone remains available. Other checks
cover pause/resume/retarget, unchanged observation before Send, New configuration,
real modal history and full hit targets, Undo, left-swipe/dismiss, creation followups,
late-focus preservation, old pending answer vs New processing, large text/Reduce
Motion and offline/stale/failure/unknown/unsupported states. The tests use synthetic
fixtures and never dispatch a live agent prompt or use AVAudioEngine input.
Lead visually inspected final native working/New/capture/paused/history/question,
stale, accessibility and lifecycle screenshots. They are local ignored/private
verification artifacts rather than redistributed artwork.

`check-playback.sh` passed on a real watch-simulator process with synthetic CAFs:
empty/missing/corrupt rejection, ordered multi-part completion, pause/resume,
late activation/delegate guards, route loss/interruption, capture gating and
unchanged original bytes. Final PCM16 encoder-only watch-runtime check passed
30s/15 ordered checkpoints within two LSBs, source-rate preservation, failed-source
cleanup and unchanged originals. Custom URLProtocol transport fixtures run on
macOS; watchOS does not reliably intercept them. Fixture hosts fail closed.

Six bounded real ASR calls used only generic OS-TTS bilingual speech through the
official BB CLI. Original Float32 WAV and shipping PCM16 each returned 44/44 words
in both trials; PCM16 reduced upload bytes 49.94%. Its two CLI durations were
2.829s/1.778s versus 3.716s/3.229s; small N and host networking do not establish a
stable watch/LTE latency improvement. AAC omitted the English part twice and was
removed. Detailed limits and reproduction: `../specs/voice-delivery-latency.md`.

Independent integration advisor found no actionable blocker after the full gate.
Signed development build passed; codesign, 0.2.0/2 metadata, AppIcon and provisioning
for the target watch were checked. Physical in-place installation and launch
completed on 2026-10-18. Initial CoreDevice 3002/IXRemoteErrorDomain 6 connection
loss was reconciled by inventory showing the old 0.1.0/1 app; one retry succeeded.
Installed inventory confirmed 0.2.0/2, and launch returned a process identifier.
A subsequent process inventory confirmed the new app was running. All 68 original
CAF paths and sizes matched before/after (25,660,928 bytes); audio contents were
not read. No uninstall or live test prompt was used.
Physical audibility, microphone, interruptions, network recovery, standalone LTE,
long-duration/power-loss/battery and general recognition quality remain unverified.
The hosted summary gateway is not part of this build; UI excerpts remain source-backed.

The following sections are historical validation of earlier builds.

# Validation — 2026-10-16

Environment: Xcode 26.1.1, Swift 6.2.1, watchOS 26.1 SDK/runtime. Deployment target watchOS 26. No claim of watchOS 27 visual acceptance.

## Verified

- `./native/check.sh`: nine filesystem tests, zero failures; real Foundation URLSession contract check; AVFoundation checkpoint check; strict Swift 6 watchOS typecheck; device and simulator builds.
- Audio check: 84,000 PCM samples across three finalized CAF files, reopened and compared sample by sample. Duration 5.25 seconds; repeated finalization does not duplicate chunks. This does not prove microphone continuity or power-loss durability on hardware.
- Transport check: authentication/cookie boundary, wire decoding, accepted queue receipt, lost acknowledgement without retry, supported question resolution. Read-only checks against installed BB confirmed project/thread/timeline structures. No live prompt was sent.
- Official logo SVG and 1024px icon compile with the asset catalog.
- Apple Watch Ultra 2 simulator on watchOS 26.1 installed and booted. Ad-hoc signed BB Watch installed and launched; main screen visually inspected. An unsigned simulator build failed Keychain access, so the check script now signs the simulator build ad hoc.
- Device build signed successfully with the existing Apple Development identity and provisioning profile. No credentials were copied into source.
- Independent Advisor review found a selection/receipt mismatch during Undo. Fixed by persisting the display label, deriving the receipt from that intent, and hiding alternate choices while an answer is pending. Rechecked by a separate Sol agent; persistence regression assertions and builds pass.

## Not verified / blocked

- Physical Ultra 2 is paired and reports watchOS 26.6. Last observed Developer Mode was disabled. Installation attempt failed before confirmation with CoreDevice tunnel timeout / NWError 60. User was asked to enable Developer Mode. Installation and on-device launch are not claimed.
- Native UI automation could obtain Simulator screenshots, but coordinate clicks failed with `noWindowsAvailable`. Full navigation, long-answer layout, maximum Dynamic Type and VoiceOver checks remain pending.
- No live pairing, audio transcription, agent send/reply, or LTE/Wi-Fi-only session has been completed on hardware.
- Long recording, battery/thermal behavior, background capture, force-quit/power-loss bounds, disk exhaustion and headphone-route behavior need physical acceptance.
- Full specification completion is tracked separately in `IMPLEMENTATION-STATUS.md`.

## Reproduce simulator launch

After `./native/check.sh`, select a watch simulator ID from `xcrun simctl list devices available`:

```sh
xcrun simctl boot <watch-simulator-id>
xcrun simctl bootstatus <watch-simulator-id> -b
xcrun simctl install <watch-simulator-id> native/.build-xcode-watchsimulator/BBWatch.app
xcrun simctl launch <watch-simulator-id> dev.tokenville.bbwatch
```

## English UI verification

After translating all native UI strings to English and removing the Record subtitle, `./native/check.sh` passed again. Reinstalled and launched the updated app in the Ultra 2 simulator; visually checked the home screen with the official BB logo and single-label Record button. Screenshot: `Verification/home-en.png`. Native source and project configuration contain no remaining Cyrillic UI strings. Speech voice selection follows the response language.

## Physical installation — 2026-10-16

Xcode 27.1 (27A9275), watchOS 27.0.1, physical Apple Watch Ultra 2. Developer Mode enabled and DDI services available. After Apple Account sign-in, the device-specific automatic provisioning build succeeded. `devicectl device install app` succeeded for `dev.tokenville.bbwatch`; `devicectl device process launch` confirmed launch. Microphone, pause/resume, saved audio playback, BB pairing and standalone delivery remain awaiting hardware interaction results; installation and launch alone are not full e2e acceptance.

## First hardware feedback fixes — 2026-10-16

The watch system crash-log catalogue was retrieved: five entries, no BB crash report. App-container listing confirms original CAF chunks, metadata and transcript caches remain present. Copying per-recording metadata did not complete; no failure cause is inferred from private recordings. The reported hang and connection loss were not reproduced under observation.

Repairs: complete sidebar bootstrap instead of first 50 threads; publish/cache chats before independent project/question loading; only query pending-interaction candidates; four simultaneous question fetches maximum; single-flight authentication; one GET-only session refresh after 401; explicit network timeouts; nonmodal sync errors; audio assembly moved off MainActor with zero-progress guard. Added 200-entry local diagnostics containing event names and error domain/code only.

Chats projection follows installed plugin shared pins, activity, parent/lifecycle folding and title/project/branch/child-title search. Both chat list and recipient picker use it; folded children remain individually selectable by their own ID. One navigation destination owns the recipient completion route. Folder tabs, colors, read state, pin editing and arbitrary React plugin rendering are not implemented. See ../specs/chats-watch-integration.md.

Full native/check.sh passed: nine filesystem tests, HTTP auth concurrency/401/full-list/no-replay fixtures, Chats projection fixture, real PCM checkpoint check, strict Swift 6 and device/simulator SDK builds. Advisor review found inaccessible child recipients; fixed by explicit family selection. Follow-up source review found duplicate navigation destination ownership; removed. Final navigation tweak was re-typechecked and signed device build rebuilt. Interactive selection-to-server-send and hardware responsiveness remain unverified. Simulator process launched but its screen stayed black after the Xcode/runtime update, so no new UI visual acceptance is claimed.

Updated hardware deployment did not complete: first install failed with device-disconnected CoreDeviceError4000; one retry exceeded its30-second timeout. The previously installed build remains the last confirmed hardware version.

Installation retry: updated signed build installed successfully on the physical Ultra 2; devicectl confirmed launch of dev.tokenville.bbwatch. Responsiveness, network recovery and Chats ordering still require user exercise; install/launch alone do not prove those fixes.

## User smoke confirmation

After the latest physical update, the user sent a dictated message from Apple Watch and reported success. This is a real recording/send smoke check, not comprehensive hardware or LTE acceptance. See `../docs/HANDOFF.md` for current priorities.

## Stage redesign — 2026-10-16

The Home list was replaced by a three-page UI (Record, Stage, Threads). Earlier entries above that mention the Home screen, the Record button on it, or navigation through Home list rows describe the previous UI. Not re-verified here: `./native/check.sh` against the new UI, hardware behavior, Always On display and recording from the new Record page. The simulator cannot record (AVAudioEngine input aborts). See `../docs/HANDOFF.md`.

## Sync repair integration — 2026-10-17

Lead ran the complete `./native/check.sh` after per-issue integration: nine core
tests pass; expanded HTTP checks cover current runtime/flat work rows, bounded
GET recovery, no TLS/mutation replay, cancellation and history cursor encoding,
401 retry and stale-cursor failure. Chats, ordered 84,000-sample audio checkpoint,
new diagnostics privacy/correlation/200-line retention, Swift 6 typecheck and
both watchOS/simulator SDK builds pass.

These checks do not prove physical-watch latency or dynamic SwiftUI task race
behavior. No live prompt or transcription was sent. Voice assembly measurement
is synthetic host-only; see specs/voice-delivery-latency.md. No device install
is part of this integration. Event transport remains a design proposal.

Read-only `ScenarioUITests/testTour` passed on the 49mm Ultra 2 watchOS 26.1
simulator after integration: stage, Record, Threads, selected-thread stage and
full thread sheet were traversed; the accessibility tree exposed Listen controls.
This existing tour is observational, not a latency or stale-response assertion.
The simulator queue contained only an accepted draft before launch; no live
message/recording scenario ran. Long-question and physical layout acceptance
remain outstanding.

Independent review found a diagnostics suspension between thread publication and
cache persistence. Publication/cache writes are now synchronous after a
connection-generation check; each later publication checks that generation again.
A second independent control-flow review found no remaining stale publication
in refresh. A dynamic AppModel connection-race harness is still absent.

Lead inspection of actual simulator diagnostics also found time-only timestamps.
A real-file regression failed on that formatter, then passed with full ISO 8601
date/time/timezone and fractional seconds. The complete native check was rerun
after both repairs and passed, including both SDK builds. Simulator observation
showed selected-thread publication preceding completion of sidebar refresh;
this is a local observation, not a latency benchmark.

## 2026-10-17 — lime icon and sync repair device update

Built current main `7f8f0ce` with the user-selected lime bracelet icon as an opaque 1024 × 1024 PNG. Device-specific signed Xcode build succeeded. Installed in place on the paired physical Apple Watch Ultra 2; `devicectl` confirmed installation and launch of `dev.tokenville.bbwatch`. This includes the sync repairs documented above. No uninstall or live test prompt was performed. Visual icon appearance and interactive sync reliability after this installation remain unmeasured on hardware.

### Icon packaging correction

The first lime installation above did **not** contain a usable app icon: its catalog entry used `idiom: watch` with the single-size format, producing `unassigned child` warnings and no `CFBundleIcons` metadata. Installation/launch success did not establish icon packaging. Changed the single-size entry to `idiom: universal` with `platform: watchos`. A subsequent signed device build succeeded without those warnings. Checked the built Info.plist names `AppIcon` as its primary icon and `assetutil --info` confirms an opaque 1024 × 1024 watch `Icon Image` rendition in Assets.car. Physical icon appearance still needs direct observation after the corrected installation.

Corrected package installation and process launch on the physical Ultra 2 both succeeded. Independent review passed. This establishes corrected packaging and device install/launch; visual Home Screen confirmation remains pending.
