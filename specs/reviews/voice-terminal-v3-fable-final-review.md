# Voice terminal 3.0 — final independent Fable review

19 October 2026, published commit `8e1a2eacd809d7c6a466338aac630c5ee95dc639` on
`main` plus the lead's uncommitted bounded corrections (frozen 11:07).
Documentation/design review only. Two passes: the independent review (10:55)
and the final readback of the corrected files (11:10).

## Evidence scope

- Read in full: product specification 3.0, design 3.0, transition/error
  contract, v8 generation brief, HANDOFF entry section. Visually inspected
  `docs/design/voice-terminal-v8.png`. The Opus transition review was read only
  after the findings below were formed, to check overlap.
- Consulted for inherited invariants and gates only: the 2.0 architecture, as
  the packet itself directs. Its superseded UX was not treated as a requirement.
- Not read: native source, recordings, session history, archived specifications.
- No code, build, install, device action, provider/ASR/Jev call, worktree or
  runtime check. No statement here is runtime evidence; concept artwork is not
  geometry, HIG conformance or platform proof.
- Apple platform statements were verified on 19 October 2026 against the
  official documentation pages listed in "Platform statements verified"; the
  exact supporting sentences are quoted there.
- Earlier Fable approvals (2.0 packet, Quick Voice packet) are historical and
  approve nothing in this packet.

## Final verdict (readback 11:10)

**Ready; runtime gates open.**

All ten findings of the independent pass are resolved in the frozen files
(dispositions below). The readback found no new consistency defect: alert and
dialog identifiers used by transitions and scenarios all exist in the catalogue;
every gate named by a scenario exists in §14.3; every product acceptance ID
P01–P22 has at least one scenario; the two new scenarios bring the count to 122
with no duplicate or out-of-order identifier; the companion SVG matches the
shape table and the indicator text. No root-owned correction is required before
the hash freeze. Two optional wording items remain for a later pass (O1, O2
below) and do not affect the verdict.

Content is ready for user approval. Implementation remains blocked by BLK-1..3
and release by every open core gate in contract §14.3; this review adds no
runtime evidence.

### Accepted tradeoffs the user approves

- Direct Enter without confirmation or Undo; quick-start appends to a stopped
  draft (now with a distinct append haptic and announcement).
- No history, playback or success state; absence of the indicator is never a
  receipt claim.
- Deterministic whole-store corruption stays blocked in the first release
  pending developer-assisted non-destructive recovery; no empty replacement
  store, set-aside, reset or uninstall is a repair path.
- Post-receipt ASR/routing/dispatch problems are recovered in full BB only.

### Readback dispositions

| ID | Independent-pass severity | Disposition | Evidence in the frozen files |
|---|---|---|---|
| F1 indicator slot undefined and undrawn | Major | **Resolved** | Spec §7, design, contract §3 and DSC-1: top-leading recorder toolbar slot opposite the system clock, neutral dot / outlined exclamation-circle, one hit region, never the thread glyph. New `docs/design/voice-terminal-v8-delivery.svg` shows both variants during live capture with X/square/Enter unchanged |
| F2 waiting only after a failed attempt | Major | **Resolved** | Term W-wait (G6); §7.1, DSC-6 ("Absence of an indicator is never a receipt claim"), DSC-7 (runs from durable enqueue, persisted basis, re-evaluated at the next OS-granted UI update, no wake deadline), E1 trigger, OUT-01, new OUT-19; spec §7; design |
| F3 store-blocked dead end | Major | **Resolved by the explicit-limitation alternative** | Spec §7 paragraph; design; contract §3 text, T-03, new LIFE-5, new LIF-07, new A-STORE-HELP ("Recovery help is needed. Recordings are kept." Try again · OK); T-04 names Try again in A-STORE and A-STORE-HELP. Retry is not a repair promise; nothing reset, deleted or replaced |
| F4 eyes-free append indistinguishable | Major | **Resolved** | T-09 split; state table `live` entry; §11.1 new = system start / append = system retry; VO `Continuing recording`; CAP-13; spec §3; design. Actual distinguishability is measured in TG-U |
| F5 glyph shapes undefined | Minor | **Resolved** | §6.1 shape column: branch, dash, three equal bars, question bubble, flag, warning triangle, outlined diamond, slashed bubble; checkmark reserved for selection; v8 raster ring/check declared illustrative; companion SVG takes precedence; design paragraph |
| F6 ">" for inline peek | Minor (optional) | **Resolved** | §6.2/§6.3 down/up expander; recorder row keeps its chevron (lead's call) |
| F7 copy edge cases | Minor | **Resolved** | A-ENQUEUE-SPACE ("Watch storage full / Recording kept.") in T-25 and SND-04; T-17/T-18 cancel a pending discard, show only the failure alert, X must be tapped again |
| F8 queued haptic mapping | Minor (optional) | **Resolved** | §11.1 queued = system click, never success; distinction tested in TG-U; design |
| F9 background recording not named by Apple | Note | **No change needed** | Gating unchanged; no runtime claim added anywhere |
| F10 HANDOFF qualifier; legacy URL | Minor | **Resolved** | HANDOFF "(gate TG1)"; contract §8 retires the legacy mic-starting `bbwatch://record` route as A-LINK-BAD and separates the configured quick-start entry |

### Optional items for a later pass (non-blocking)

- O1 Issue dialogs D-E4, D-E6 and D-E7 are reachable only by the naming
  convention in DSC-3 ("Tapping an item opens a native dialog with its
  actions"); the E4/E6/E7 rows in §7.3 do not cite their dialog IDs the way E3
  and E9a cite D-E9. One parenthetical per row would make the binding explicit.
- O2 The E1 reason `Waiting for BB` also appears for an item in a long but
  progressing transfer once W-wait elapses (DSC-7). This is the lead's
  deliberate simplification and is truthful (not yet received); a later pass
  may consider a `transferring` wording if G4 measurements show routine long
  transfers.

## Pinned inputs (final, frozen 11:07)

| File | SHA-256 |
|---|---|
| specs/bb-watch-product-spec.md | 4e4ee88f277a8c717034f03d214202dc4333cb3937846e5229f40a2824fee934 |
| design.md | fd7464676e26f55d590096f86f1629312491bec7b2c210b1a14cefbe0fcffba8 |
| specs/bb-watch-transition-contract.md | fe6987738dfb2789c7b02792a1e76b35076cff1bf2feaae6a0cc05881cf4a585 |
| docs/design/voice-terminal-v8.png (unchanged) | 578061fcc5d1be82ee8b8cb31310c5e06026e29255005a1181737ad5035ad083 |
| docs/design/voice-terminal-v8-prompt.md (unchanged) | 4938b3adf46e4ca1323d874c3dbb1629e74224010df4f2dee8b4a1c652f2e125 |
| docs/design/voice-terminal-v8-delivery.svg (new) | 0510bc7df179566c75865056cc8e54c88d6a6f4075a6a46a2313c6bb6b6b576a |
| specs/reviews/voice-terminal-opus-review.md (historical banner only) | 89c9642d43237462de9706c82b7fe013fae560ace50b6c8383a8c19a3861de9b |
| docs/HANDOFF.md | fd0836220ce894c4c24ccace6cdd41941595d92f0db0693f125b749e8e17685c |

Any later edit to a pinned file reopens this verdict for that file. The
independent pass (10:55) reviewed the committed versions whose hashes are kept
in "Independent pass inputs" at the end of this file.

Readback checks performed on the frozen files: full read of every diff against
the committed versions; visual inspection of the companion SVG and its rendered
preview (two live-capture recorders, waiting dot and outlined exclamation in
the top-leading slot, X/square/Enter and the lower row unchanged, working glyph
as three equal bars); mechanical counts (40 transitions, 122 scenarios: OUT 19,
LNK 15, CTX 14, CAP 13, SND 9, TAP 9, SET 9, INT 8, LIF 7, PRE 6, STO 5, DIS 4,
GLY 4; no duplicate, rows in numeric order); catalogue cross-reference (every
A-/D- identifier used outside §12 exists in §12); gate cross-reference (every
gate named by a scenario exists in §14.3); P01–P22 coverage; link integrity of
every relative link in the five documents.

## Findings of the independent pass (10:55), kept as the review record

Dispositions are in the readback table above.

Severity: **Major** = fix before user approval; **Minor** = fix when convenient;
**Note** = no document change required. Class: *document defect*, *gate* (needs
device/integration proof), *optional* (preference, lead's call).

### F1 · Major · document defect · The issues indicator is the only delivery-feedback control and it is never positioned or drawn

Location: contract §3 ("one fixed position in the input region, outside the
X / center / Enter slots and the lower row"), §7.3 DSC-1; design "One lower
component"; v8 panels 01–03 show no indicator slot.

Walkthrough: a user in context A has an E6 item; they start recording in B.
The contract requires an attention indicator to be visible during capture and
tappable without stopping the microphone. The specification says where it is
*not* (not in the three slots, not in the row) but not where it is; the artwork
never shows either variant. TG-U is asked to measure "indicator discoverability
and hit areas" of a control that has no defined slot or shape family in any
document, so the gate cannot be written as a test.

Smallest fix: one sentence naming the slot (recommended: the top-leading
toolbar position, opposite the system clock, the slot watchOS uses for
Close/Back on sheets, so it never competes with X/center/Enter), and one
annotated artwork variant or a fifth panel showing the recorder while `live`
with the attention variant and, separately, the waiting variant. Keep it
non-red and non-lime per DEF-10.

### F2 · Major · document defect · "Waiting" is attempt-based, so an OS-deferred transfer looks delivered

Location: contract §7.3 E1 ("Attempt could not reach BB"), OUT-01 ("after
failed attempts waiting indicator"), DSC-1 waiting variant; specification §3
("Returning to ready is not a delivery-success claim").

Walkthrough: the computer is asleep; the user Enters three thoughts and lowers
the wrist. watchOS defers the background session without making an attempt.
Apple: "Background sessions may be deferred based on the system's state,
network connectivity, and other issues" (Making background requests). No
attempt fails, so no waiting dot ever appears. With no history and no success
state, the absence of the dot is the user's only signal, and it now means
"delivered or never tried" indistinguishably. Hours later the user believes
three thoughts reached BB.

Smallest fix: add a second trigger to E1: an item not `received` within a
bounded time since enqueue (W-wait, value from G6) also shows the waiting
variant and the `Waiting for BB` reason, whether or not an attempt ran. One
clause in §7.3 and in OUT-01. This keeps DSC-6 (no success state) intact and
makes "no dot" honest.

### F3 · Major · document defect · `store-blocked` has no bounded exit on deterministic failure

Location: contract §3 ("store-blocked is not a dead end: its center Retry stays
available"), T-03/T-04/T-04b, LIFE-2, INV-06 ("never reset the store"); design
"dismissing its alert must not strand the user".

Walkthrough: the local store's index is corrupt in a way that every open
rejects. Each launch yields `store-blocked`; every Retry fails within W-drain
and shows A-STORE-REOPEN; relaunch repeats. Nothing is reset or deleted, which
is correct, but the user can never record again and AGENTS.md forbids
uninstall as a repair without preserving recordings. Per-item quarantine (E10)
covers damaged artefacts, not a store that cannot open. The design's own
sentence "must not strand the user" is unmet.

Smallest fix: one row and one dialog. After N consecutive failed restores
(N from G6), the A-STORE alert gains a third, explicit, user-chosen action
that moves the entire store aside into a quarantine directory (never deletes,
ledger and audio kept), then starts an empty store: D-STORE-ASIDE "Set saved
recordings aside?" body "They are kept but will not be sent. Recording
resumes empty." buttons `Set aside · Cancel`. Record it under RET-5 as a
quarantine. Alternative if the lead prefers no such action: state in §10 that
the documented recovery is a developer-assisted restore and that the app stays
blocked, so the limitation is explicit rather than implied.

### F4 · Major · safeguard respecting DEF-05 · Eyes-free quick-start appends to a forgotten draft with no distinguishable signal

Location: specification §3 (quick-start appends within the visible context;
"the visible context and stopped waveform identify it, and actual capture gets
its own haptic"); contract DEF-05, T-30, CAP-13, §11.1 (one `start` haptic for
T-09 in both new and append).

Walkthrough: yesterday the user stopped a draft in thread A and forgot it.
Today, sleeve covering the watch, they press the Action Button for an
unrelated thought. Apple: "People often use the Action button without looking
at the screen" (HIG, Action button). The mitigation named by the specification
is visual; the only non-visual signal, the start haptic, is identical for a new
recording and an append. The thought is appended to A's old audio and, when the
user later glances and taps Enter, both go to A.

The decision to append stands and is not reopened. Smallest safeguard: in §11.1
give T-09 in `starting(append)` a distinct haptic from `starting(new)` (for
example the system `retry`/double pattern versus `start`), and add a VoiceOver
announcement `Continuing recording` for the append case. One table row and one
word in CAP-13 ("start haptic" → "append haptic").

### F5 · Minor · document defect · Glyph vocabulary has no shapes; the artwork's choices collide

Location: contract §6.1 lists glyph *facts* (routing, idle, working, question,
done, failed, unknown, unavailable, not paired) but only two shapes anywhere
(attention exclamation, waiting dot). v8: the working glyph is a partial lime
ring; the done glyph is a checkmark in a circle; the current-row selection is a
bare checkmark.

Why it matters: INV-10 and the design insist the thread glyph must never be
read as upload/ASR progress, yet a partial ring is the universal progress
motif, and the design allows a progress treatment for input-region transients.
Two checkmarks with different meanings sit in the same sheet list.

Smallest fix: a shape column in §6.1 (working = non-ring symbol, done ≠
checkmark, failed = neutral shape, unknown = outline) and a sentence that
input-region transient indicators and thread glyphs never share a shape family.
Regenerate panel 04's done glyph or annotate it as illustrative.

### F6 · Minor · optional · Trailing ">" used for inline expansion and for opening a sheet

Location: v8 panel 04 current row "Game idea ✓ >"; recorder lower row ">".

A trailing chevron conventionally promises a pushed page. Here it toggles an
inline peek (sheet) or opens a sheet (recorder). HIG Sheets for watchOS warns
against cues that suggest hierarchical navigation. Preference: use an expander
glyph (chevron.down/up) for the peek; keep the recorder row's chevron only if
the lead accepts the sheet idiom. No text change required.

### F7 · Minor · document defect · Two copy edge cases

- A-NOT-QUEUED after T-25 when the known cause is storage shows "Not sent /
  Recording kept" with no cause; the user may retry Enter repeatedly. Reuse the
  "Watch storage full" title when the commit failure is a space error.
- T-14 (X while live) seals first; if the seal fails (T-17/T-18) the text says a
  pending switch/link/pairing is not applied but does not say what happens to
  the pending D-DISCARD. HIG Alerts: never more than one alert at a time. State
  that the failure alert replaces the pending discard and X must be tapped again.

### F8 · Minor · optional · Map the `queued` haptic to a system pattern that is not success

Location: contract §11.1 "queued: distinct from start, stop and failure; not
'delivered'". HIG Playing haptics: "Use system-provided haptic patterns
according to their documented meanings." Name the WKHapticType (for example
`.click`) so an implementer does not pick `.success`, which would contradict
"not delivered".

### F9 · Note · gate evidence · Background audio *recording* is not among the sessions Apple names

Apple, Background execution: "Apps that support workouts, audio playback, or
location updates can continue to run in the background until the current
session ends." Enabling Background Sessions names "Audio, Location updates, and
Workout processing" modes and "Use the class to play extended audio files in
the background." Recording is not named. The packet already gates this (G3,
INT-02/03, specification §7 "legitimate background recording is a hardware
gate"). This note only strengthens that classification: no document should
imply wrist-down capture before G3 is measured, and the Always On statement
"capture and `starting` continue" (INT-2a) must stay inside TG10/G3.

### F10 · Minor · document defect · HANDOFF wording and the legacy URL scheme

- HANDOFF says "reply links reopen the same recorder" without the TG1 qualifier
  the specification carries; add "(gate TG1)".
- HANDOFF's historical section records that the installed 0.2.0 deep link
  `bbwatch://record` starts the microphone without confirmation. The 3.0
  contract forbids any link from starting the mic (INV-02). Add one sentence to
  §8 or TG1 that the legacy scheme is retired or rejected (A-LINK-BAD) so the
  old behavior cannot survive into a rewrite by default.

## Dimension audit (independent pass; defects named here are resolved per the readback table)

1. **Navigation, Close/back, hit areas, irreversible sends.** One sheet with a
   visible X and system dismissal equal to Close; no nested sheets; dialogs
   serialized (HIG Modality: "Let people dismiss a modal view before presenting
   another one"; "never display more than one alert at the same time"). Direct
   Enter without confirmation is the user's decision and holds; the contract's
   TCH-3 re-arm interval, TCH-6 stable slots and TCH-2 held-touch rule cover the
   state-change races, including the large ready microphone over the old Enter
   area. Residual risk is adjacency of square and Enter on 49 mm: keep it in
   TG-U with a concrete acceptance (visual gap, no hit-area expansion of Enter
   toward the center, both ≥ 44 pt per HIG Buttons). F1 and F4 are the only
   comprehensibility defects found.
2. **State reachability and safe exits.** Every transient has a bounded exit
   (INV-16); double tap, held touch and late callbacks are specified (TCH-1–7,
   T-11b); storage, stall, interruption, short/long/append and crash cases
   are covered (T-15–T-18, T-25–T-27, STO, INT, LIF). F3 is the one unbounded
   terminal state. Always On and Reduce Motion match HIG Always On ("prefer
   transitioning an interactive component to an unavailable appearance", "make
   infrequent, subtle updates") and HIG Accessibility (Reduce Motion, 140 %
   text scaling on watchOS). Dynamic Type claim "three controls reachable
   without scrolling" is a TG-U measurement, correctly gated.
3. **Thread selection, peek, drafts, links.** One editable draft per context,
   switch seals first, destination restores its own draft, same-context no-op
   (CTX-01–14). Link validation order and per-state application are complete
   (§8, LNK-01–15) and honestly gated (TG1); Apple's SwiftUI `onOpenURL`
   documentation confirms only the generic URL/Universal Link mechanism, not a
   watch notification path, so the gate is right. Sticky exact target plus
   "spoken conflicting routing is held" is the correct safeguard against
   wrong-recipient sends after a link-induced switch.
4. **Outbox, unknown seal, deletion, order, store, migration, marks.** INV-04
   atomic enqueue, INV-08 same-ID reconciliation with `Check again` and no
   `Send again`, §7.5 delete table with seal-free/fence semantics, ORD-1–6
   barriers with the honest "no unrestricted progress while an unbound
   destination is unknown", RET-1–5, LIFE-1–4, SET-08/E9 import rules and
   INV-18 immutable marks are consistent with the specification. F2 (deferred
   transfer visibility) and F3 (store dead end) are the gaps.
5. **Cross-document consistency.** Specification §3 table, design anchors
   table and v8 panels 01–03 agree on lime mic, waveform, X/square/Enter and
   red REC with white circle; no timer, Send label, title or halo appears.
   Design mermaid matches T-05/T-09/T-10/T-12/T-19/T-24/T-25. PRE-04/PRE-05 and
   the §12 catalogue agree with INV-15. Counts verified. Only F5/F6 (glyph
   shapes, chevron idiom) and F10 (HANDOFF wording) are inconsistencies; no
   unjustified complexity was found that a scenario-safe removal would improve.
   No BB reader is proposed; the inline peek stays bounded and hidden in
   Always On.
6. **Classification.** Document defects: F1, F2, F3, F5, F7, F10. Safeguard on
   an accepted decision: F4. Optional: F6, F8. Gate evidence: F9. The packet's
   own gate taxonomy (core/feature/deferred) is sound; G3 deserves the Apple
   citation above.

## Platform statements verified

Verified 19 October 2026 against the official Apple pages linked below (read
through developer.apple.com's documentation data endpoints for the same
paths). Excerpts are paraphrased; short quotes are kept under 25 words per page.

| Packet claim | Apple source | What the page states | Status |
|---|---|---|---|
| watchOS sheet is full-screen, modal, needs an explicit dismiss cue | [HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | In watchOS a sheet is a full-screen view sliding over current content and is always modal; a top-leading label that reads like a page or app title leaves people unsure how to dismiss | Supports the Close X and plain title |
| No nested sheets; one alert at a time; dialogs resolved before a link applies | [HIG: Modality](https://developer.apple.com/design/human-interface-guidelines/modality) | Dismiss one modal view before presenting another; never show more than one alert at the same time; always give an obvious way to dismiss | Supports §8 and TCH-7 |
| Always On: static truthful state, hide peek/issue text, no decorative motion | [HIG: Always On](https://developer.apple.com/design/human-interface-guidelines/always-on) | The dimmed display keeps showing the app while it is frontmost or running a background session; hide sensitive information; make infrequent, subtle updates; prefer an unavailable appearance over removing a control | Supports §11.3; TG10 remains a measurement |
| Background upload persists after the app closes; timing is not guaranteed | [Making background requests](https://developer.apple.com/documentation/watchos-apps/making-background-requests) · [WKURLSessionRefreshBackgroundTask](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask) | A background session persists even if the app closes; sessions "may be deferred based on the system's state, network connectivity, and other issues"; a short runtime means an asynchronous transfer cannot be assumed to finish before suspension | Supports G4 wording, DSC-7 and OUT-19 |
| Background capture is a gate, not a given | [Background execution](https://developer.apple.com/documentation/watchkit/background-execution) · [Enabling Background Sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions) | Apps supporting workouts, audio playback or location updates may keep running until the session ends; the session must start in the foreground. Audio recording is not named | G3 correctly open (F9) |
| Action Button runs an App Shortcut; eyes-free use | [HIG: Action button](https://developer.apple.com/design/human-interface-guidelines/action-button) | Pressing the button runs the associated App Shortcut; "People often use the Action button without looking at the screen" | Supports TG9 and motivated F4 |
| 44 pt controls, spacing, 140 % text | [HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) · [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | A button needs at least a 44×44 pt hit region; watchOS default control 44×44 pt, minimum 28×28 pt; spacing matters as much as size; allow text enlargement of at least 140 percent on watchOS | Supports TG-U acceptance text |
| Alert button titles | [HIG: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | Always title a canceling button "Cancel"; avoid "OK" as the default unless the alert is purely informational; use the destructive style for unintended destructive actions | §12 conforms; `Keep recording` in D-LINK-LIVE is an acceptable verb phrase |
| Haptics follow documented meanings | [HIG: Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) | Use system haptic patterns according to their documented meanings; build a clear causal link between haptic and action; avoid overuse | Motivated F8; §11.1 now names click/retry/start |
| Links reach the app as URLs | [onOpenURL(perform:)](https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)) | A view modifier receives incoming URLs, including Universal Links passed directly as URLs; routing depends on scene structure | Generic only; watch notification → app path stays TG1 |

Not verified here and correctly gated by the packet: Shortcut-triggered
foreground intent latency on Ultra 2, same-device notification launch, AAC
part-boundary integrity, intake admission, Jev routing contracts.

## Required before user approval (independent pass) — all applied

F1–F4 applied as recorded in the readback table; F5, F7, F10 applied; F6 and
F8 applied by the lead's choice. Nothing remains required.

## Runtime gates (unchanged by this review)

Implementation blockers BLK-1 (unbound routing intake), BLK-2 (fences and
definitive non-acceptance), BLK-3 (remote admission). Core release gates G1b,
G3, G4, G6, TG2, TG3, TG4, TG10, TG11, TG13, TG-U; feature gates TG1, TG5,
TG7, TG8, TG9, TG12; deferred TG6. Every scenario marked gated in contract §13
needs recorded device or integration evidence; this review adds none.

## Handoff

- This file is the only artefact owned by the reviewer; frozen at the hash
  reported to the root thread and left uncommitted. No other file was edited.
- Root owns integration, commits, publication and closure of the canonical
  work item; the reviewer does not close it.
- Next check, if any pinned file changes again: re-read the exact changed
  files, re-pin hashes and record whether the verdict holds.

## Independent pass inputs (10:55, committed versions)

| File | SHA-256 |
|---|---|
| specs/bb-watch-product-spec.md | 89b9564cc30a3f8f92af4d857c5dc73bcea31117051ba8f9afcc61429b0610db |
| design.md | 465d2cd6de4d30cb38114165648a5bb968334dc8b30653de59a029138a73aea6 |
| specs/bb-watch-transition-contract.md | ae2430ff33fa6d5c0ada37b884327b2bd5e6fb1124cc44bc1a714a30021c1254 |
| docs/design/voice-terminal-v8.png | 578061fcc5d1be82ee8b8cb31310c5e06026e29255005a1181737ad5035ad083 |
| docs/design/voice-terminal-v8-prompt.md | 4938b3adf46e4ca1323d874c3dbb1629e74224010df4f2dee8b4a1c652f2e125 |
| specs/reviews/voice-terminal-opus-review.md | 06611c06ece05a385034e66ba6501cf285b92953119a07776d8a3a744cfa0e88 |
| docs/HANDOFF.md | ce8279e4561a5ab95b7c25bf0d986d2d7769f768623abd807f993e08a9806ae2 |
