# Quick Voice — original BB recording language

**Superseded:** [voice root v6](voice-root-v6.md) removes the default Auto pill
and replaces saved Play with microphone to append; playback is in history detail.

19 October 2026. Latest user-directed revision; **not implemented or covered by
the earlier Fable approval**. Supersedes v4's Send label, up arrow, halo, timer
and pause controls. Retains the normal start → direct send flow.

[Concept](bb-composer-v5.png) · [generation brief](bb-composer-v5-prompt.md).

Use the original BB composer's vocabulary and quiet neutral styling, adapted to
native watch hit areas. Preserve the lime accent on the start/Enter actions.
During recording, audio amplitude bars/dots progress **left to right**; no fake
loop or decorative halo. On watch the full-width waveform sits above its action
row to retain usable native hit targets. No elapsed-time counter is displayed.

| Icon | Recording | Saved draft |
|---|---|---|
| Curved Enter/Return arrow | Finish and durably enqueue delivery | Enqueue this saved audio |
| Filled square | Stop input and checkpoint/save locally; do not send | Replaced by Play for local preview |
| X | Stop/checkpoint, then confirm discard of nonempty audio | Confirm discard |

Enter is the same curved leftward return symbol as BB, not an upward arrow,
paper plane or checkmark. No visible Send text. Square has a separate neutral
button, so local save and network delivery cannot be mistaken for one action.
This explicitly replaces the prior visible-label design at the user's request;
the earlier concern about hiding send behind a save-like checkmark is addressed
by removing that checkmark and matching BB's distinct Enter/save-square mapping.
Icon recognizability still needs native usability validation; do not claim it
proved by artwork alone.

Stopping leaves the same draft on screen, waveform static and mic off. Play
previews locally and never sends. Enter remains at the same position and can
deliver immediately without resuming capture. A fresh quick-start parks saved
audio in history before beginning another Auto recording. There is no mandatory
pause/send sequence and no separate Save confirmation screen.

Local autosave remains continuous. Guard Send until first audio and during
sealing/enqueue; require a fresh tap after start, keep originals on failure and
never replay ambiguous BB acceptance. Receipt/history ages are allowed; recording
duration is absent from the recorder. Recipient and history stay below controls.
VoiceOver labels remain explicit: Send recording, Stop and save recording,
Discard recording, Play recording. Confirmation/error details may use concise
text; the ordinary recorder uses icons. Preserve Reduce Motion, static truthful
Always On state and distinct capture/playback ownership. Starting capture stops
local playback first. Device continuity, energy and LTE gates remain unproven.
