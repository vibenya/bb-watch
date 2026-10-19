# Quick Voice — start, then Send

19 October 2026. Latest user-directed control revision. **Concept, not implemented
or covered by the earlier Fable approval.** Supersedes record-first v3 and the
older capture-control hierarchy; destination/history and delivery invariants remain.

[Three-state concept](direct-send-v4.png) · [generation brief](direct-send-v4-prompt.md).

The ordinary path has two actions: start recording, then tap the same dominant
control to finish and deliver. Pause is optional, never an intermediate required
step. A quick-start action may perform the first step; a second physical Action
Button press is not assumed supported without the existing hardware proof.

| State | Main lime button | Small left action | Small right action |
|---|---|---|---|
| Empty | Microphone → start | Hidden | Hidden |
| Recording | Up arrow + visible **Send** → finish/deliver | Pause | X cancel |
| Paused | Same up arrow + **Send** → finish/deliver | Microphone → resume | Same X cancel |

The Send word stays visibly attached to the arrow in both live and paused states.
No unlabeled checkmark authorizes transmission. The previous v3 checkmark implied
Save/finish while performing irreversible delivery; this revision addresses that
independent-review concern directly, rather than relying on setup-only teaching.
Only historical receipt glyphs may be checks.

Send seals, checkpoints and durably enqueues once; it does not merely save locally.
Guard the transition until durable enqueue; failure restores recoverable paused
audio. Before the first buffer Send is unavailable. The initiating touch cannot
also activate Send: transmission requires a fresh distinct tap. Quick-start while
already recording reveals the same recording, never sends it or starts another.

Pause checkpoints and stops the mic, leaving Send as the primary action. Resume
starts the same draft from the left action. X pauses/checkpoints, then confirms
before deleting nonempty audio; Keep returns paused. These side actions retain
their positions and never become Send. Haptics follow actual capture changes.

Keep local autosave, honest queued/received statuses, retained originals and the
existing no-replay rule after ambiguous acceptance. No pause, silence, dismissal,
interruption or app exit implicitly sends. No timed Undo is added in this proposal.

Use a small elapsed counter, real-input halo only while recording and paused
glyph while paused. Recipient and history stay below the controls. Remove prose
such as Resume, Finish & send and Settings fixed from the ordinary recorder.
Send is the short action label retained because its consequence must be explicit.
VoiceOver names all controls; native hit targets and state distinctions under
Reduce Motion/Always On remain required, unmeasured implementation checks.
