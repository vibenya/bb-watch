# Quick Voice — approval packet, 19 October 2026

**Corrected review packet; see the independent review for the current verdict.** This is approval of
product/design content and a bounded proof plan, not production release approval.

## Current sources in precedence order

1. [Quick Voice product/design variant](../bb-watch-quick-voice.md): two-action
   capture, lime control, compressed transfer candidate, Auto/manual/New intent.
2. [Interaction contract and I01–I21 walkthroughs](../../docs/design/quick-voice-interactions.md):
   exact target tap, history detail, Reply and asynchronous-state semantics.
3. [Six-panel interaction storyboard](../../docs/design/quick-voice-interactions-v2.png)
   and [capture/recovery state sheet](../../docs/design/quick-voice-states-v2.png).
4. [Voice-notes direction](../bb-watch-voice-notes-direction.md): user decisions
   superseding the older 2.0 navigation and mandatory-target intake assumptions.

The earlier [architecture](../bb-watch-architecture.md) is a source of existing
reliability invariants and unproven platform gates, **not an approved engineering
contract for Quick Voice Auto routing or AAC**. The old Fable review does not
approve this packet. Older sprites and native source are not current UX authority.

## What the reviewer must decide

- Are destination selection and a past recording visibly/semantically distinct?
- Are X, native Back, Play, Reply, Record and Finish & send predictable?
- Can a user recover or redirect a thought without losing audio or sending twice?
- Are live recording, paused compose, Reply, search and quick-start coherent?
- Are unresolved Auto and explicit New/manual choices honest and consistent?
- Do pending receipts/routing events preserve the current draft/recipient/focus?
- Is optional manual project/model configuration defined without recreating a
  mandatory wizard or nesting modal sheets?
- Does the lime recording control remain accessible and distinguishable from a
  successful receipt without relying only on color?
- Does the technical proposal separate verified API facts, experimental codec
  settings and actual hardware/reliability evidence?

## Proofs that content approval cannot waive

Action Button/Shortcut cold/warm launch to first input, watch background capture,
AAC quality/continuity/energy and AAC→PCM16→ASR bilingual coverage, complete
file-backed LTE intake with lost-receipt/restart recovery, own scoped remote
plugin admission, and the durable Jev destination/model/order adapter. No instant
background-completion or exactly-once BB mutation claim is authorized.

## Expected review output

Record a severity-ranked finding list with affected source, concrete failing
scenario, repair and disposition. Review I01–I21 explicitly. Separate document
blockers from runtime go/no-go gates. Report one of:

- Content ready for user approval; runtime gates remain open.
- Content needs revision, with exact changes required before another decision.

After lead corrections, read the actual updated package and state which findings
remain. Pin final file hashes. Do not implement, install, create a worktree, start
Astra, send real prompts/ASR/Jev requests, or mark a new release complete.

## Lead dispositions after first Fable pass

- F1–F2: visible Pause, distinct paused/resume composition, Actions → New
  recording, Saved locally detail → Continue, confirmed draft deletion and empty
  compose rules are defined and drawn in the new state sheet.
- F3: exact/manual Reply pin is one-compose; New is a visibly persistent local
  context after first enqueue (Pending thread). Add recording reselects a pending
  context without fabricating a thread. Auto stays Auto.
- F4: exception recovery is explicitly computer-side in this version; the watch
  says Resolve on BB and preserves the audio receipt.
- F5: optional In/Model rows exist only for New, use separate X pickers, and
  become frozen metadata after first enqueue. No setup wizard is introduced.
- F6/F11/F17: v2 sheets use To:, microphone glyph, consistent history chevrons,
  Destination title and no redundant Reply caption. Required accessibility and
  live-capture indicators are explicit; native geometry remains unmeasured.
- F7/F8: immediate Finish has no Undo; silence has no automatic pause. These
  tradeoffs are stated, with Finish caption and actual-start haptic; neither
  navigation nor silence sends anything.
- F9/F10: uncertain-receipt safety rules are copied into the current contract;
  decoded AAC boundaries must preserve the original timeline.
- F12–F16: no empty enqueue; no background timing promise; pairing/permission,
  secondary Settings, configured hosted services and historical-design scope are
  explicit.

These are lead dispositions, not the final reviewer verdict. The independent
review records whether the actual corrections resolve each finding.

Readback corrections: paused Finish is below the destination pill, never at the
former Pause hit target, with haptics on actual pause/resume. The Destination
sheet shows the selected New/Pending context checked separately from New thread.
Add recording is available for enqueued pending-New rows (Queued or Received).
The final capture sheet includes the Actions ellipsis, pending-context pin and
draft destination; both actual generation briefs are saved.
