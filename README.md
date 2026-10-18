# BB Watch

An independent Apple Watch voice interface for [BB](https://github.com/get-bb).
This is a community project, not an official BB release.

## Proposed next product: voice delivery plugin

[Specification 2.0](specs/bb-watch-product-spec.md) and [design](design.md) describe
a proposed reset: the watch records and delivers original audio; a BB plugin on
the computer owns durable intake, transcription and thread submission. The watch
is an external input interface, not a miniature BB conversation client.
The [architecture and gated plan](specs/bb-watch-architecture.md) and
[Fable/lead review](specs/reviews/bb-watch-v2-fable-review.md) define the next steps.
The package is reviewed for Phase 0 proofs and is **not implemented yet**;
remote admission, ASR, capture and complete background delivery remain unproven.
The current source/build below is version 0.2.0; keep it separate from v2 claims.

## Installed 0.2.0 scope

- Durable chunked recording with pause, save, recovery and explicit Send.
- BB mobile pairing with credentials in Keychain; transcription and delivery.
- Chats with shared pin order, family activity, related chats and local search.
- Cached messages and system text-to-speech.
- Supported single-choice questions with a persisted ten-second Undo window.
- Bounded network requests, shared authentication and private local diagnostics.

Earlier device smoke tests do not establish reliable long-recording delivery.
The current watch-side transcription path can be delayed by background suspension.
Version 2.0 moves this work to the computer; it must pass independent wrist-down
transfer and recovery acceptance before release.

## Build

Requires macOS, Xcode with watchOS SDK/platform components, and XcodeGen.
Deployment target: watchOS 26+. Latest device build used Xcode 27.1.

Before building, supply artwork you have rights to use:

- `native/Sources/BBWatch/Assets.xcassets/BBLogo.imageset/BBLogo.svg`
- `native/Sources/BBWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024 × 1024)

These two files are intentionally excluded from Git. Existing asset catalogs
reference those filenames. Official BB artwork used during local development
is not redistributed or covered by this project's MIT license; see
[asset provenance](native/ASSET-SOURCES.md). You can supply your own artwork.

```sh
./native/check.sh
open native/BBWatch.xcodeproj
```

For core tests without artwork or an installed watchOS platform:

```sh
swift test --package-path native
```

Choose your own signing team and unique bundle identifier for device installation.
See [native setup](native/README.md) for pairing and build details.

## Continue development

Read [AGENTS.md](AGENTS.md), [current handoff](docs/HANDOFF.md),
[product specification](specs/bb-watch-product-spec.md), and
[Chats integration](specs/chats-watch-integration.md).
The historical HTML prototype (`watch.html`) is simulated, not a live client.
The native application UI is English. Version 1.2 requirements are archived in
[specs/archive](specs/archive/bb-watch-product-spec-1.2.md).

## Known limits

BB send/create endpoints have no established idempotency contract. A lost
acknowledgement remains an unknown delivery outcome and is never blindly retried.
Summaries, push/complications, full interaction types, Chats folders/colors and
an extensible native plugin interface remain unfinished. Long recordings,
interruptions, network transitions, battery use and accessibility need hardware testing.

## License

Project source is [MIT licensed](LICENSE). BB names and marks belong to their
respective owners; no trademark rights or endorsement are granted.
