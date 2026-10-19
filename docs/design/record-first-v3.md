# Quick Voice — record-first control

**Superseded:** [direct-send v4](direct-send-v4.md) restores start → Send as the
normal two-action flow and removes the ambiguous checkmark transmission action.

19 October 2026. User-directed visual revision; **not implemented or covered by
the previous Fable approval**. Supersedes the v2 capture-control hierarchy and
root explanatory copy only. Routing, receipts and audio-retention rules remain.

[Three-state concept](record-first-v3.png) · [generation brief](record-first-v3-prompt.md).

One dominant lime button controls the microphone. Sending never replaces its
function. Secondary controls keep fixed positions around it.

| State | Main button | Left | Right |
|---|---|---|---|
| Empty | Microphone → begin | Hidden | Hidden |
| Recording | Pause → checkpoint/pause | X → cancel | Check → finish and deliver |
| Paused | Microphone → resume same draft | X → cancel | Check → finish and deliver |

The check seals and durably enqueues once, from live or paused state. It is not
a local-only Save: finishing still authorizes delivery to BB. Local autosave is
continuous and requires no button. Before the first audio buffer both secondary
actions are absent; while sealing they cannot be activated again.

X checkpoints/pauses first; deleting nonempty audio requires confirmation. Keep
returns paused, never automatically resumes. A pause position never becomes a
finish position. Start/pause/resume give haptics on actual state changes.

Remove visible Record/Resume/Paused/Finish & send sentences and root metadata
explanations. Use the mic/pause glyph, real-input halo, small elapsed digits and
small paused glyph. The recipient capsule below the cluster shows Auto or the
target title; no To prefix. History remains visually separate below a divider,
with receipt glyph/age and full details on tap. New project/model controls remain
secondary; do not expose frozen-setting explanations on the normal recorder.

VoiceOver retains explicit Record, Pause recording, Resume recording, Cancel
recording and Finish and send to BB labels. Teach the check's delivery meaning
once during setup, not through permanent root copy or a confirmation per send.
Preserve scalable text, native hit targets and static truthful Reduce Motion /
Always On states. Rare errors, deletion confirmation and receipt details still
use concise text. Hardware geometry, energy and background delivery remain gates.
