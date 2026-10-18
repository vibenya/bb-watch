# BB Watch v2 — simplicity audit

18 October 2026. **Proposal, not an adopted specification change.** Based on the
[reviewed product contract](../bb-watch-product-spec.md), [design](../../design.md)
and a separate read-only product critique. No usability study or native test was
performed for this proposal. The existing spec, architecture and sprite remain
the baseline until changes are explicitly adopted together.

## Recommendation

Simplify the decisions people make, rather than compressing the same controls
onto a smaller screen. The normal job needs: capture a thought, identify its
destination, explicitly send, and trust the retained audio and receipt.

Two everyday surfaces suffice: a recorder with history below it, and a recipient
chooser. One occasional recording-detail page remains for playback, Continue,
deletion and recovery; connection setup remains a utility. This is not a claim
that every error can be handled by two screens.

## Concrete cuts

| Current entity | Proposed change | What is actually lost |
|---|---|---|
| Model picker, catalog, invalid overrides, frozen-model explanation | New threads use the project's BB default; remove model controls from the watch | Deliberately choosing a different model from the wrist; this changes an explicit existing requirement |
| New recorder configuration plus Project picker | Put destinations such as `New in BB Watch` directly in the recipient chooser alongside existing threads | Separate configuration UI; project choice itself remains |
| Project/Model rows on the recorder after New | Remove both; the target row already identifies `New in <project>` | In-place configuration, which is redundant once the chooser selects a complete destination |
| Latest-receipt shortcut plus Recordings entry plus history page | Put one recording list below the recorder, reached by Crown scrolling; its first item is the latest receipt | Dedicated history page and duplicate route to the same item |
| Two ways into recording detail | Any history row opens the same detail from the root; Back always returns to that root position | A navigation branch, not playback or recovery |
| Sending, waiting causes and receipt reconciliation as prominent statuses | Main/list vocabulary: Saved locally, Queued, Received by BB, Needs attention; expose causes only when relevant | Transport stage visibility at a glance; no underlying state is discarded |
| Computer ASR stages in watch detail | Keep processing and repair on BB; watch detail ends at audio receipt | Watching transcription from the wrist |
| Detailed normal desktop job dashboard | One compact inbox; attention-needed items prominent, completed history secondary, detail on demand | Routine exposure of groups, hashes, transport steps and raw acknowledgements |

No new global default destination is introduced. A project name in the New
destination is visible before Send. Selecting an existing thread never asks for
a project. Keep recent destinations near the top and search for the rest in the
same chooser; do not render every project as a new configuration form.

## Smaller interaction model

```text
RECORDER                       CHOOSE DESTINATION
Watch sync                 >   X                  Send to
                                Watch sync             ✓
             ●                  Release notes
                                New in BB Watch
                                New in School

History, by scrolling
✓ Watch sync · Received by BB
◷ Release notes · Queued
  Unsent · Continue
```

The drawing is a flow sketch, not measured native geometry. Capture mode adds
Pause and explicit Send at stable anchors; New does not change the composition.
Keep the small recording indicator, secondary elapsed time and genuine input
feedback. Do not add a new icon-only language to save a few characters.

Existing destination: Record → speak → Send. The last deliberately chosen
destination stays visible and can be reused. Changing destination is optional,
not a mandatory review screen before every Send.

New destination: Record → choose `New in <project>` → Send. No model choice,
required title, extra Create button or configuration page. If Send first opens
the chooser because no destination exists, choosing still returns to the paused
recorder for an explicit Send. Removing that last tap would silently make a
selection transmit audio and change the agreed dismissal contract.

## Scenario check

| Scenario | Preserved path or explicit limitation |
|---|---|
| Thought while unpaired/offline | Record without target; autosave; Pause; New recording parks the thought. Other thoughts remain possible. No fabricated destination. |
| Several thoughts before sending | Keep New recording and Continue; drafts are ordinary history rows, with no separate Drafts area, names or folders. |
| Four-minute recording, wrist down after Send | Same durable outbox, original chunks and background transfer; UI cuts do not relax hardware proof gates. |
| Follow-up before a New thread exists | Target still means the same pending context; stable context ID and Send ordering remain internal. Choosing `New in <project>` again explicitly creates an independent context. |
| Need a different model | Use a suitable existing thread or configure the project's default in BB. A one-off watch model override is no longer supported by this proposal. |
| Need another project | Select its `New in <project>` destination; project selection is not replaced by an invisible universal default. |
| Target mistaken before Send | Change the visible destination without creating/sending anything. |
| Target mistaken after Send | Rare safe cancellation/replacement remains a recording-detail action, subject to confirmed server abandonment. Never pretend an offline Cancel retracted an unknown operation. |
| Final receipt response lost | Keep Queued while reconciling the same operation; detail explains the uncertainty. Never create a fresh send to make the status look successful. |
| Desktop transcription fails | Watch receipt stays Received by BB. Desktop inbox exposes Retry ASR with retained audio and cached groups. |
| BB submission acceptance unknown | Desktop reconciliation and explicit duplicate-risk handling remain; no automatic repeat. |
| OS interrupts capture | Restore the same paused draft and explain the interruption; resumption stays explicit. |
| Playback or deletion needed | Tap a history row for the one detail page. Playback cannot steal a live microphone; deletion retains the existing safety rules. |
| Incoming receipt while inspecting another draft | Update only its history row; no navigation, target replacement or scroll jump. |

## Cuts rejected or deferred

- **Do not collapse record, pause and Send into one ambiguous button.** Removing
  controls at the cost of an unclear destructive/transmitting action is worse.
- **Do not auto-record on launch, auto-send on Pause/exit or auto-route by ASR.**
  The user remains in control of microphone, transmission and exact destination.
- **Do not delete multiple drafts to simplify storage.** It would force a user
  to send or discard one thought before saving another while unpaired.
- **Do not flatten recording detail into a collection of expanding controls.**
  Keeping one native push avoids playback, deletion and recovery controls
  competing with the live recorder. Removing the separate history page is enough.
- **Do not make queued cancellation a normal recorder button.** The independent
  critique proposed removing watch cancellation/retargeting from the first
  release entirely. The lead recommends retaining the rare safe detail action:
  dropping it loses correction of a mistaken destination, not just visual noise.
- **Do not remove the desktop repair surface.** A successful audio receipt with
  an unrecoverable processing failure would strand the user's thought.
- **Do not remove durable IDs, pending-New context, part acknowledgements,
  ordering, reconciliation or abandonment fences.** Hide those entities from the
  normal interface; their absence would compromise recovery and delivery.

## Independent critique and disposition

The separate reviewer agreed on the strongest cuts: watch model choice, visible
New-context configuration, duplicate receipt navigation and prominent transport
states. It also warned against removing project choice, pending-New identity,
multiple unsent drafts, exact recipient visibility or desktop recovery.

The reviewer proposed retaining a separate history page. The lead instead
recommends history on the root scroll, matching the requested gesture and
eliminating the two detail-entry paths; detail itself stays. Cancellation was
considered separately above rather than being silently removed.

## Adoption boundary

The first proposed revision should remove watch model selection, select complete
New destinations in one chooser, merge receipt/history navigation, and reduce
ordinary status presentation. These are product decisions, not just new pixels.
Update spec, design, architecture, acceptance and concept together if adopted.
In particular, remove the optional-model catalog dependency from the watch plan;
still verify project-default spawn and project routing. Authentication, capture,
segmented ASR, complete background delivery and recovery gates remain required.
