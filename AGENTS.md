# BB Watch — contributor and agent instructions

## Start here

Read `docs/HANDOFF.md`, `native/README.md`, and `specs/bb-watch-product-spec.md`.
The specification describes the intended product; it is not a completion claim.
Use `specs/chats-watch-integration.md` for the verified BB/Chats boundary.
Work in the canonical project checkout on `main`. Inspect existing edits before
changing files. Never commit credentials, recordings, user conversations, device
identifiers, signing profiles, local logs or third-party artwork without rights.

## Product constraints

- Independent Apple Watch Ultra 2 LTE usage without a nearby iPhone.
- Native SwiftUI and current Apple HIG; short, English UI copy.
- Home has one Record action. Record first, select a chat or new-thread project
  afterward. Do not require a thread title.
- Explicit Send during recording and pause; retain local audio on failures.
- Long recordings use chunks; do not introduce arbitrary recording time limits.
- Present text and playback. Short voice summaries are a future requirement;
  current playback reads the full response.
- Questions are messages followed by multiline action buttons and Record voice.
  Single-choice taps create a persisted ten-second cancelable intent, not a checkbox.
- Share BB/Chats state and ordering. Do not invent a separate pin model or claim
  arbitrary React plugins run natively on watchOS.

## Architecture

`native/project.yml` is authoritative; generate the ignored Xcode project with
XcodeGen. `BBWatchCore/DurableStore.swift` owns persisted drafts and answer intents.
`AppModel.swift` coordinates the UI, cache, recorder and delivery queue.
`BBClient.swift` is the authenticated HTTP actor. `ChatList.swift` projects Chats
ordering and search. `AudioWriter.swift` checkpoints audio; expensive assembly
must stay off the main actor. `Diagnostics.swift` stores bounded private events.
Prefer small changes and system components; avoid unnecessary dependencies.

## Reliability invariants

- Never delete original recording chunks on network/transcription failure.
- Bind queued work to its connection identity; preserve ordering per recipient.
- Do not replay mutations after ambiguous acceptance. No exactly-once claim
  without a verified server-side idempotency/reconciliation contract.
- Authentication is single-flight; retry authenticated GET after 401 at most once.
- Publish chat results independently of question-fetch failures; bound concurrency.
- Persist Undo deadlines and selected values/labels; recheck the current question
  before commit. Voice clarification is not approval or a fabricated selection.
- Preserve exact child-chat IDs through recipient selection and delivery.
- Logs must not contain audio, transcript text, credentials or sensitive URLs.

## Verification

Run `./native/check.sh` for behavioral changes: nine core tests, HTTP contract,
Chats fixture, real audio checkpoint roundtrip, strict Swift 6 typecheck and both
SDK builds. Supply locally owned artwork first (README). Add focused behavioral
regressions for meaningful bugs, not implementation-mirroring tests.
Do not send live prompts merely to run tests. Device testing must distinguish
install/launch, user-reported smoke tests, and measured reliability acceptance.
Use compatible Xcode/device support and the developer's own signing identity.
Never uninstall the app as a repair step without preserving user recordings.
For substantial changes, obtain an independent review after checks and address
blockers before completion. Update handoff/validation with evidence and remaining gaps.

## Collaboration

Delegate independent research and simple coding when useful: Luna for routine
work, Sol for complex implementation; the lead owns architecture and verification.
Keep public documentation free of private session history and internal task IDs.
No release binaries or App Store distribution are implied by publishing source.
