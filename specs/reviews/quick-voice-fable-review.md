# Quick Voice — independent Fable review

19 October 2026. Documentation/design review of the Quick Voice packet only.
Three passes: a first independent pass (07:30), a consistency readback (07:40)
after the lead's corrections and the tap-storyboard freeze, and a final
confirmation (07:45) after the F18–F21 corrections and the state-sheet freeze.
No implementation, build, install, ASR/Jev call or device action was performed
in any pass. The earlier 2.0 Fable review does not apply to this packet.

## Final verdict (07:45, final correction freeze)

**Content ready for user approval; runtime gates remain open.**

All twenty-one findings are resolved in the frozen packet: the seventeen from
the first pass and the four from the readback (F18 placement/haptic sentence
and regenerated paused panel, F19 checked current-context row, F20 three image
details, F21 restored generation briefs). Twenty-one walkthroughs pass. No
document blocker remains. The hashes below are the approved package; any later
edit to these files reopens the verdict for that file.

Accepted tradeoffs the user is approving explicitly:

- Finish & send is immediate with no Undo and no remote retraction; the caption,
  the stop glyph and the placement rule for the paused Finish capsule are the
  mitigations.
- No automatic pause on silence and no duration cap; an accidental quick-start
  records until paused, finished or interrupted by the OS/storage guard.
- Auto routing clarification happens on the computer; the watch shows Needs
  attention / Resolve on BB and offers no retargeting after enqueue.

This is approval of product/design content and a bounded proof plan. It is not
release approval, and every item under "Runtime gates" still has to be measured.

## Inputs reviewed — final pinned hashes (correction freeze 07:45)

| Source | SHA-256 |
|---|---|
| specs/reviews/quick-voice-approval-pack.md | ca54ed08997b73864d843dfb1d6391f2fafd7ff737da7c1656fa296602aee7d1 |
| specs/bb-watch-quick-voice.md (QV) | 117e430868b5cc61a8cc938ba06d1bb69d8f397b2f4041915b5382fd705c4f06 |
| docs/design/quick-voice-interactions.md (IC) | a3cace06af30ce6d404977ab81d8e31d47cd501d9865f4b30b4c6e33b03c0d4f |
| docs/design/quick-voice-interactions-v2.png (SB6v2) | 895798db67c5ec9507ba12e4981c596f47e0d196f1f28a48ebbfcdb5c8549416 |
| docs/design/quick-voice-states-v2.png (STv2) | b9f154f1953d45b614ad60d98d8a7c3ba7ba7bf00ff796f2761e0c47ffe31ac5 |
| specs/bb-watch-voice-notes-direction.md (VND) | 2a663d1c3f1e6b444157617a9393e2381a7846655f781d8ebd8a969824678085 |
| design.md | 0ee81b810be7f16121192bf59231739deaa1f1ac138a53e8f2fb7583182b98cb |
| docs/design/quick-voice-interactions-v2-prompt.md | f6b80cda670bbdeac9f5dbc8bedd6aa4ee14e1650727cb32e69edc8180185cf1 |
| docs/design/quick-voice-states-v2-prompt.md | 2bf1bf59c9102224b642f18ff0d0abc6775c21e6be495ada38583e6a3dfc37ed |
| docs/HANDOFF.md (pointer only) | f64df4ca900f8e2a0c4b50ff03649c3bcc2598a1d50932e57d4cbe0eccab1a6e |

`specs/bb-watch-architecture.md` was consulted only as the source of inherited
invariants and gates. Old sprites, archives, native source and private
conversations were not read in any pass.

Image inspection at the freeze: SB6v2 panel 02 shows Destination with Auto
checked, Watch sync, Release notes, + New thread, no To: prefix and no chevron
inside the picker; root pills keep To:, history rows keep the check beside the
caption and a trailing chevron. STv2 panel 03 shows Resume and Paused · 0:24
centred under the dashed-ring circle, the To: Auto pill below them and a
full-width outlined Finish & send capsule at the bottom; the former Pause spot
beside the circle is empty. Panel 02 has the Actions ellipsis, panel 04 shows
To: Auto under Saved locally, panel 06 has a pin glyph in the Pending thread pill.

## Readback dispositions F1–F17

| ID | First-pass severity | Disposition | Evidence in the corrected packet |
|---|---|---|---|
| F1 Paused state and Pause control undefined | Blocker | **Resolved** | QV "Pause, recovery and secondary controls": two-bar Pause during capture, dashed ring + mic glyph + Resume + Paused · m:ss, Paused · interrupted, outlined Finish & send capsule; VoiceOver labels per state. STv2 panels 02–03 |
| F2 Parked draft had no resume path | Blocker | **Resolved** | QV Saved locally detail: Play, Continue, Delete draft; Continue restores paused, parks other, mic off; empty composes never listed/enqueued. IC B Continue rules, live drafts not deletable. STv2 panel 04. I17 |
| F3 Destination persistence undefined | Blocker | **Resolved**, two notes | QV "Destination lifetime": Auto stays Auto; manual/Reply = one compose; New → Pending thread → title, explicit leave conditions; Add recording on pending-New detail; "still addressing" replaced by "while that context remains selected". IC C/D. I18. Notes: (a) a persistent-context pin and a one-compose Reply pin look alike on the pill; the frozen In/Model rows are the visible discriminator and QV could say so in one phrase; (b) IC says Add recording is on a *received* pending-New detail while QV says any pending-New detail; align to any enqueued (Queued or Received) recording, since the context is local |
| F4 Auto clarification surface undefined | Blocker | **Resolved** | QV normal experience: computer-side clarification, Needs attention / Resolve on BB, no watch retarget after enqueue. IC C, VND. I20 |
| F5 Optional override undefined | Blocker | **Resolved** | QV: New-only rows In: Auto project › and Model: Auto ›, separate X sheets, project-scoped models, no nested picker launch, incompatible model cleared visibly, frozen metadata with Settings fixed for this thread, Resolving project. STv2 panels 05–06. I19. No wizard |
| F6 Storyboard inconsistencies, idle glyph | Major | **Resolved** | SB6v2 and STv2: To: pill, microphone glyph, consistent chevrons with check beside caption, Destination title; old SB4/SB6 declared history in IC |
| F7 Accidental Finish without recovery | Major | **Resolved as explicit decision** | QV: no Undo/retraction, caption as mitigation, correct with another recording. I21. See F18 for a layout path that still needs one sentence |
| F8 Unattended quick-start recording | Major | **Resolved as explicit decision** | QV: no silence pause, no cap, real-start haptic, OS/storage guard; "explicit tradeoff, not a safeguard" |
| F9 Repair rules deferred to a disclaimed contract | Major | **Resolved** | IC B: five rules copied; "inherits architecture §6 reliability, not its UX" |
| F10 Per-part AAC boundaries | Major | **Resolved in text; proof is Gate G2** | QV compression row + Apple AAC priming/remainder citation; "separate proof, not an assumption" |
| F11 Accessibility statements | Minor | **Resolved; geometry is a gate** | QV: state labels, live indicator on all sheets/pages, Reduce Motion, Always On, 49/45 mm + large text; IC B detail Recording indicator |
| F12 Finish before first buffer, empty compose | Minor | **Resolved** | QV: Finish inactive before first buffer/pending permission/sealing; empty never enqueued. I21 |
| F13 Background-completion wording | Minor | **Resolved** | QV step 4: Queued until receipt; wrist-down timing is a gate |
| F14 Settings/pairing/permission absent | Minor | **Resolved** | QV: pushed Settings after Actions closes; Needs attention · Pair BB; Microphone access required |
| F15 Hosted processing not disclosed | Minor | **Resolved** | QV: plugin settings expose hosted ASR/routing services |
| F16 design.md body stale | Minor | **Resolved** | design.md "Historical 2.0 baseline — superseded for Quick Voice" banner; links moved to v2 sheets |
| F17 Reply caption, sheet title | Minor | **Resolved** | SB6v2 panel 06 without caption; IC "Destination sheet" |

## Readback findings F18–F21 and their dispositions

| ID | Severity | Disposition | Evidence in the frozen packet |
|---|---|---|---|
| F18 Paused Finish & send occupied the former Pause location | Major | **Resolved** | QV: "It sits below the destination pill, never at the former Pause hit area: a second tap at Pause must not become an irreversible Finish. Pause/Resume give a haptic on the actual state change." STv2 panel 03 regenerated accordingly; states brief records the edit prompt |
| F19 Destination sheet with a selected pending context | Minor | **Resolved** | QV: the selected New/Pending context is a checked row above the separate New thread action (e.g. Pending thread · Studio) |
| F20 Illustrative mismatches | Note | **Resolved** | STv2: ellipsis in panel 02, pin glyph in panel 06, To: Auto line in panel 04 |
| F21 Empty interaction v2 brief | Minor | **Resolved** | Both actual prompts restored in quick-voice-interactions-v2-prompt.md; states brief includes the final correction prompt |
| F3 notes (a)(b) | Note | **Resolved** | QV: "Frozen In/Model metadata distinguishes this persistent context from a one-compose Reply pin"; IC: Add recording for an enqueued (Queued or Received) pending-New recording |

Original F18 scenario, kept for the record: the user taps Pause, gets no haptic,
taps the same spot again to be sure, and the second tap lands on an outlined
Finish & send that the lead has deliberately made irreversible. The fix is a
placement rule plus a haptic, not an Undo.

## Walkthrough audit I01–I21 (corrected packet)

| ID | Text | Sheet | Result | Note |
|---|---|---|---|---|
| I01 | IC A1–A2, QV lifetime | SB6v2 01→03 | Pass | Pin resets to Auto after enqueue (F3) |
| I02 | IC A3 | — | Pass | — |
| I03 | IC A, QV live indicator | Not drawn, stated | Pass | — |
| I04 | IC A Pause to search; QV Pause | STv2 02 | Pass | Pause now exists on root |
| I05 | QV New thread 1–2 | SB6v2 02, STv2 05 | Pass | Checked current-context row (F19) |
| I06 | IC B | SB6v2 04→05 | Pass | Consistent chevrons |
| I07 | IC B | SB6v2 05 | Pass | — |
| I08 | IC C | SB6v2 05→06 | Pass | One-compose pin |
| I09 | IC C, QV parking | STv2 03→04 | Pass | Parked draft recoverable via Continue |
| I10 | IC B | — | Pass | Compose-replacing actions blocked while live; detail shows Recording |
| I11 | IC C | — | Pass | Resolve on BB |
| I12 | IC C | — | Pass | — |
| I13 | IC D, QV | STv2 03 | Pass | Empty Reply compose discarded |
| I14 | IC D, QV | STv2 02–03 | Pass | Paused Finish placed below the pill (F18) |
| I15 | IC stable state | — | Pass | — |
| I16 | IC B | SB6v2 05 | Pass | Draft deletion defined |
| I17 | QV, IC B | STv2 04 | Pass | Continue on the active draft is a no-op |
| I18 | QV lifetime, IC C/D | STv2 06 | Pass | Add recording for Queued or Received pending-New |
| I19 | QV overrides | STv2 05–06 | Pass | Separate X sheets; frozen metadata |
| I20 | QV, IC C, VND | — | Pass | Computer-side only, stated |
| I21 | QV Pause/recovery | STv2 02–03 | Pass | No Undo accepted; placement and haptic rule present |

All twenty-one walkthroughs pass on the frozen text and sheets.

## Approval-pack questions (final)

1. Destination vs past recording distinct: yes, by To: prefix, pin, separator,
   and now consistent row affordances in both v2 sheets.
2. X, Back, Play, Reply, Record, Finish, Pause, Resume, Continue predictable: yes;
   the paused Finish capsule has an explicit placement and haptic rule.
3. Recover or redirect without losing audio or sending twice: before Finish yes,
   including Pause, park, Continue; after Finish no, by explicit decision.
4. Live, paused, Reply, search, quick-start coherent: yes.
5. Auto / New / manual honest and consistent: yes; Pending thread labelling and
   one-compose pins are explicit.
6. Pending receipts preserve draft/recipient/focus: yes.
7. Optional overrides without a wizard or nesting: yes; New-only rows, separate
   X sheets, frozen metadata.
8. Lime control distinguishable without colour alone: yes; glyph, ring, caption
   and VoiceOver labels per state.
9. Technical proposal separates facts, experiments and evidence: yes, including
   the AAC boundary qualification.

## Runtime gates (not closable by document edits)

- Action Button → Shortcut → foreground intent: cold/warm press to first
  recorded buffer, consent flow, duplicate press, press while paused, no iPhone.
- Capture while not frontmost and through wrist-down, Crown press, other app;
  interruption and crash recovery of sealed parts (architecture G3).
- AAC-LC candidate: quality, decoded part-boundary timeline (F10), encode
  backlog, energy; AAC→PCM16→ASR RU/EN coverage and order against the same PCM
  source (G2).
- Finish → durable enqueue latency independent of network/ASR.
- Real LTE file-backed declare → parts → seal with screen asleep, dropped
  receipt, relaunch, force quit (G4); scoped remote plugin admission (G1b).
- Jev destination/model adapter: candidates, pin priority, durable per-recording
  decision, confidence calibration, provider/model mapping, ordered dispatch.
- Halo on Canvas/TimelineView: frame cost, energy, Reduce Motion, Always On.
- Native 49/45 mm default and large-text layouts, 44-pt hit targets for Pause,
  Resume, Finish capsule and the ellipsis; VoiceOver tour of root, sheets, detail.
- No exactly-once BB mutation and no instant background completion is claimed by
  any document in this packet; both remain unauthorised.

## Final confirmation

Nothing remains required. The lead reported no further source edits planned;
the hash table above is the reference for that statement. Implementation may
start reading this packet, with the runtime gates as the next go/no-go decision
and the lead as release owner.

---

## First pass (07:30) — findings as originally reported

Kept as the review record. Dispositions are in the table above.

### Inputs of the first pass

| Source | SHA-256 |
|---|---|
| specs/reviews/quick-voice-approval-pack.md | 07741ad7fa70dfe89f8abf2a82f1e6289e0cc60b69132a72577b2551f08683ad |
| specs/bb-watch-quick-voice.md | a31b8190d6223e26997e59e479cfce9b84c2d860f17d04d69ad31fcc2e37d2c5 |
| docs/design/quick-voice-interactions.md | 7c18a7ef6ea9d8d77e71ad0a8a6e30e589aa5805da5c6af666dfc37de735ed80 |
| docs/design/quick-voice-interactions.png | 344df27d0d2b6c59868bbeb87f2c10c26af42ddbcbe629fdf068e1cc0be27c5f |
| docs/design/quick-voice.png | 84f340a386410a1940f6df6b58a43ef25ae5944ccad8f8384c6ab2071c9025f0 |
| specs/bb-watch-voice-notes-direction.md | 68215acf88c9b62093bbe5e35b9b55ab925ed01107144095d0ee332853f6c13f |

Severity scale used: **Blocker** = must change before approval; **Major** =
same pass; **Minor** = when convenient; **Gate** = runtime proof.

### What held in the first pass

- Navigation: root → one sheet with X → root; root → pushed detail with Back →
  same root position; no nested sheets; no event-driven navigation.
- Finish & send as the only transmission; Pause, X, Back, interruption, silence
  and app exit never send; enqueue-once with a recoverable paused draft.
- Destination choices commit a local value only; New thread never creates a
  server thread; Reply never records or resends.
- Honest receipt vocabulary; routing errors separate from the audio receipt.
- Technical section separated Apple-stated facts, experimental codec, bitrate
  arithmetic and prior ASR evidence; AudioRecordingIntent excluded.

### F1 · Blocker · Paused compose state and the Pause/park controls undefined
QV named Pause/park as secondary actions; IC I04, I09, I10, I13, I14 depended on
a paused state; no storyboard showed Pause, Resume, a paused composition or park.
Scenario: after an interruption the user sees a still lime circle identical to
idle and cannot tell resume from new. Repair: define the Pause control, paused
composition, resume, park and interrupted variant.

### F2 · Blocker · A parked or unsent draft had no resume or send path
IC detail actions covered received recordings only. Scenario: a thought parked
by the Action Button was stranded. Repair: Saved locally rows and detail actions
(Continue, Finish from root, Delete); empty composes never listed.

### F3 · Blocker · Destination persistence after Finish undefined
"current/next recording" ambiguous; New implicitly sticky; pill "To: New thread"
wrong after first send; pending context unreachable once the pill changed;
"still addressing" semantic. Repair: one rule per intent; Pending thread label;
Reply/Add on pending-New decided; UI-state wording.

### F4 · Blocker · Auto routing failure had no user-facing recovery surface
Needs attention with no watch action and no statement that resolution is
computer-side. Repair: state Option A (computer) or B (Send to on received
audio) explicitly.

### F5 · Blocker · Optional project/model override declared but not defined
No entry point, labels, frozen presentation. Repair: New-only rows, single-level
X sheets, frozen metadata, or an explicit decision to keep Model off the watch.

### F6 · Major · Storyboards disagreed; row affordances inconsistent; idle disc without glyph
SB4 lacked the To: prefix; SB6 panel 04 mixed chevron and check as trailing
elements; the idle control had no glyph or caption. Repair: SB6 governs; one
trailing-element rule; glyph or VoiceOver label.

### F7 · Major · Accidental Finish & send had no recovery
Repair: decide explicitly between accepted risk and a short local Undo hold.

### F8 · Major · Unattended quick-start recording unbounded
Repair: decide silence auto-pause or accept and state; haptic on actual start.

### F9 · Major · IC deferred repair rules to a disclaimed contract
Repair: name or copy the inherited reliability rules.

### F10 · Major · Per-part M4A needed a gapless decode requirement
AAC priming/padding per part would gap or overlap at every boundary. Repair:
decoder honours priming/padding or encode continuously; part of Gate G2.

### F11 · Minor · Accessibility statements missing
VoiceOver labels per state, live indicator off root, Reduce Motion/Always On,
45 mm note.

### F12 · Minor · Finish before first buffer; empty composes
### F13 · Minor · Step 4 read as a background-completion promise
### F14 · Minor · Pairing, Settings, permission states absent
### F15 · Minor · Hosted processing not disclosed
### F16 · Minor · design.md body read as normative 2.0
### F17 · Minor · Redundant Reply caption; "Send to" title

### First-pass walkthrough result
I04, I09, I13 failed on the text; I03, I05, I10, I11, I14 passed only on assumed
state. All are re-audited in the final table above.
