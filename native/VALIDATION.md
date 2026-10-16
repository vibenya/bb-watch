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
