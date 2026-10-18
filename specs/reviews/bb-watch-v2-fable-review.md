# BB Watch 2.0 — independent review of the product spec and design

Reviewer: Fable (architecture/review role). Date: 18 October 2026, revision 4
after three rounds of lead feedback. Status: **reviewed for gated Phase 0;
runtime gates unproven.** Every document-level finding is resolved or
dispositioned below; B1–B4 remain runtime release blockers, not document
defects. Scope: [product spec 2.0](../bb-watch-product-spec.md),
[design 2.0](../../design.md) and the [architecture](../bb-watch-architecture.md).
Old native source, archived documents and private recovery material were
deliberately not read; the review judges the intended product against current
platform contracts.

Severity scale: **Blocker** (the package cannot be approved until resolved),
**Major** (would produce a wrong or unreliable product), **Minor** (clarity,
scope or consistency), **Note** (confirmation or advice).

## 1. Verdict in one paragraph

The product boundary is right: the watch records, keeps originals, and delivers
raw audio to an exact BB target in the user's Send order; the computer-side
plugin owns intake, transcription and submission. That boundary is feasible on
the installed platform (BB 0.46.0, plugin SDK 0.6.37) using existing surfaces,
with two honest limits: dispatch to core is *one automatic attempt per
operation, with human reconciliation after ambiguous acceptance*, never
exactly-once (the intake transport itself retries idempotent steps), and
background execution on watchOS is scheduled by the OS without an ETA. The
revised spec and design use one flat navigation model, one active compose
context with explicit parking, pause-before-search, and confirmed abandonment
before any re-target. Four runtime gates are not yet proven by anyone: remote
ingress admission for plugin routes, long-audio behaviour of the configured
transcription service with the chosen segmentation, continued capture while the
watch app is not frontmost, and the complete declare → parts → seal chain while
the wrist is down. Everything below is a gated plan, not proven runtime readiness.

## 2. Blockers (proof gates, not document defects)

| ID | Finding | Evidence | Required resolution |
|---|---|---|---|
| B1 | **Remote ingress admission is unproven.** The watch reaches the computer over LTE only through a public URL. The installed server mounts plugin routes at `/api/v1/plugins/<id>/http/<path>` and exempts that path from the browser-origin check; token auth compares a static per-plugin token. Whether the BB remote-access URL forwards plugin routes to a non-browser client with raw bodies, and with what body cap and idle timeout, has not been exercised. | Installed bundle: plugin wire path exemption and token auth (lead-verified line references); SDK `PluginHttp` auth modes. No published body cap. | Two gates: G1a (plugin's own authorisation on loopback) and G1b (remote admission). A failed G1b **blocks** the plan and is answered by a scoped ingress or core capability, never by a core mobile session on the watch or a separate public proxy of the BB port. Architecture §4.2, §11. |
| B2 | **Long-audio transcription is unproven.** V07 depends on BB's configured voice service. The installed voice path caps a request at 25 MiB and gives the task a 70-second deadline (lead-verified). The selected service today is hosted (`bb cloud`), so audio leaves the computer. No measurement exists for the group sizes the plugin will send, nor for 16 kHz input (the existing bilingual evidence is 48 kHz PCM16). | `bb settings ai-services show`; installed constants (lead-verified); SDK `system.transcribeVoice({file: Blob})` → `{text}`. | Gate G2 exercises the chosen segmentation on 60, 240 and 600-second sources at 16 kHz and 48 kHz; it never sends a whole ten-minute file. |
| B4 | **The complete delivery chain while the wrist is down is unproven.** Each step (declare, every part, seal) is a separate background task whose callback and next-step scheduling the OS may defer; a single-file transfer test does not show that the chain completes and yields a receipt while the app is asleep. | Apple states background responses may be deferred and are delivered when the app next runs ([Making background requests](https://developer.apple.com/documentation/watchos-apps/making-background-requests)). | Gate G4 runs the production-shaped chain with four 60-second parts and a long fixture, intermittent network, relaunch, force quit and a dropped seal response, and records the measured envelope; an unacceptable chain revises the protocol before UI work. |
| B3 | **Capture while not frontmost is unproven on hardware.** Apple's frontmost-state article lists audio-recording apps among those that keep running for their audio session; the `AVAudioSession` record category page points to the `audio` background mode. The watchOS `WKBackgroundModes` reference does not list `audio`; no version or duration is stated. | [Frontmost app state](https://developer.apple.com/documentation/watchkit/taking-advantage-of-frontmost-app-state); [AVAudioSession record category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record); [WKBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes). | Gate G3 (capture), separate from gate G4 (upload). |

## 3. Findings on the product spec (against revision 2 of the spec)

| ID | Sev | Section | Finding | Status after the lead's revision |
|---|---|---|---|---|
| S1 | Major | §8 | Pairing must be plugin-owned; a core mobile session cannot authenticate a raw upload to a plugin route, and a plugin-wide token has no per-watch scope. | **Resolved** in spec §8. The architecture removed the mobile-session fallback; G1b failure blocks. |
| S2 | Major | §4 | Thread creation timing and the limits of metadata reconciliation. | **Resolved** in spec §4: creation at first dispatch; identity is not acceptance; ambiguous spawn reconciled or blocked. |
| S3 | Major | §3.3 | No state for capture ended by the system. | **Resolved**: `Paused · interrupted` with cause when known; cold start does not claim to know why. |
| S4 | Major | §4, §7 | Re-target or cancel only after a confirmed durable abandon; missing acknowledgements prove nothing. | **Resolved** in spec §4 and §7; tombstones outlive audio. |
| S5 | Major | §3.8, §9 | Transcription in ordered groups within the verified envelope; completed groups survive restart. | **Resolved** in spec §3.8 and V11. |
| S6 | Minor | §2 | Desktop inbox required in the complete release; CLI cannot replace it. | **Resolved** in design §8; architecture Phase 2. |
| S7 | Minor | §3.4 | Send pauses capture before opening the chooser. | **Resolved**. |
| S8 | Minor | §7 | Delete cases. | **Resolved** in spec §7. |
| S9 | Minor | §3.1, V01 | Microphone permission state. | **Resolved**. |
| S10 | Minor | §8 | Hosted voice service disclosure. | **Resolved**. |
| S11 | Minor | §7 | Storage reserve from measurement. | **Resolved** (gate G6). |
| S12 | Note | §4 | Thread list fields exist in the SDK. | No change needed. |
| S13 | Note | §6 | `Dispatch acceptance unknown` is resolved by a human; `sent`/`queued` is core acknowledgement only. | Spec §6 already states this; architecture §5.3–5.4 follow it with a single automatic intent per operation. |
| S14 | Minor | §2 | No notifications. | **Resolved**. |
| S15 | Major | §3.9 | One active compose context with explicit parking and Continue; several thoughts while unpaired. | **Resolved**. |
| S16 | Minor | §6 | The receipt row lists a "job ID"; the architecture issues one job per recording and returns `jobId` equal to `recordingId`. | **Resolved**: spec §6 now states that `jobId` equals `recordingId`. |
| S17 | Minor | §3.4, §4 | A New context may lack a project (first use, unpaired). The architecture treats such a target as incomplete: Send opens the Project picker; the draft can be parked. | Consistent; no spec change needed. |

## 4. Findings on the design (against revision 2 of the design)

### 4.1 Navigation model — accepted by the lead and now in the design

Apple's watchOS guidance, paraphrased with primary links: a watchOS sheet is a
full-screen modal view, to be used briefly and occasionally, not as a way to
navigate app content; Back is for steps, not for dismissing a sheet; title-like
text in the top-leading corner hides how to dismiss; one sheet at a time
([HIG Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)).
Modal views need an obvious dismiss control and should not stack
([HIG Modality](https://developer.apple.com/design/human-interface-guidelines/modality)).
"Minimize the depth of hierarchy in your app's navigation" and use the Crown for
vertical navigation ([HIG Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)).

The design's revision 2 flowchart (single-level Threads/Project/Model sheets,
New on the root, pushed Recordings/detail/Settings, detail popping to its real
invoker, no `Use target`, no swipe shortcut) matches the model this review
proposed. Rules the implementation must keep:

- Sheets never contain hierarchy; each commits at most one value on tap and
  dismisses; X and system dismissal commit nothing; the dismiss control is added
  explicitly with the system close symbol and never relabeled.
- New is a recorder state; Project and Model rows appear only for a New target
  and become read-only once the context's first recording is enqueued.
- Only one live microphone: cached recents during capture; `Pause to search`
  before any dictation; no auto-resume on dismissal; replay unavailable while
  recording; Record stops playback.
- Detail pops to its actual invoker (root or Recordings).

### 4.2 Other design findings and their status

| ID | Sev | Finding | Status |
|---|---|---|---|
| D2 | Major | Root draft restoration. | **Resolved** in design §4 (active compose ID, `New recording`, `Continue`). |
| D3 | Major | Desktop surface and audio in the thread. | **Resolved** in design §8: plugin inbox, audio stored by the plugin, no invented timeline API. |
| D4 | Minor | Pending activation. | **Resolved** in design §4 and §5: honest pending state, no success haptic or meter before real input, no timing claim. |
| D5 | Minor | Elapsed time and meter. | **Resolved** in design §1. |
| D6 | Minor | Settings as a pushed page. | **Resolved**. |
| D7 | Minor | Transfer captions. Acknowledged part counts belong in detail, not the main row; `Waiting for BB` needs a real server result. | **Resolved** in design §6. |
| D8 | Minor | Hit sizes. Apple's accessibility table gives watchOS a default control size of 44×44 pt and a minimum of 28×28 pt — [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility). | **Resolved**: design §5 cites the HIG Accessibility table. |
| D9 | Minor | Always On: privacy applies to data (titles), never to the fact that recording is live; controls remain interactive — [HIG Always On](https://developer.apple.com/design/human-interface-guidelines/always-on). | **Resolved** in design §7. |
| D10 | Minor | Haptics bounded; no background haptic or notification promise — [HIG Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics). | **Resolved** in design §6. |
| D11 | Major | Dictation search during capture would take the microphone. | **Resolved** in design §4. |
| D12 | Note | SwiftUI `.sheet` default dismiss control is not stated in the API reference. | **Resolved** in design §2 ("Add an explicit dismiss control"). |
| D13 | Note | watchOS background pages instead of the iOS page. | **Resolved** in design §9. |
| D14 | Minor | The PAUSED sketch in design §5 omitted the latest-delivery/Recordings row. | **Resolved**: the paused sketch now shows `Latest / Recordings` below `New recording`. |
| D15 | Minor | Design §3 did not say how frozen Project/Model rows look after the context's first Send. | **Resolved**: design §3 keeps them visible as read-only values without chevrons, with a short caption. |

## 5. Navigation walkthrough under the agreed model

| # | Start | Action | Result | Audio | Target |
|---|---|---|---|---|---|
| 1 | Root idle, no target | Record | `Starting…` then Recording; row says `Choose thread` | new active draft | none |
| 2 | Root idle | Recipient row | Threads sheet | unchanged | unchanged |
| 3 | Threads sheet | Tap thread | Dismiss; row shows title | unchanged | exact thread ID |
| 4 | Threads sheet | Tap `New thread` | Dismiss; row `New thread · <project>`; Project/Model rows appear | unchanged | New context |
| 5 | Threads sheet | X or swipe down | Root | unchanged | unchanged |
| 6 | Root, New not yet sent | Project row → pick | Dismiss; row updates | unchanged | project for this context |
| 7 | Root, New not yet sent | Model row → X | Dismiss | unchanged | unchanged |
| 8 | Root, New already sent once | Project or Model row | Read-only; no picker | unchanged | frozen |
| 9 | Recording | Pause | Paused; central control is Resume | current part sealed | unchanged |
| 10 | Recording or Paused | Send, target complete | Capture ends, parts sealed, manifest with Send order frozen, enqueued; root idle; latest row `Queued` | immutable | frozen |
| 11 | Recording or Paused | Send, no target or New without project | Capture pauses; Threads or Project sheet; root shows Paused with Send after a choice | unchanged | selected |
| 12 | Recording | Recipient row | Threads sheet, cached recents, recording indicator; search needs `Pause to search` | capture continues | applies to this draft |
| 13 | Threads sheet during capture | `Pause to search` | Capture paused and sealed; dictation field available | paused, no auto-resume | selected |
| 14 | Paused | `New recording` | Current draft parked `Unsent · Continue`; root idle | parked draft kept | none |
| 15 | History → parked draft | `Continue` | It becomes active; a currently paused draft is parked explicitly | kept | kept |
| 16 | Any sheet | Crown press | App backgrounded; sheet remains on return | continues if recording (G3) | unchanged |
| 17 | Paused draft | Cold start | Root restores the active compose context; `Paused · interrupted` if capture was live | sealed parts and committed prefix kept | kept |
| 18 | Root | `Recordings` row | Pushed list; Back returns to root unchanged | unchanged | unchanged |
| 19 | Root | Latest-delivery row | Pushed detail; Back returns to root | unchanged | shown |
| 20 | Detail, `Failed` before receipt | Retry | Same recording ID rescheduled | unchanged | unchanged |
| 21 | Detail, queued/not received | `Cancel delivery` | Abandon request; on confirmed `abandoned`: `Cancelled` with Delete and `Send to another thread`; if unreachable: `Can't cancel while BB is unreachable` | kept until confirmed | kept |
| 22 | Detail, `Cancelled` | `Send to another thread` | Threads sheet; new operation for the same audio; old one stays abandoned | unchanged | new, explicit |
| 23 | Detail, never-sent draft | Delete → confirm | Removed | deleted locally | — |
| 24 | Detail, `Received by BB` or unknown | `Delete local copy` → confirm | Local parts removed; row kept `on BB · does not retract` | deleted locally | — |
| 25 | Detail while recording | Replay | Unavailable with caption | unchanged | unchanged |
| 26 | Root | Settings → Forget pairing → confirm | Queue items freeze `Paired to another BB`; drafts stay recordable | kept | kept, frozen |
| 27 | Root with queued items | Wrist down | Uploads continue as the OS schedules; status reconciles on next open without another Send | unchanged | unchanged |
| 28 | Any | Cold start after force quit | Outbox reconciles via status query; missing steps rescheduled; a draft under capture becomes `Paused · interrupted` | kept | kept |

No path starts or resumes capture except Record/Resume; no dismiss control
sends, deletes or changes a value; no cancellation is shown before the plugin
confirms it.

## 6. Consistency check of the revised spec, design and architecture

| # | Where | Observation | Action |
|---|---|---|---|
| C1 | Spec §3.3 vs design §4–§5 | Caption wording. | **Resolved**: both use `Paused · interrupted`; the architecture and this review match. |
| C2 | Design §5 sketch | See D14. | **Resolved**. |
| C3 | Spec §6 receipt | See S16. | **Resolved**: `jobId` equals `recordingId` in spec and architecture. |
| C4 | Spec §3.4, design §3 | New without a project is an incomplete target. | Architecture §3.2 handles it; no change. |
| C5 | Design §3 | Frozen project/model rows after the first Send. | **Resolved** (D15). |
| C6 | Spec §4 "search on demand" vs design §4 | Consistent: search exists, dictation requires Pause. | None. |
| C7 | Spec §9 V09 vs architecture §5.1 | Send order is now carried in the manifest (`sendSeq`, predecessor list) and enforced per lane with context-to-thread aliasing; arrival order is never used. | Spec V09 is satisfied by design; the lead may add "Send order recorded at Send" to §4. |
| C8 | Spec §10 gates vs architecture §11 | Spec names six gate areas; the architecture has G1a/G1b, G2–G6 covering them plus the execution catalog. | Consistent. |
| C9 | Spec §8 vs architecture §4.2 | Spec forbids assuming a core mobile session; the architecture no longer proposes one. | Consistent. |

No document-level contradiction remains. B1–B4 are runtime release blockers
until their Phase 0 reports exist.

## 7. Evidence versus assumption

| Claim | Status | Source |
|---|---|---|
| Plugin can register raw HTTP routes with token or self-verified auth | Verified | SDK `PluginHttp.route`; installed token comparison |
| Plugin owns durable SQLite with migrations; synchronous mode can be set on the handle | Verified / plugin-set and checked at load | SDK `PluginStorage.database()`, `migrate()` |
| Plugin can call BB's configured transcription | Verified | `system.transcribeVoice({file: Blob})` → `{text}`; Telegram plugin precedent |
| Transcription cap 25 MiB, voice task deadline 70 s | Lead-verified in installed bundle; not in SDK docs | installed server constants |
| Selected voice service is hosted | Verified today | `bb settings ai-services show` |
| Send/create have no idempotency key; `sent` carries no message ID | Verified | SDK request/response schemas |
| Create accepts `providerId`, `model`, `pluginMetadata`; plugin-created threads can be listed | Verified (metadata listing is experimental) | SDK `createThreadRequestSchema`, `threads.list({originPluginId})`, `experimental_listPluginMetadata` |
| Project-scoped execution catalog calls | Exist; exact arguments to be documented | gate G5 |
| Background upload tasks persist after the watch app closes; delivery may be deferred | Apple-stated | Making background requests |
| Capture continues when not frontmost with the audio background mode | Apple names audio-recording apps; hardware proof required | Frontmost app state |
| Remote URL forwards plugin routes to a non-browser client | **Assumption** | Gate G1b |
| 16 kHz PCM16 is adequate for bilingual ASR | **Assumption**; existing evidence is 48 kHz | Gate G2 |

## 8. Scope challenges

- **Keep**: pause/resume, explicit Send, chooser with New, outbox, receipts,
  history with replay/delete/continue, pairing, inbox page.
- **Dropped**: `Use target`, nested sheets, left swipe, engine-start Cancel,
  timed progress animation, notifications, audio attachment in the thread,
  automatic local cleanup, a broad CLI, dispatch hook and provenance tagging.
- **History stays a pushed list**; the root's first screen is the capture
  control with one latest-delivery row.

## 9. Disposition of lead findings

### Round 1

| # | Lead finding | Disposition |
|---|---|---|
| 1 | No safe cancellation or re-target without confirmed abandon; tombstones; ledger outlives audio | Addressed: S4, S8, walkthrough 21–24; architecture §3.3, §4.1 (`DELETE` on an unknown id creates the tombstone), §4.3 permanent rows |
| 2 | Metadata proves identity, not acceptance; hook is a checkpoint; no replay on absence; evaluate provenance | Addressed: architecture §5.3–5.4 single intent, `core_submitted` only on positive result, unknown otherwise; hook and provenance removed |
| 3 | One active compose context with explicit parking | Addressed: S15, D2, architecture §3.1 |
| 4 | Dictation search steals the microphone | Addressed: 4.1 rules, D11, walkthrough 12–13, 25 |
| 5 | Remove the activation timing claim; keep a pending state | Addressed: D4, architecture §3.1 |
| 6 | Detail pops to the real invoker | Addressed: flowchart in design §2, walkthrough 18–19 |
| 7 | Exact Apple hit-size table; privacy on data only; capture and upload proofs separate; no force-quit detection | Addressed: D8, D9, B3, architecture §3.1, §3.5 |
| 8 | Apple quotations ≤ 25 words per source | Addressed: paraphrase with one short quotation; the architecture has none |
| 9 | ASR group cache across restart; lane blocking; G2 exercises segmentation | Addressed: S5, architecture §5.2, §11 |
| 10 | Small CLI; inbox in the complete release; gated plan versus readiness | Addressed: S6, architecture §2.2, §11, status line |

### Round 2

| # | Lead finding | Disposition |
|---|---|---|
| A | Send order must be recorded at Send and enforced per lane with aliasing | Addressed: manifest `order` (§3.2), `predecessor` rows and §5.1 |
| B | Invalid hook decision values; `seen_by_core` and metadata are not acceptance; one automatic attempt per operation; no unguarded `Dispatch again` | Addressed: hook removed; §5.3 single intent; §5.4 guarded `Send again` with overt duplicate-risk confirmation |
| C | Provider and model as a pair from a project-scoped catalog; freeze after the first Send | Addressed: §3.2 `execution`, §4.4, gate G5, walkthrough 8 |
| D | No mobile-session fallback; G1b failure blocks | Addressed: §4.2, B1 |
| E | Frame-aligned durability, checkpoints, recovery, per-write disk guard; 16 kHz unproven; byte arithmetic | Addressed: §1, §3.1 steps 2–4; sizes corrected (1,920,000 bytes per minute; four parts for four minutes) |
| F | Stream ASR groups; no whole-recording buffer; bounded provider calls | Addressed: §5.2 |
| G | Session wake handling, `getAllTasks`, `taskDescription`, bounded background retry | Addressed: §3.4 |
| H | watchOS 26 and current Xcode; inbox in release; mode `auto`; no setting proliferation | Addressed: §2.1, §5.3, §13 |
| I | Pair route limits before reading; ownership on all routes; tombstones fence seals; quota includes all states and WAL; full durability | Addressed: §4.1, §4.3, §7 |
| J | Builder brief excludes review/archive/supersession text; history reachable; migration keeps delivery state; backup and bundle gates | Addressed: §8, §12 |
| K | Reproducible proofs in the worktree; no live prompts in tests; valid JSON example; no hard-coded test count | Addressed: §10, §11, §3.2 (JSONC marked) |

### Round 3

| # | Lead finding | Disposition |
|---|---|---|
| R3.1 | G4 must exercise the production-shaped declare → parts → seal chain while the wrist is down, with a measured envelope and no preset latency number | Addressed: architecture §11 G4; review B4 |
| R3.2 | "At-most-once delivery" overstates transport/core guarantees | Addressed: wording is now "one automatic dispatch attempt per operation, with human reconciliation after ambiguous acceptance"; intake transport retries idempotent steps (architecture §1, review §1) |
| R3.3 | §5.1 must state that already-received earlier recordings stay ordered by `send_seq` although absent from the predecessor list; regressions for slow-ASR predecessor and context alias collision | Addressed: architecture §5.1 rules 1–2, §10 V09 (a)–(c) |
| R3.4 | Manifest example arithmetic (`totalFrames` versus one part); frame-sum validation at declare and seal | Addressed: architecture §3.2 example shows four parts for 240 s and the validation rule |
| R3.5 | Logical retained bytes with reservations versus physical headroom; allocated database size is not a quota; retention frees capacity | Addressed: architecture §4.3 |
| R3.6 | S16, D14, D15, C1, D8 closed by the root's final edits | Addressed: dispositions above |

Rejected: none.

## 10. What this review does not claim

No build was run, no device was touched, no live prompt was sent. Installed
bundle line references were verified by the lead, not by this reviewer. Apple
pages are paraphrased with at most one short quotation per page. Nothing here
is an Apple approval, a reliability measurement or a release-readiness
statement.
