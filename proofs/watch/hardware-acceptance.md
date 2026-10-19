# Physical acceptance — NOT RUN

All G3/G4/TG9/TG10/TG11 remain open. The initial window permitted host fixtures and unsigned generic-device builds;
a later isolated synthetic simulator window has been used and released. These steps are a future lead-coordinated
plan, not authorization to install, inspect signing credentials or use a device.
Use provisional `app.getbb.voiceprobe.phase0`; never replace/uninstall the existing
app or import its recordings. Device size/model, OS build, source hash manifest,
network route and foreground/background state must be recorded per trial.

## Prerequisites and measurements

1. Lead grants exclusive hardware/build/simulator window, signing route and a
   bounded synthetic speech plan. Confirm independent bundle identity before any
   installation. No credential values in logs.
2. Lead provides an admitted synthetic fixture endpoint and approved transport
   configuration. Current loopback-only sink is useful on host/simulator, not a
   physical watch. Full G4 additionally requires accepted shared wire, authorization,
   file body limits, receipt validation and the declared/part/seal/status state
   machine; this harness alone cannot pass that gate.
3. Capture system log events for subsystem `app.getbb.voiceprobe.phase0`; record
   gesture, first tap buffer, first durable buffer/haptic, stop, seal, enqueue and
   receipt separately. State logging and the first buffer host-time at durable acknowledgement exist;
   correlate host clock units and frame positions before asserting onset latency. Never log
   audio, thread text, tokens, endpoint payloads or credentials. All test speech
   is newly authorized synthetic speech, never imported user recordings.
4. Hash and decode the retained **test-only** PCM on the computer after permission
   to export it. Compare chronological markers and frames per part; do not use
   different sample-rate frame sums as duration. Retain sources for failed trials.

## Capture/durability: G3, TG11

1. Ordinary cold/warm launch: no mic indicator and no new source. Tap Record,
   decline permission; repeat with grant. One tap continuation must start input
   after grant, never from a later unrelated app activation. Verify no waveform
   or start haptic before actual first input. Cancel activation by Crown/app switch;
   late permission/activation callbacks must not open a mic.
2. Record one short utterance (< checkpoint-scale duration), Stop, wait five
   seconds, red REC, second utterance, Stop. Verify same draft ID, two ordered
   nonempty parts, no invented five-second silence, no incomplete mark from Stop,
   and a distinct append haptic/announcement only on real appended input.
3. Record → Enter while live; then Enter twice / held-touch release. Verify one
   local operation and one sequence, no editable copy, no second capture and no
   network activity from staging. Start another recording immediately afterwards.
4. With active audio, lower wrist five minutes, return; repeat with Crown, other
   app and standalone conditions. Compare captured markers throughout, not only
   final duration or waveform. No workout/silent-audio workaround is allowed.
   A lost input yields stopped recovery with a missing boundary, not an automatic
   resume. A failure means G3 remains failed/open, not a relaxed acceptance.
5. Interrupt with approved call/Siri/route-change scenarios; classify each actual
   system notification, last committed frame and recovered state. Stop at a known
   low-storage threshold with retained prefix. Do not fill the user's storage;
   use an isolated bounded test fixture/injected writer filesystem failure.
6. Terminate the test process during capture, stop and enqueue in separate trials.
   On launch, inspect exactly one draft/outbox owner, committed prefix and crash
   marks; no auto-record/send, no new operation ID. Force quit is its own trial,
   not labeled OS termination. Whole-store corruption must block without reset;
   a damaged old item must not block a healthy different context in future UI.

## Action Button and Always On: TG9, TG10

1. After lead-approved install, create a Shortcut containing only **Record with
   Voice Probe**, enable Show on Apple Watch, select it under Watch Settings →
   Action Button → Shortcut. If unavailable, record the actual discovery failure;
   no direct workout intent substitution.
2. Test first physical press from watch face, app foreground, locked state and
   cold process. Verify authentication and microphone permission precede capture;
   first actual input alone produces capture feedback. Repeat with retained draft:
   same ID/context, append feedback, earlier audio preserved. Repeated presses
   while live only reveal/preserve input; no send or second owner is assumed.
3. Cancel/deny permission; generic URL and ordinary app launch must never start
   the mic. No URL scheme is registered in this harness.
4. With Always On, verify frontmost inactive differs from actual background;
   capture continues only while hardware proves it. Inspect dim static frame,
   VoiceOver distinction, Reduce Motion and actual input gaps. The probe UI is not
   a TG-U accessibility/geometry pass or the final Always On product rendering.

## Background transfer: G4 (fixture first, then accepted protocol)

1. Explicitly upload the fixed fixture through native background URLSession.
   Record body SHA-256, stable session/task/record IDs and HTTP observation. Check
   files remain after HTTP 200 and after fixture receipts; no audio cleanup.
2. Suspend/background, temporarily disconnect networking, restore network and
   relaunch. Recreate the same session and compare `getAllTasks` with ledger:
   adopt matching tasks; missing tasks are uncertain; no duplicate submission.
3. Crash between plan/task creation/task-ID persistence/resume, and after server
   acceptance before delegate observation. Verify same durable record survives;
   a task without a description is held/canceled, not guessed/reissued. Test
   completion before/after WatchKit refresh-task delivery and disk failure during
   delegate observation. All refresh tasks eventually complete or record timeout;
   failures retain ledger/source and do not masquerade as receipts.
4. Separately test user force quit, OS termination, watch restart, phone absent,
   Wi-Fi and LTE. Apple may cancel/defer work; report observations without claiming
   a guaranteed retry or deadline. Test actual body sizes and server response
   behavior. Do not promote a host HTTP or simulator success to hardware proof.
5. Only after accepted wire/BLK gates: run complete file-backed declare → parts →
   seal → same-ID status, lost seal response, plugin restart, wrong identity,
   receipt mismatch and order barriers. Match immutable manifest bytes, identity,
   per-part source frames, totals and `decoded-audio-v1` from an admitted endpoint.
   Fixture profile cannot authorize cleanup. This production chain is not yet
   implemented in native Phase 0.

Report each trial with pass/fail/not-run, timestamps, frame/hash observations,
source revision, fixture ID and dependency. Do not mark any gate passed merely
because an API compiled, an animation appeared or a task returned HTTP 200.

## Native sealed-part codec follow-up — NOT RUN on hardware

1. After a separate physical window, run the same synthetic codec fixtures without
   microphone capture. Preserve original raw PCM/layout/hash and all candidate
   files. Record watch model/OS, encoder/decoder implementation, source/encoded/
   decoded bytes and per-part rate/channels/frame counts. Confirm unsupported rate,
   source corruption and output failure retain source and hold the candidate.
2. Export only those newly generated synthetic candidates through the explicitly
   approved path. Decode the *same M4A bytes* with the intended computer decoder;
   record its actual format/frames and compare ordered boundary markers. Host
   encoding of similar PCM is not cross-decoding evidence. Never trim a second
   time using packet priming if the decoder already returns playable frames.
3. Measure actual capture-format/route changes only in an authorized speech trial.
   Keep per-part source mapping and interruption boundaries; never sum frames
   across rates as elapsed duration. Codec failure must hold exact source rather
   than silently replacing it or shipping an unapproved raw fallback.
4. Only a reviewed timeline/receipt policy and authorized RU/EN speech comparison
   can establish release fidelity. Current synthetic correlations, packet tables,
   simulator codec results and HTTP observations authorize no source cleanup.

The latest simulator transport probe failed before intake because its background
session daemon was unavailable. A physical trial must instrument `session-created`,
`getAllTasks`, task creation/attachment/resume, completion/error, observation-durable,
finished-events and WatchKit refresh delivery/completion. Match private task/record
identity across relaunch; record missing callbacks as unknown, not success. Public
reports omit device/process IDs and payloads. See [bounded report](milestone1-2.md).
