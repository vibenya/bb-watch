# Quick Voice — a voice terminal, two surfaces

**Superseded:** [product 3.0](../../specs/bb-watch-product-spec.md) and
[current design](../../design.md), including red REC instead of microphone after
Stop and the full transition/error contract. This remains an archived concept.

19 October 2026. Latest user-directed scope reduction. **Not implemented or
covered by the earlier Fable review.** Supersedes v6's history/detail/Reply pages,
New context UI and persistent delivery copy. The normal job is record → send →
record → send. Messages are read in BB and notifications elsewhere.

[Compact concept](voice-terminal-v7.png) · [generation brief](voice-terminal-v7-prompt.md).

## 1. Recorder

Only recording controls and **one current-thread/status row** below them.
No recording list, receipt page, playback, extra recipient chip or duplicate
thread selector. No Recording title, Received by BB, Resolve on BB, New thread,
Send label or elapsed timer on the ordinary watch surface.

- Empty: lime microphone starts capture.
- Recording: real left-to-right waveform; X / square / lime curved Enter.
- Stopped: static waveform; X / microphone / same Enter. The microphone appends
  to the same saved recording, not another message.
- Enter finishes and durably queues delivery from either live or stopped state.
  Return to ready capture without waiting for ASR, routing or agent execution.
  Square stops/checkpoints locally; it never sends. X confirms nonempty discard.

No required pause step, Send text, up-arrow or checkmark transmission action.
Guard enqueue and the fresh-tap boundary; retain audio on failure. A return to
ready does not claim delivery. Async transport status belongs to the input
control (brief progress, recoverable failure glyph/haptic), never to thread state.
Native errors may show short actionable text on demand, not permanent status prose.

The single lower row shows actual thread title + activity glyph + chevron.
Thread glyphs mean actual idle/working/question/done/failure from BB; do not infer
working from upload, transcription or audio receipt. Unknown/stale state is
neutral, never fabricated Done. No per-recording transfer labels live in this row.

Without a bound recipient the same row shows BB and a routing glyph, not Auto,
New or the last unrelated thread. This is a routing context, not a fabricated
thread. Once a real target is explicitly bound, show its actual title/activity.
BB mode stays BB until an explicit choice/link; a late route/receipt never changes
the current context or retargets another recording. Resolved targets are available
through actual BB notifications and the thread chooser.

## 2. Threads sheet

Tap the single lower row → one sheet with system Close X, current context and
authorized recent threads. Picking another thread closes the sheet and prepares
that context; no capture/send. The BB routing choice leaves target selection to
the plugin using spoken instructions. No separate thread-creation, project or
model forms: request those verbally or configure them in full BB. Jev performs
the existing server-side routing/model job subject to verified authorization.

The current thread can be inspected by expanding its row **inline in this same
sheet**, showing at most a short original BB activity/message excerpt and status.
No new reader route, response player, recordings detail or explicit Reply page.
Full conversation and detailed notifications stay in BB. Close restores the
recorder without starting the microphone or changing a recipient.

Selected thread context persists across repeated record/send until changed.
An exact manual or notification-link target is never silently overridden by Jev;
the BB routing choice is explicitly unbound. Quick-start uses the current visible
context; during active capture it reveals that capture, never sends or starts a
second one. This supersedes the older always-Auto quick-start/reset rules.
No pin and history row are duplicated.

## Notification reply and retained drafts

A reply link identifies an authorized connection/thread and opens **the same
recorder**, with that thread in its single lower row. It does not open a new
reply screen, start capture or send. Parse/authorize the exact ID, never a title
match; reject invalid/cross-pairing targets without redirecting to another chat.

Switching contexts checkpoints/stops nonempty current audio and retains it with
its original context. Returning to that context restores its stopped draft for
append or send. No history page is required to recover it; the context selector
can mark a retained draft with a small mic glyph. Never silently retarget recorded
audio or replace it with a new empty compose. Queued recordings stay separately
durable and bound; selecting a new context cannot mutate prior queued delivery.

Inbound-link routing from actual BB notifications to the standalone watch is
a required proof, not an assertion that a phone URL remotely launches a watch.
Verify cold/warm launch, device destination, auth, duplicate/stale links and
nonempty draft handling before promising this path. The product URL/wire contract
must be coordinated with the plugin; no scheme or existing support is invented.

No user-visible recording history does not remove persistent audio/outbox safety:
original retention, identity isolation, idempotent intake and no replay after
ambiguous BB acceptance remain mandatory. Playback is outside this app's scope.
Usability, native layout, background capture/LTE, compression/ASR and routing gates
remain open. VoiceOver names icon actions and thread states; Reduce Motion and
Always On remain truthful without decorative animation.
