# Current product direction — voice terminal 3.0, runtime gates open

Read the canonical [product contract](../specs/bb-watch-product-spec.md),
[design](../design.md), [transitions/errors](../specs/bb-watch-transition-contract.md)
and [Opus transition review](../specs/reviews/voice-terminal-opus-review.md).
The [current concept](design/voice-terminal-v8.png) shows stable states with red
REC append after Stop; it does not verify runtime behavior.

Only recorder and Threads are everyday watch surfaces. No recording-history,
playback, delivery-detail, Reply/New/project/model pages. One lower component
shows the chosen thread and its actual activity; input/transport recovery is
separate. Read messages in BB/notifications; reply links reopen the same recorder (gate TG1).
The current code/build remains 0.2.0, not this contract. No clean rewrite,
worktree, implementation, provider call, device build/install or runtime proof is
implied by these documents. The earlier architecture needs a 3.0 update before
implementation; its safety invariants survive but its old UI/routing assumptions
are not a builder's contract. Earlier Fable reviews apply only to their frozen
historical packets, not this consolidated product.

# Earlier direction — reviewed specification 2.0, runtime gates open

The next product is a watch voice-delivery interface plus a BB intake plugin.
Transcription and thread submission move to the computer. See the proposed
[specification](../specs/archive/bb-watch-product-spec-2.0.md), [design](../specs/archive/design-before-voice-terminal-3.0.md),
[gated architecture](../specs/bb-watch-architecture.md) and
[Fable review](../specs/reviews/bb-watch-v2-fable-review.md).
These documents do not describe completed source changes. The native 0.2.0 code
below remains installed; its earlier contract is archived as
[specification 1.2](../specs/archive/bb-watch-product-spec-1.2.md).
Do not treat a signed build/install as reliable wrist-down transcription evidence.

# Glance 0.2.0 (2) — 2026-10-18

The approved Glance design replaces the three-page Record/Stage/Threads shell.
One thread header opens the chooser by tap or left swipe. New is a local
Project/Model context; actual creation waits for explicit Send. Recording uses
pause/red-circle resume, autosave and an icon-only send action. Questions,
processing, messages and results share the main block with 200ms replacements;
Reduce Motion is immediate. History includes destination and truthful status.
See [Glance design 1.2](../specs/archive/glance-design-1.2.md) and
[product specification 1.2](../specs/archive/bb-watch-product-spec-1.2.md)
for that build's behavior and implementation.

Local New followups persist their dependency on a creating request and resolve
only to its confirmed same-identity thread ID. Independent New requests stay
independent. Queue draining preserves per-thread order without offline spin;
unknown acceptance cannot replay. Background delivery and late create/sidebar
updates cannot steal an explicit selection. Model choices/defaults use the real
BB catalog and create contract. Draft defaults do not inherit unrelated global
model settings.

Playback repairs cover asynchronous watch activation, recording/message source
identity, scoped errors, ordered CAF completion, interruption and capture gates.
Transcription now lives in `TranscriptionPipeline.swift`: one-pass PCM16 WAV,
completed-segment caches, cancellation/identity validation and original retention.
A real synthetic bilingual comparison validated complete text in two PCM16 calls
with roughly half the Float32 upload bytes. Rejected AAC lost English words in
both trials; no AAC path ships. This does not establish general ASR accuracy or
physical watch/LTE latency. See `../specs/voice-delivery-latency.md`.

Verification: final complete `./native/check.sh` passed after the last UI fix:
12 core tests, HTTP/catalog/default/create, Chats, projection, real audio and
PCM16/cache/transport checks, diagnostics, strict Swift 6 and both SDK builds.
Eleven isolated simulator UI scenarios passed across final focused runs,
including same-launch lifecycle changes, New followups/focus, modal hit targets,
prior-question/New isolation, Undo, large text and Reduce Motion. Actual synthetic
CAF playback and final PCM16 encoding also passed watch-simulator runtime checks.
Lead inspected settled native screenshots. Independent integration review found
no blocker. Signed development build, signature, version/icon metadata and target
watch provisioning were verified.

**Physical update completed on 2026-10-18:** version 0.2.0 (2) was installed
in place and launched on the Ultra 2. The first attempt lost its installation
service connection; inventory confirmed 0.1.0 remained before a successful retry.
Post-install inventory confirmed 0.2.0/2. All 68 original CAF paths and sizes
matched the pre-install manifest (25,660,928 bytes). No uninstall or live agent
test prompt was used. Install/launch and retained-file metadata do not establish
hardware microphone, speaker/headphones, interruptions, standalone LTE,
power-loss or battery acceptance; these remain separate. A cheap-model summary gateway is not implemented; the compact
view uses actual activity/source excerpts with full-original access.

The entries below describe earlier builds and historical evidence.

# Sync reliability repairs — 2026-10-17

GitHub issues #1–#10 track the sync investigation and follow-up. Native repairs
separate selected-thread polling from sidebar and queued transcription, restart
reads on selection/foreground changes, and invalidate stale results with a
selection/connection generation. Loading and failed refreshes no longer present
READY; runtime status comes from current thread detail instead of historical
turn rows. Thread detail and timeline are still separate, non-atomic reads.

Replies, activity and question labels scroll without line caps. Full history has
explicit cursor-based Load older and stale-cursor recovery. Safe GET transport
failures retry once; mutations and TLS failures do not. Typed private diagnostics
correlate local request, display and delivery milestones; see DIAGNOSTICS.md.

Lead verification: full `./native/check.sh` passed, including nine durable-store
tests, expanded URLSession contracts, Chats projection, real audio checkpoint
roundtrip, diagnostics privacy/retention, strict Swift 6 and both SDK builds.
Dynamic thread-switch race and physical latency acceptance remain unverified.
No live test prompts, device installation or binary distribution accompany this
source repair. Current foreground polling still sleeps 3 seconds busy / 20 idle;
network duration is additional, and background polling is suspended.

Voice performance has only a synthetic host assembly baseline; no ASR/upload
speedup is claimed. The event/plugin design in `specs/watch-event-contract.md`
is a proposal, not installed functionality. Network/TLS root cause on hardware,
measured voice latency and plugin implementation remain open (#6, #7, #10).

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
