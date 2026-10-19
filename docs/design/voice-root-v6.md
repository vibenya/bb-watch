# Quick Voice — recording and history, no default destination row

**Superseded:** [voice terminal v7](voice-terminal-v7.md) removes recording history,
playback and detail/Reply/New pages. Only recorder and one Threads sheet remain.

19 October 2026. Latest user-directed revision, **not implemented or covered by
the frozen Fable review**. Supersedes v5's persistent Auto pill and saved Play
control; preserves BB's waveform and Enter/square/X icon language.

[All-state concept board](voice-root-v6.png) · [generation brief](voice-root-v6-prompt.md).

## Ordinary recorder

Root contains the microphone/input controls, then a separator and history of
individual recordings. There is **no Auto label, default recipient row or thread
list beside the recorder**. The plugin routes spoken instructions through Jev.
A prior history title never implies the target of a new recording.

| State | Primary recording cluster |
|---|---|
| Empty | Lime microphone starts a fresh recording |
| Recording | Real left-to-right waveform; X / square / lime curved Enter |
| Stopped/saved | Static waveform; X / microphone / same lime Enter |

Square stops the mic and durably saves the current draft without sending.
Its place becomes a microphone, **not Play**. Tapping that microphone appends to
this same draft/recording ID, preserving old audio, destination intent and order;
the control becomes square again. It does not replace audio, start a second
recording or create another thread. Enter finishes and enqueues directly from
either live or saved state; no mandatory stop/resume step precedes sending.
X retains the existing checkpoint-and-confirm-discard behavior.

Playback is only in history detail. Starting/resuming capture first stops any
playback. Autosave, guarded enqueue, original retention, no mutation replay after
ambiguous acceptance and connection isolation remain. No timer, Send label,
decorative halo or save-like checkmark transmission action is introduced.

## Secondary targeting

The small root ellipsis opens one Actions sheet with Close X. Destination opens
its single-selection sheet only after Actions closes; Settings is pushed after
the same dismissal. New recording checkpoints/parks any nonempty current draft
and returns to fresh idle automatic compose; it never sends. Destination contains
Automatic, authorized recent threads
and New thread. Automatic is a default policy visible **only inside this picker**.
Picking it returns to root with no recipient chip.

Manual thread choice or Reply shows a pin and that thread's title below controls.
The chip exists only for an explicit target; its small X clears the target to
automatic without deleting audio. Its VoiceOver label is Clear recipient,
distinct from the recording-control X, Discard recording. Tap the chip to reopen
Destination. Exact manual/Reply pins apply to one compose and disappear after
durable enqueue. Quick-start still starts a fresh automatic draft, parking any
nonempty saved one; repeated quick-start during capture opens that capture only.

Explicit New is a persistent local context: New thread → Pending thread → real
title. Keep the pin until deliberately cleared/replaced; never fabricate a real
ID. Optional project/model pickers remain secondary Actions entries only when
New is selected; each opens after Actions closes. They are editable before first
enqueue and frozen afterward, inspectable there rather than repeated on root.
Selecting another project visibly resets an incompatible model as before.

## History and navigation

History rows represent audio, not selectable thread destinations. Each has the
known title or Voice note while unresolved, receipt/attention glyph, age and one
detail affordance. Crown scroll reveals more rows on the same root. Enqueue
returns to ready recording controls and adds a queued row, not a completion page.

Tap a row → one pushed detail with native Back, local Play, accurate receipt and
Reply only for a known authorized thread. Reply returns to idle root with the
exact pin; it never starts capture. A pending-New Add recording action retains
the existing context dependency. Saved locally detail restores a draft stopped
on root; the center microphone appends. No detail action resends accepted audio.

Received by BB still proves audio storage, not routing or agent completion.
Unresolved/routing-failed items retain that receipt with Resolve on BB, and offer
no fabricated Reply or automatic resubmit. Async updates never change another
draft's target, current navigation or microphone state. The board illustrates
ordinary states and secondary navigation, not OS permission/setup dialogs or
hardware acceptance. Native layout, accessibility and delivery gates remain open.
