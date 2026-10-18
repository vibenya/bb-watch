# BB Watch — Glance implementation design

2026-10-17. Implements product specification 1.2. This document is a build contract, not a completion report. Current sources and verified server contracts take precedence over illustrative mock text. Preserve all durable-store, identity, question and delivery invariants.

## Visual references

Local concept assets (intentionally not required for a source checkout):

- `output/imagegen/thread-navigation/14-main-sprite-revised.png`: main compositions.
- `output/imagegen/thread-navigation/15-request-lifecycle.png`: temporal variants of one block.
- `output/imagegen/thread-navigation/16-recording-controls-refined.png`: final pause/resume/history correction.

Latest correction wins: resume is a simple solid red circle; no play-plus-record glyph. Sheet toolbar mic replaces sheet X. Small paused-recorder cancel remains and preserves audio.

## Ownership and integration

Use canonical checkout on main. Lead owns spec/design, release integration, check.sh orchestration and device install. UI session owns SwiftUI views, Theme, navigation/presentation state, UI fixtures and tests. Playback session owns AudioPlayback.swift and focused audio playback checks. Transcription session owns new transcription module, BBClient ASR transport and audio assembly/encoding. Shared AppModel/DurableStore changes require explicit coordination; UI owns presentation/draft context and transcription owner may change only the transcription call path. No worker commits unrelated edits, releases or installs. Report exact files, checks, limitations and commit boundaries to lead.

## Main composition and navigation

Replace horizontal three-tab shell with one NavigationStack/main ScrollView and system sheets. Persistent selected thread ID remains source identity, not a row offset. There are only two main compositions: Thread and Thread chooser. New is a local context in Thread. Recording is a body state. Existing connection/settings/full detail remain secondary system destinations.

A shared ThreadContextHeader is a Button with status glyph, one-line title, small relative time and `chevron.right`. Entire surface is tappable. A deliberate predominantly horizontal right-to-left swipe opens the same chooser; it must not steal vertical Crown/touch scrolling. Keep a visible header action, so gesture is supplementary. Restore scroll position on dismissal. Avoid nested active sheets/presentation races.

Header semantics depend on current body: observation follows currentThreadID; an unsent capture follows draft destination. Selecting another thread while dictating updates unsent destination durably, not existing enqueued work. Once Send starts, freeze recipient and connection identity for that recording. Do not silently retarget answer context or children to family roots. While recording, changing destination does not change the observed thread. Picker dismissal without selection changes neither. Explicit Send switches observation to its existing destination; New retains a local creating/sending context until create returns the actual thread ID, then follows that ID.

Thread chooser uses shared Chats projection, family-activity order, hidden/archive filtering and pins as glyphs. New is a normal list action. Selecting New only creates local intent. Project/Model selectors are focused sheets. Their toolbar microphone dismisses back to the existing recorder without starting/resuming audio. A user on a non-recorder main state may return to its idle recorder; capture still needs an explicit mic tap. Preserve active capture while navigating and show capture affordance. A dismissed picker does not change selection.

## Model selection and new-thread contract

Inspect installed BB server schema before extending BBClient. Fetch real provider/model choices and project defaults. Represent default explicitly; persist selected intent across capture/relaunch. Pass a verified supported model field on createThread. No hardcoded demonstrative models, private credentials or fabricated capability. Existing drafts must decode with defaults if persisted schema grows. Server rejection preserves draft and its chosen configuration. Do not create an empty server thread on choosing New or a model. A second capture in the pending New context persists a dependency on the creating request, not a fabricated thread ID. Resolve that dependency only to the acknowledged returned ID under the same connection identity. Parent failure/unknown acceptance blocks dependent dispatch; relaunch preserves it. Explicit selecting New again starts an independent context. Post-create completion must not steal focus after the user selected another thread.

## Working block and request projection

Build one source-backed request presentation value from durable draft state + current selected thread snapshot + freshness. Keep presentation separate from mutation state. Typical fields: stable request/source ID, phase, glyph, concise primary content, detail access, source timestamps, allowed actions, failure/reconciliation context. It must not infer delivery from a completed spinner or agent-start from HTTP request completion.

| Source | Presentation | Available action / transition |
|---|---|---|
| Idle selected thread | task/activity or last message | mic, details, header |
| New local context | Project + Model | mic, selectors |
| Engine starting | pending capture, honest state | safe cancel; no false waveform |
| Capturing | red waveform + red pause bars | pause, explicit up-arrow Send, context picker |
| Paused | waveform + solid red circle; small cancel X | resume, Send, dismiss/save local |
| Local saved/queued | locally retained, destination | capture another, inspect history |
| Transcribing | concise stage, no percent or ETA | capture another; safe cancel only if supported |
| Sending transcript | network stage | no mutation replay action |
| Receipt accepted | confirmed BB receipt | capture another; await current thread |
| Ambiguous acceptance | review/reconcile | never blind retry/send again |
| Agent active | current task + factual activity | mic, details |
| Question | full prompt access + native choice buttons | persisted 10-second intent + Undo, voice |
| Message/result | concise latest message; check only for known done | mic, full text/playback |
| ASR failure | original saved; localized concise error | retry transcription from saved parts |
| Delivery failure | known rejection vs unknown distinguished | safe retry only if non-acceptance established |
| Offline/stale | cached content with freshness | local capture; no fabricated Ready |

Several stages may be absent in a real contract. Do not artificially delay or insert them. Keep prior request visible in history while capture another is foreground. Ordering still applies per recipient. Question UI retains durable deadline/selected labels and rechecks question before commit. Do not truncate decision-critical question content.

## Capture and autosave

Reuse WatchRecorder/AudioWriter/DurableStore. Central circular control is 44pt+ target; active `pause.fill` in red, paused red circle. Up arrow in lime bottom capsule, accessibility label Send recording. No visible Record/Send/Resume/Save text. No prominent standalone capture timer. Header's time refers to thread activity/reply, never accidentally labels recording duration. Recording meter redraws at a bounded cadence and stops offscreen/inactive; do not run decorative perpetual animation.

Autosave chunks during capture and checkpoint on pause/leave. Separate stopping capture from deleting audio. A paused X dismisses locally saved work; permanent delete is explicit and confirmed when appropriate. Existing recording failure recovery remains. Do not start multiple recorders from deep links or mic shortcut. A new capture stops playback before activating input. Playback cannot reconfigure the session during live capture; checkpoint/pause first under explicit UI ownership.

## History and playback

History is below main content, with a small next-section peek; use normal vertical scroll and Crown, not a separate permanent tab. Focused full history sheet is acceptable for deeper navigation. No thread selector atop sheets. Toolbar mic returns to capture state. Rows contain short request topic, recipient thread and meaningful persisted/source-backed processing status; safe fallback topic when transcript absent. Do not display all requests as Delivered or derive Done merely from local send success.

Original-audio playback uses ordered CAF chunks. Handle empty/missing/corrupt parts, unsuccessful player start, decode failure, interruptions, route changes, pause/resume, stale delegate callbacks and end-of-queue. State must identify the recording being played consistently with view IDs. Errors remain visible and preserve files. Watch audio routing/session activation must support the watch speaker as allowed by current APIs and headphones; verify on real device, do not infer audibility from isPlaying alone. Full-response speech remains distinct from recorded audio.

## Typography, layout and motion

Black background, white text, lime #D5FF00, charcoal materials; red only for capture/destructive meaning. Use system rounded/semantic fonts, roughly 16–17pt body at default watch size, smaller secondary metadata, Dynamic Type scaling. No huge status word. Short content naturally fits about 4–5 lines; offer full text and let accessibility sizes scroll. Avoid fixed heights clipping translations/choices.

Motion contract:

- Stable source ID plus content revision, not a new UUID per render/poll.
- Header glyph replacement uses system symbol replacement (availability fallback opacity); retain title geometry.
- Phase/summary/message changes use a restrained 180–250ms ease-in-out opacity transition. A 4–6pt vertical offset is optional only if it does not disturb layout. Animate complete text blocks, not characters. Reserve consistent minimum content space while allowing long text to grow.
- Press feedback uses native Button style; modal transitions are system transitions. No nested spring chains or decorative bounce.
- Waveform responds to actual input; paused waveform is static. Pause/resume glyph transition is short and respects real engine state.
- New history row appears once; updates alter same row. Send may briefly acknowledge locally saved/queued, then show actual processing; capture button is immediately usable after final checkpoint.
- Rapid source changes coalesce naturally into latest content; do not queue obsolete animations. Animation never delays persistence, Send or current status.
- Reduce Motion: opacity-only or immediate replacement; no spatial movement/indeterminate decorative ring. Inactive/Always On: no continuous animation. Announce meaningful state once for VoiceOver, not every waveform sample or poll.

## Transcription module and performance

Extract assembly/encoding/upload orchestration from AppModel into a small independently checkable module. AppModel retains durable queue ownership and publishes truthful phases. Module takes immutable draft/chunk references plus request client/identity context; returns ordered transcript segments or failure. Preserve existing segment checkpointing and avoid repeated ASR of completed segments. Cleanup only temporary assembled/upload files, never original chunks.

First measure same synthetic/owned non-private fixture before changes: audio duration, PCM bytes, encoded bytes, assembly, encoding, ASR/upload, total, chunk/segment count. No transcript, private URL or credentials in logs. Optimize largest measured local/network cost. Shipping upload is 16-bit PCM WAV at source sample rate/channel count. It halves Float32 payload while retaining original CAFs. AAC was rejected after two real bilingual ASR omissions despite correct decoded source audio. Validate ordered samples and quantization bounds, and use real speech coverage as well as byte size. Bounded segment concurrency is a candidate only after verified service limits and timing. Preserve chronological text order, connection cancellation and per-recipient mutation ordering. Do not send live agent prompts as tests or replay ambiguous send/create. ASR network calls may cost money; prefer mock contracts and synthetic transport measurement; if authorized test audio is used, report real provider timing separately from local baseline. No claim of maximum theoretical latency or speedup without evidence.

## Concise text adaptation

Lifecycle, errors, elapsed and freshness come from source facts, never model inference. A concise foreground view can use actual activity and a short excerpt initially, explicitly documented as a fallback. Future hosted cheap-model summary gateway is demand-driven, revision-keyed and cached, only for selected active view; every glance must not cause a fresh model call. No invented model endpoint or secret. Original remains reachable. Do not expose private hidden reasoning; show user-facing activity/messages. If gateway cannot be implemented from verified existing contracts, report it separately rather than claim full AI summarization.

## Verification and release

Use focused behavioral checks for meaningful fixes, not text snapshots mirroring code. Exercise state projection/draft destination/frozen queued recipient, pause/autosave/relaunch, every permitted lifecycle action, failure/unknown acceptance, questions/Undo, no repeated animation on unchanged content. Update non-mutating simulator tour to new navigation; use deterministic local UI fixtures for transitions rather than live test messages. Capture simulator screenshots for working, new, chooser, capture/paused fixture, processing/history, question, result/failure; inspect legibility and scroll. Real mic/audio limitations of simulator must remain explicit.

Run ./native/check.sh after integration; independent review after passing checks, resolve blockers; signed device build with developer identity. Install in place, preserve recordings/Keychain, never uninstall as repair. Verify actual install and process launch. Hardware audibility, LTE, interruptions and real transcription latency require measured/device evidence; user smoke is separate. Update HANDOFF/VALIDATION with exactly what passed and what remains. Bundle all three sessions in one build; no partial worker deployment.
