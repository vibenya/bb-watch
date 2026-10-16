# Development handoff — 2026-10-16

## 2026-10-16 — stage redesign

The Home list was replaced by a horizontal three-page `TabView`: Record (left),
Stage (centre, home), Threads (right). The Stage shows one current thread as a
mood (READY, WORKING, NEEDS YOU, DONE, FAILED, SENDING, OFFLINE) over a black
background with one colour, the agent's activity line and its latest reply.
Tap opens the thread sheet; long-press opens Settings. Recording defaults to the
current thread; New thread picks a project and opens the recorder. A
`BBWatchUITests` target (`testTour`, `testFullScenario`) was added; see
`native/README.md`.

Nothing in the new UI is verified on hardware. Any evidence is limited to the
watchOS 26.1 simulator; page navigation, mood colours and typography, thread
selection and the Stage layout need a device check. Recording cannot run in the simulator (AVAudioEngine input
aborts), so the Record page and the record-to-send path of the new UI have not
been exercised outside hardware. `testFullScenario` still follows the previous
Home-list navigation.

Open items:

- Complication and Smart Stack entry.
- Push notifications for replies and questions.
- Short voice summaries (playback still reads the full response).
- Hardware acceptance of the new UI and of recording from the Record page.
- Always On display behavior verified on device (the Stage tint and glass logo
  are untested in the dimmed state).
- Question types beyond single choice (multi-select, grouped and approval).

## Latest evidence

The updated app was installed and launched on a physical Apple Watch Ultra 2
running watchOS 27.0.1 using Xcode 27.1. The user subsequently dictated and sent
a message from the watch and reported that it worked well. This verifies a real
record/send smoke path; it does not prove standalone LTE, long-term connection
recovery, power-loss bounds or every acceptance criterion.

Latest fixes: single-flight auth; one GET-only 401 retry; bounded timeouts;
all active sidebar-bootstrap chats; selective bounded pending-question fetches;
progressive refresh; audio assembly off the main actor; bounded diagnostics;
Chats pins/activity/folding/search; explicit child-chat recipients.
Full checks passed before the final navigation-owner cleanup; that final cleanup
passed strict Swift 6 typechecking and the signed device build. Independent review
identified child-recipient selection and the fix was verified before installation.

## Next work

1. Reproduce any renewed connection/hang reports and inspect the private watch
   diagnostics file (`Application Support/BBWatch/diagnostics.log`). No BB crash
   report was found in the retrieved catalogue; the original hang cause is not proven.
2. Validate standalone LTE/Wi-Fi, interruption/recovery, long recording and battery
   behavior on hardware. Preserve recordings and unknown delivery states.
3. Extend shared Chats configuration: folders/colors and unread state, using the
   source-backed contracts in `specs/chats-watch-integration.md`.
4. Design a bounded native plugin representation; the iOS WebView integration
   is not a watchOS native plugin framework.
5. Complete summaries, push/complications, broader question types and accessibility.

`native/IMPLEMENTATION-STATUS.md` is the original criterion-level baseline;
its older unverified entries must be read alongside this newer handoff and
`native/VALIDATION.md`. Do not mark all criteria done from one successful message.

## Build and distribution

Source publication is MIT; official artwork and screenshots containing it are
excluded. Add owned artwork at README paths before a full Xcode build. The
maintainer's local checkout retains those ignored files for device development.
No binary release, App Store submission or production backend change accompanies
this source publication. No actual credentials or device signing identities belong here.

End-to-end simulator evidence (2026-10-17): XCUITest testFullScenario passed against live BB; a transcript draft sent from Recordings reached the agent and the stage showed WORKING → DONE with the reply in 36 s. Stage polling: 3 s while working/sending, 20 s idle, paused when the app is not active. Untested on hardware: microphone, haptics, Always On, complication and the bbwatch://record deep link (it starts the microphone without confirmation).
