# BB Watch

An independent, voice-first Apple Watch client for [BB](https://github.com/get-bb).
Record locally, choose a chat, send to an agent, and read or listen to its reply.
This is a community project, not an official BB release.

## What works

- Durable chunked recording with pause, save, recovery and explicit Send.
- BB mobile pairing with credentials in Keychain; transcription and delivery.
- Chats with shared pin order, family activity, related chats and local search.
- Cached messages and system text-to-speech.
- Supported single-choice questions with a persisted ten-second Undo window.
- Bounded network requests, shared authentication and private local diagnostics.

A user confirmed recording and sending a message from a physical Ultra 2 after
the latest update. This is a smoke test, not comprehensive LTE or reliability acceptance.

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
The HTML prototype (`watch.html`) and original product specification are in Russian;
the native application UI is English. The prototype is simulated, not a live client.

## Known limits

BB send/create endpoints have no established idempotency contract. A lost
acknowledgement remains an unknown delivery outcome and is never blindly retried.
Summaries, push/complications, full interaction types, Chats folders/colors and
an extensible native plugin interface remain unfinished. Long recordings,
interruptions, network transitions, battery use and accessibility need hardware testing.

## License

Project source is [MIT licensed](LICENSE). BB names and marks belong to their
respective owners; no trademark rights or endorsement are granted.
