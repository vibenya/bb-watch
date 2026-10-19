# BB Watch — voice-notes direction update

18 October 2026. **User direction adopted; routing implementation contract still
requires review.** This updates the product intent of [specification 2.0](bb-watch-product-spec.md)
and [design](../design.md). The reviewed architecture does not yet implement this
routing extension. No application change is claimed.

## Decisions

Only simplicity-audit proposals 3 and 4 are adopted: merge latest receipt and
history below the recorder, and reduce ordinary visible status vocabulary.
Do not treat the audit's separate proposals to remove model selection or replace
New configuration with flattened project destinations as approved. Automatic
routing below is a new direction, not permission to silently remove explicit
target/model overrides.

The primary layout is now the lime (`#D5FF00`) recording control, then the current destination
or Auto, then scrollable history/status. It resembles a voice-notes recorder.
There is no separate history page or competing direct-latest-detail shortcut.
An item may open the one native detail route; Back restores the root position.
Settings and explicit chooser utilities remain secondary.

## Automatic destination and model routing

- Ordinary capture may use Auto. The user can say which existing thread or new
  task/project the thought belongs to; the computer-side plugin performs ASR and
  uses Jev-assisted logic to select an existing thread or create a new one.
- Before that logic runs, Auto is an intent, not a known recipient. The watch
  must not display the last active thread as a confirmed destination.
- An explicitly selected thread, and especially Reply from a history item,
  pins the exact server thread ID. Automatic matching cannot silently override
  it. The pinned recipient remains visible below the capture control.
- Reply starts a fresh compose context for that thread; it does not immediately
  activate the microphone, transmit audio or resend the previous recording.
- The plugin may route model choice through Jev. Existing-thread behavior and
  any explicit provider/model choice must follow a verified BB contract; do not
  assume the discovered model proxy already preserves overrides.
- A materially ambiguous spoken destination is held for resolution, with the
  audio retained and a visible attention state. Never use the nearest title or
  last active thread as an undocumented fallback. The precise clarification
  interaction and confidence policy are implementation-design work.
- Persist the routing decision before submission. Retries and later catalog
  changes cannot silently pick a different recipient/model for the same job.

## History and status

History identifies the user's recordings, their actual destinations once known,
and delivery facts. Repeated destinations may be grouped by thread with a Reply
action; do not add a full agent conversation reader by implication. Unknown Auto
destinations stay honestly unresolved until the plugin reports its decision.

Main/list vocabulary is Saved locally, Queued, Received by BB and Needs attention,
with familiar glyphs and short captions. Causes and transfer mechanics are detail
information. Received by BB still means durable audio ownership, not successful
routing, transcription, BB submission or agent completion. A later routing error
does not revoke that receipt; attention is a separate processing fact.

## Contract changes that must precede implementation

The previous architecture requires a complete frozen recipient at intake. Auto
requires accepting a frozen routing intent before its final thread exists.
Extend the manifest, receipt/status projection, authorization checks, ordering
and reconciliation explicitly. Preserve exact destination identity for Reply,
durable decisions, New correlation and per-recipient Send order even when ASR
and routing finish out of order. A generic inbox receipt must not claim that a
particular thread already accepted the message.

Local research found a Jev model-tier router prototype and typed Jev classifier
precedents. The inspected sources did not prove an existing semantic-thread
router, durable destination decision, BB provider/model mapping or Reply override.
Reuse verified mechanisms, but validate this adapter rather than claiming it
already exists. No live Jev/provider request was made for this research.

## Visual direction

See [references and button recommendation](../docs/design/voice-notes-references.md).
Keep the lime control primary, a black stop glyph during recording, the recipient
below it, and restrained lime voice-reactive motion. See the latest
[Quick Voice variant](bb-watch-quick-voice.md) for explicit New thread behavior.
The earlier 12-panel sprite is
historical context for 2.0; it is not the new auto-routing composition.
