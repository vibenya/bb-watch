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

Record, pause, save, recover fully readable recordings, choose an existing thread or a project for a new thread, transcribe and deliver, read/listen to full responses, and answer supported single-choice questions with a ten-second cancellation window. Cached lists and messages remain available offline.

Unknown delivery outcomes are never retried blindly: current BB send/create APIs do not offer message idempotency. Push, complications, summaries, full multi-question/approval workflows, and hardware reliability acceptance remain outstanding. See [implementation status](IMPLEMENTATION-STATUS.md), [validation](VALIDATION.md), and [integration findings](../specs/bb-integration-findings.md).
