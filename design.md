# BB Watch — voice delivery design

Version 2.0 · 18 October 2026. Reviewed design for a fresh build,
not the installed application. [Product contract](specs/bb-watch-product-spec.md).
[Architecture and gated plan](specs/bb-watch-architecture.md).
[Fable review](specs/reviews/bb-watch-v2-fable-review.md).

## 1. Design principle

The watch answers: am I recording, where will it go, and has BB safely received
it? The computer owns transcription, conversation and agent execution.

One full-screen native recorder is the root. Respect real watchOS safe areas,
time/system chrome, Crown scrolling, lists and toolbar controls. No inner phone
frame, custom floating navigation bar or rounded card containing the whole app.
Use system fonts/SF Symbols, black/white, sparse lime accent and red capture.
The default recorder viewport contains the recipient, capture control and Send
when applicable. Optional New fields/history follow the primary controls, rather
than pushing them below the fold. Validate 49 mm and 45 mm default-text layouts;
large accessibility text scrolls naturally instead of shrinking to fit.

The waveform is a supporting real level meter, not decorative motion. A compact
five-bar meter may be used while genuine input is arriving; a static microphone
is an acceptable quieter alternative. A small elapsed `m:ss` is secondary,
never the hero. Active, paused and idle keep control anchors stable.

## 2. One navigation model

```mermaid
flowchart TD
  R[Recorder root] -->|Recipient row| T[Threads: single-level sheet]
  T -->|Pick existing or New; dismiss| R
  T -->|X or system dismissal; no change| R
  R -->|Project row, New only| P[Project: single-level sheet]
  R -->|Model row, New only| M[Model: single-level sheet]
  P -->|Pick or X; dismiss| R
  M -->|Pick or X; dismiss| R
  R -->|Recordings row| H[Recordings: push]
  H -->|Row| D[Delivery detail: push]
  D -->|Native Back| H
  H -->|Native Back| R
  R -->|Latest delivery| L[Delivery detail: direct push]
  L -->|Native Back| R
  R -->|Settings row| S[Settings: push]
  S -->|Native Back| R
```

Only one sheet can be active. **A sheet never contains another sheet or navigation
hierarchy.** Its visible system Close symbol (X) dismisses the picker without a
choice. Picking a row commits exactly one value and dismisses. Back is absent
from pickers; it pops the actual invoking path on pushed history/detail/settings.
Do not replace Close with a microphone or relabel it as a navigation shortcut.
Add an explicit dismiss control rather than assuming SwiftUI supplies it.

The visible recipient row opens Threads. No custom swipe-to-chooser shortcut:
native back/dismiss/Crown interactions retain their usual roles. Dismissal does
not start/resume capture, send, delete or change a value. Focus and scroll return
to the invoking recorder; incoming network events never navigate the interface.

## 3. Target selection and New

Threads is a small recent list (initially 30 visible, recently updated threads),
with project subtitle only when needed and a `New thread` row. Exact child IDs
are retained. A stale/offline cache is labeled with its source age when materially
stale; it is not silently replaced with a different target. The plugin validates
permission and availability. No model chips, agent counters or chat preview UI.

Choosing New commits a local New context and returns to the recorder. The last
valid project and `Project default` reduce setup; neither requires a server
mutation. Optional Project and Model rows live below primary controls, only in
New. Each opens a focused one-value picker with X. No wizard, `Use target`,
required title, extra Create button or staged multi-page transaction.

Model choices use the real project's catalog; a project default is genuine nil
intent, never a hidden global override. An unavailable catalog does not block
recording or selecting a known project default. A rejected override stays visible
as invalid until explicitly repaired; no silent fallback to a different model.

After the context's first Send, its project/model are frozen. Keep those rows
visible as read-only values without chevrons; they do not open pickers. A short
caption, `Choose New thread to change project or model`, explains the restriction.
Later recordings
in that pending context follow the same future thread. A different project/model
requires explicitly choosing New again. A receipt resolving that context cannot
change the target of an unrelated current compose draft.

Send with no target pauses capture and opens Threads. New without a valid project
opens Project instead. A choice returns to the paused recorder; another explicit
Send is required. No selection itself sends or creates anything remotely.

## 4. Capture, draft restoration and search

One live microphone and one active compose ID. Pause finalizes the current part;
resume continues that same draft. Successful durable enqueue ends it and returns
root ready for a new recording. The red circle means record/resume; red pause
bars mean pause. A separate up arrow means explicit Send. No play-plus-record
hybrid, manual Save or discard X beside the recording control.

A pending audio activation is represented until the actual input callback.
There is no success haptic or animated input before capture really starts.
Permission denial/unavailable input has a truthful recovery caption. No assumed
millisecond activation guarantee. A system interruption or cold-start recovery
returns a paused draft with `Paused · interrupted` and a known cause when available;
resuming always requires the real control. A normal pause is not an interruption.

The active paused draft restores by ID after returning. Other unsent drafts can
remain autosaved in history. A secondary **New recording** action parks the
paused draft and opens a new empty compose state without starting the microphone.
History **Continue** explicitly restores a selected unsent draft, parking the
currently paused one. Neither sends/deletes. Do not require Send or Delete just
to save a second thought while unpaired. No silent "newest draft wins" switching.

A target picker may remain open during live capture with a small recording
indicator. **Voice search cannot steal the recorder microphone.** During capture,
use cached recent choices; entering dictation/search requires an explicit
`Pause to search` action that first finalizes/pauses capture. Dismissal does not
resume. The same rule applies to any search field or local replay. Replay is
unavailable during capture; Record stops existing playback before starting input.

Actual wrist-down/not-frontmost capture capability is a hardware gate; legitimate
recording background execution must not be confused with background networking.
If the OS interrupts capture, retain finalized parts and explain the pause.
Cold start does not pretend to know whether the user force-quit or the OS killed
it; reconcile durable state and require an explicit resume.

## 5. Screens and their exits

| Surface | Main content/actions | Exit semantics |
|---|---|---|
| Root idle | target; prominent record circle; latest-delivery/Recordings; Settings below | No fake Back at root; app exit preserves drafts |
| Root activation pending | honest pending input; no live waveform | Activation failure returns a recoverable state; no fake success |
| Root recording | target; real input; secondary elapsed; pause; separate Send | Picker selection/dismissal does not stop/resume capture; explicit search pause is distinct |
| Root paused | target; subdued meter; record circle to resume; Send | Secondary New recording parks this draft; no delete disguised as Close |
| Root paused after interruption | same paused composition; `Paused · interrupted` caption | Resume/Send are explicit; saved parts are retained |
| Root New | same recorder; optional Project/Model rows below primary controls | Focused pickers return here; no server creation from navigation |
| Threads/Project/Model | one-value native list; X; voice-search recording guard | Pick commits one choice; X/system dismissal commits nothing |
| Recordings list | newest requests; unsent drafts; recipient, age, truthful delivery glyph/caption | Native Back restores root; row pushes detail |
| Delivery detail | exact recipient; durable receipt/failure; local replay; only safe repair/delete actions | Native Back pops its real invoker (history or root) |
| Settings | connection/pairing identity, storage used, Forget pairing | Pushed page with native Back; any picker remains single-level |

```text
IDLE                      RECORDING                 PAUSED
[Recipient           >]   [Recipient           >]   [Recipient           >]
                              Recording                 Paused
        ●                       ▁▂▅▃▂                    ─▂▅▃─
      Record*                  0:24                      0:24
                               [Ⅱ]                      [●]
                           [↑ Send*]                 [↑ Send*]
[Latest / Recordings  >]   [Delivery / Recordings >]  [New recording          ]
                                                    [Latest / Recordings   >]
[New fields if needed ]   [New fields if needed ]   [New fields if needed   ]
```

Asterisks are accessibility labels, not mandatory visible words. A visible label
is allowed where an icon is insufficiently clear. Primary Record/Pause/Resume and
Send have at least the project's 44-point target (Apple's default watchOS control
size; see [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility))
and a full hit region; no dead
center Spacers. Do not expand labels into half-screen status words. Actual default
screen screenshots, not these ASCII sketches, decide whether the composition fits.

## 6. Delivery presentation and safe actions

The main recorder remains available while the outbox works. A compact latest
receipt row uses `Saved`, `Queued`, `Sending`, `Received by BB` or `Needs attention`.
Acknowledged progress can be shown in detail; transport chunk counts are not
primary screen content. `Waiting for network/BB` needs an actual supporting
network/server result; an OS-deferred task without an explanation says `Queued`.
No invented percent, stage duration, ETA or timed progress animation.

Received means durable computer-side audio/job ownership, not completed ASR or
an agent result. Desktop ASR/submission facts are optional detail, never a new
watch progress modal. A failed ASR cannot revoke an upload receipt or show Send
again. Appropriate transfer Retry reuses the same recording ID and frozen audio.

Unsent drafts: explicit Delete in detail with confirmation. Enqueued/uncertain
intake: retain audio while querying receipt or confirming server abandon; zero
ACKs is not proof of zero acceptance. Retarget creates a replacement operation
only after a durable fence blocks the old one. Received local copies: explicit
`Delete local copy` says it does not retract anything on BB. No automatic local
cleanup in this release. Audio deletion never erases the plugin deduplication
fact needed to reject delayed duplicate commits.

Haptics occur on actual start/pause/resume and a newly confirmed foreground audio
receipt. No repeated receipt haptic on polling; a background receipt does not
promise a haptic or notification. No notifications in this release.

## 7. Motion, privacy and accessibility

Use short system-consistent content replacements (approximately 150–200ms),
keyed to actual revision. Keep controls stable and identical refreshes quiet.
No typewriter output, activity shimmer or whole-screen pulsing. Reduce Motion
removes nonessential custom movement; system transitions remain system-owned.

Always On stops the level animation and hides sensitive titles as needed; a static
capture glyph/caption remains truthful, with infrequent timer updates. Never hide
the fact that recording is live for the sake of privacy. Dynamic Type uses Crown
scrolling. VoiceOver names capture/pause/resume/send/close/back and the recipient;
focus is isolated to the sheet, and covered root controls are inaccessible.

## 8. Desktop plugin interface

A small plugin inbox is the operational surface, available within BB. It shows
original audio, exact thread/pending New context, durable receipt, processing
failure/transcript and verified core submission facts. It links to the actual
thread. Audio is stored by the plugin; no audio-native timeline API is invented
and no fake `audio received` prompt is sent just to draw a message.

Retry ASR reuses audio and completed groups. Ambiguous core dispatch requires
reconciliation; no blind Retry. Deletion/retention/revocation are explicit desktop
operations. Expert CLI/diagnostics may help implementation, but cannot replace
the promised inbox in the complete release. No transcript content is silently
modified to manufacture UI or reconciliation evidence.

## 9. Design validation

[Fable's review](specs/reviews/bb-watch-v2-fable-review.md) and the lead evaluate
all routes: target mid-capture, search/mic interaction, X without a choice, New
project/model, missing target Send, unsent draft parking, direct/detail Back,
replay during capture, interrupted capture, offline/unknown receipt and pairing.
Native simulator tours cover 49/45 mm default/large text, VoiceOver and Reduce
Motion; hardware tests separately prove capture and background audio delivery.
An installed binary alone is not navigation or reliability acceptance.

Primary guidance:
- [Apple HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Apple HIG: Modality](https://developer.apple.com/design/human-interface-guidelines/modality)
- [Apple HIG: Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
- [Apple: Making background requests](https://developer.apple.com/documentation/watchos-apps/making-background-requests)
- [Apple: WKURLSessionRefreshBackgroundTask](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask)
- [Apple: Life cycles](https://developer.apple.com/documentation/watchkit/life-cycles)

This is a product-specific design, not Apple certification. The architecture's
platform/auth/ingress proofs remain release gates; UX cannot promise immediate
background execution or exactly-once core mutation unsupported by BB.
