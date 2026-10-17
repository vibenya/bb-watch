# BB Watch

Native, independent SwiftUI watchOS client. Current implementation is an integration build, not the completed product specification. It has no iPhone companion target.

## Build

Supply locally owned artwork at the paths described in the [root README](../README.md) first; artwork is excluded from Git. From the repository root:

```sh
./native/check.sh
open native/BBWatch.xcodeproj
```

`check.sh` runs core filesystem tests, the HTTP contract and Chats projection checks, a real audio checkpoint roundtrip, compact transcription/cache/transport checks, bounded diagnostics privacy checks, strict Swift 6 typechecking, XcodeGen, an unsigned device build, and an ad-hoc signed simulator build. Simulator signing is necessary for Keychain access. It does not send messages to live BB.

Build products are under ignored `.build-xcode-*` directories. `project.yml` is the authoritative Xcode project configuration; `Package.swift` exposes the Foundation-only core for macOS tests.

## Run on a watch

Select your Apple Development team in Xcode, enable Developer Mode on the watch, choose the watch destination, and run. The app uses bundle ID `dev.tokenville.bbwatch` and requires watchOS 26 or newer. Installation and launch on watchOS 27.0.1 are verified; final hardware reliability acceptance remains pending.

In BB, generate a code under **Settings → Mobile → Add mobile device**. On the watch, open **Connect BB** and enter that one-time code. Credentials remain in the watch Keychain. Recordings work before connection; connecting does not send drafts automatically.

## Current scope

The Glance interface has two primary compositions: a selected **Thread** and its
**Threads** chooser. Header tap or left swipe opens the same chooser. New is a
local Project + Model state, with server creation only on explicit Send.

- One microphone action; capture uses a red waveform and pause/red-circle resume.
  The lime up arrow explicitly sends. Audio autosaves; there is no manual Save.
- Activity, messages, questions and delivery processing share the working block.
  Compact text fades on a real content change; full text and playback remain accessible.
- History scrolls below the block and includes destination and truthful delivery state.
  A focused sheet's microphone returns to the recorder without starting capture.
- Playback uses original ordered CAFs, asynchronous watch audio activation and
  source-scoped state; capture and playback cannot own the session together.
- Transcription is isolated in `TranscriptionPipeline.swift`: compact 16-bit PCM WAV
  upload, persisted completed segments, original-audio retention.
  Synthetic bilingual ASR coverage/timing and upload bytes were measured; physical-watch latency is not.

Credentials remain in Keychain. Offline recordings and cached conversations are
retained. Unknown acceptance is never retried blindly. The selected model is
loaded from verified BB execution options and persisted with a New draft.
There is no hosted cheap-model summary gateway in this release: concise activity
and a bounded excerpt have full-original access. Push, broader question types,
short voice summaries and standalone hardware reliability remain separate gaps.
See [design](../design.md), [implementation status](IMPLEMENTATION-STATUS.md) and
[validation](VALIDATION.md) for evidence and limitations.

## UI tests

The `BBWatchUITests` target runs isolated DEBUG simulator fixtures. These tests
never authenticate, start AVAudioEngine input or dispatch a live agent prompt.
Each fixture uses temporary storage. The main flow exercises capture/pause/resume,
recipient selection, explicit send and another capture while processing. Other
flows cover New, question Undo, unknown delivery and visual state tours.

```sh
cd native
xcodegen generate --spec project.yml
xcodebuild test -project BBWatch.xcodeproj -scheme BBWatch \
  -destination 'platform=watchOS Simulator,name=<watch simulator>' \
  -only-testing:BBWatchUITests/ScenarioUITests
```

The previous live `testFullScenario` and three-page tour are obsolete. Current
UI evidence and exact passing tests are recorded in `VALIDATION.md`.

**Simulator limitation:** real AVAudioEngine input aborts in this environment;
normal simulator capture reports no input instead. Explicit DEBUG UI fixtures
simulate capture state. This does not prove microphone operation on hardware.

The original-file playback check runs actual synthetic CAFs in a booted watch
simulator, without an app install, microphone or network:

```sh
PLAYBACK_SIMULATOR=<watch-simulator-id> ./native/check-playback.sh
```

The main `check.sh` remains independent of a booted simulator: its ASR contract
checks use a local macOS URLProtocol fixture. watchOS Foundation does not reliably
intercept these custom protocol fixtures; fixture hosts use `.invalid` to fail
closed. Encoder-only watch-runtime evidence is separate from transport evidence.

See [voice latency measurements](../specs/voice-delivery-latency.md) for the
reproducible synthetic before/after benchmark and its limits.
