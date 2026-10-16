# BB Watch

Native, independent SwiftUI watchOS client. Current implementation is an integration build, not the completed product specification. It has no iPhone companion target.

## Build

Supply locally owned artwork at the paths described in the [root README](../README.md) first; artwork is excluded from Git. From the repository root:

```sh
./native/check.sh
open native/BBWatch.xcodeproj
```

`check.sh` runs nine filesystem tests, the HTTP contract and Chats projection checks, a real audio checkpoint roundtrip, strict Swift 6 typechecking, XcodeGen, an unsigned device build, and an ad-hoc signed simulator build. Simulator signing is necessary for Keychain access. It does not send messages to live BB.

Build products are under ignored `.build-xcode-*` directories. `project.yml` is the authoritative Xcode project configuration; `Package.swift` exposes the Foundation-only core for macOS tests.

## Run on a watch

Select your Apple Development team in Xcode, enable Developer Mode on the watch, choose the watch destination, and run. The app uses bundle ID `dev.tokenville.bbwatch` and requires watchOS 26 or newer. Installation and launch on watchOS 27.0.1 are verified; final hardware reliability acceptance remains pending.

In BB, generate a code under **Settings → Mobile → Add mobile device**. On the watch, open **Connect BB** and enter that one-time code. Credentials remain in the watch Keychain. Recordings work before connection; connecting does not send drafts automatically.

## Current scope

The UI is a horizontal three-page `TabView`: **Record** (left) ← **Stage** (centre, home) → **Threads** (right).

- **Stage** shows one thread: project, a large mood word, the agent's current activity and its latest reply. Tap opens the full thread; long-press opens Settings. The mood sets the background colour:
  - `READY` — thread has no reply yet. `WORKING` — agent is active or owes an answer to your last message.
  - `NEEDS YOU` — an open question or a pending answer (single choice, ten-second Undo).
  - `DONE` — the agent has replied and is idle. `FAILED` — agent error or a send that failed.
  - `SENDING` — a recording is being transcribed or delivered. `OFFLINE` — not connected to BB.
- **Record** captures first; the recording goes to the current thread by default. **New thread** picks a project, then jumps to the recorder. No title is required.
- **Threads** lists chats in Chats order and search; selecting one makes it the current thread.

Also: pause, save, recover readable recordings, transcribe and deliver, read or listen to full responses; cached lists and messages stay available offline. Unknown delivery outcomes are never retried blindly: current BB send/create APIs do not offer message idempotency. Push, complications/Smart Stack, summaries, full multi-question/approval workflows, and hardware reliability acceptance remain outstanding. See [implementation status](IMPLEMENTATION-STATUS.md), [validation](VALIDATION.md), and [integration findings](../specs/bb-integration-findings.md).

## UI tests

The `BBWatchUITests` target (`UITests/ScenarioUITests.swift`) drives the app in a watch simulator against a live BB. It does not run in `check.sh`.

```sh
cd native && xcodegen generate --spec project.yml
TEST_RUNNER_BB_PAIRING_CODE=<one-time code> TEST_RUNNER_BB_SKIP_RECORD=1 \
  xcodebuild test -project BBWatch.xcodeproj -scheme BBWatch \
  -destination 'platform=watchOS Simulator,name=<watch simulator>' \
  -only-testing:BBWatchUITests/ScenarioUITests/testTour
```

- `testTour` walks Stage, Record, Threads and the thread sheet for screenshots; it records and sends nothing.
- `testFullScenario` pairs, syncs and sends a message to live BB; run it only when that is intended. Its steps were written for the previous Home-list navigation and need updating for the three-page UI before they can be trusted.
- `TEST_RUNNER_`-prefixed variables reach the test without the prefix: `BB_PAIRING_CODE` (one-time code), `BB_SKIP_RECORD` (skip live recording and send an existing draft), `BB_PROJECT_NAME` (project for the new thread) and `BB_THREAD_TITLE` (thread to open; not read by the committed test source at the time of writing).

**Simulator limitation:** `AVAudioEngine` input aborts in the watchOS simulator (input RPC timeout), so recording cannot be exercised there. Record on hardware.
