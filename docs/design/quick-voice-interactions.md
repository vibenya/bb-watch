# Quick Voice — destination, history and Reply

19 October 2026. Current interaction supplement to
[Quick Voice](../../specs/bb-watch-quick-voice.md).
[Storyboard](quick-voice-interactions-v2.png) · [capture/recovery states](quick-voice-states-v2.png) · [generation brief](quick-voice-interactions-v2-prompt.md).
Concept artwork, not a native screenshot or measured geometry.

## Two different rows

The pill immediately below the lime recording control says **To: Auto**, **To:
Watch sync**, **To: New thread**, or **To: Pending thread**. It selects the recipient intent of the
current/next recording. A pin indicates an explicit target, never a saved chat
favorite. The row is a button with a full hit area and recipient VoiceOver label.

Below a separator, history rows represent **individual past recordings**. A row
has an audio/draft glyph, recipient when known, truthful receipt caption, age and
consistent trailing chevron. Receipt glyphs sit next to the caption, never replace
the chevron. Its tap never selects that recipient for a new recording.
Do not make a thread title within the row a second competing hit target.

## A — tap the destination (storyboard 01–03)

1. Tap To: Auto → one full-screen Destination sheet, visible X, no Back or duplicate
   recipient header. Existing choices, Auto and New thread are single selections.
2. Pick Watch sync → dismiss, show To: Watch sync with pin. Same compose audio,
   history and root scroll state. Recording does not start merely from selection.
3. X or system dismissal → prior intent unchanged. No remote create, send or delete.

If capture was live, opening/choosing/dismissing keeps the same capture live.
The sheet includes a small truthful capture indicator; it is not drawn in the
idle storyboard. Dictation search first requires explicit Pause to search;
the old draft is checkpointed before dictation takes the microphone, and closing
search never resumes capture automatically. Cached choices work without search.

New thread returns directly with force-new intent as specified in Quick Voice.
It never immediately creates a server thread. Optional New-only In: Auto project and Model: Auto root rows open separate
single-level pickers, never nested sheets. The Quick Voice destination-lifetime
section defines the exact labels, project/model scoping and frozen metadata
after first enqueue; no mandatory form is implied.

## B — tap a history row (storyboard 04–05)

Open the one pushed Recording detail page. Native Back returns to the same root
position and compose context. Detail displays this recording's recipient/intent,
recorded duration, local playback availability and receipt. It is not the agent
conversation. No recipient chooser is duplicated at the top of detail.

Playback starts only on Play. Back stops local playback before returning to
capture controls. While the microphone is live, detail may be inspected, but
Play and all compose-replacing actions (Reply, Continue, Add recording) are
unavailable with a short Pause recording first explanation. The detail shows
a small truthful Recording indicator while capture continues.
Inspection does not pause capture. The user returns with Back to pause explicitly.

Delete local copy is available for received recordings with explicit confirmation
and Does not retract. It removes local audio, not BB's message or receipt. A
queued/uncertain recording does not acquire that action just because zero bytes
are acknowledged. Inherited reliability rules are explicit for this variant: retain audio while
receipt is unknown; zero acknowledged bytes is not proof of non-acceptance;
abandon remote work only after server confirmation; retarget only after a durable
server fence prevents the old dispatch; never automatically clean up uncertain
audio or replay an ambiguously accepted BB mutation. This inherits architecture
§6 reliability, not its superseded mandatory-recipient UX.

Saved locally details offer Play, Continue and confirmed Delete draft. Continue
stops playback, parks a different paused compose, restores this exact recording
as paused on root and does not send or resume. Root exposes Resume and Finish &
send. Empty contexts disappear without a history item. Queued/received records
cannot be restored as editable drafts by Continue. Continue on the already active
draft returns to that draft without parking a duplicate. Repeated Continue/Add
recording taps are one local transition. Deleting an active paused draft clears
its compose only after confirmation; live drafts cannot be deleted.

## C — tap Reply (storyboard 05–06)

Reply is available only when a real authorized thread ID is known. It prepares
an empty compose context, pins that exact ID and returns to the root with To:
Watch sync. Stop any detail playback before changing compose. Guard repeated taps
as one local transition. The mic remains off; tap Record to begin. It does not replay, resend
or append audio to the selected historical recording.

If a different unsent compose is paused, park it intact in history before
preparing Reply. Back alone never parks/replaces a draft. If a cached thread is
known but BB is offline, recording the pinned reply is allowed; availability is
validated later. A known archived/deleted/unavailable thread cannot be silently
replaced with another target.

For Auto received audio whose destination is still unresolved, show Auto /
Destination pending in detail. Reply remains unavailable until a real thread ID
is reported. Received by BB is still a valid audio receipt. A routing error gets
a separate Needs attention explanation, BB could not pick a thread / Resolve on BB.
In this version clarification happens in the computer plugin, not a watch modal.
No Send again, retarget-after-enqueue, or fake agent Done is offered.

An enqueued (Queued or Received) pending-New recording is different from unresolved Auto: its durable
local context ID already identifies the intended future thread. Its detail offers
Add recording instead of Reply, restoring that same authorized context to idle
root with To: Pending thread. It never fabricates a server ID or creates another
thread. Stop playback and park another paused compose as for Reply. Settings stay
frozen. Once resolved, ordinary Reply pins the real ID for one compose.

## D — quick action versus in-app capture

The configured quick-start action starts a new Auto recording, parking a paused
compose if necessary. In-app Record uses the visible selected destination; Reply
does not change the shortcut's Auto behavior. A repeated start while capture is
already live shows that capture and cannot start a second mic or finish/send it.

Finish & send seals the current compose and enqueues it once. Controls remain
guarded while sealing/enqueueing; repeated taps cannot enqueue the draft twice.
Only durable enqueue clears the active compose. Failure restores a paused,
recoverable draft. A manual/Reply pin resets to Auto only after durable enqueue; Auto stays Auto.
New stays selected as Pending thread until an explicit target change, with frozen
metadata and the same-context follow-up semantics in Quick Voice. No gesture,
picker dismissal, Back, interruption or silence
stands in for explicit Finish & send.

## Stable state under asynchronous changes

Receipt/routing updates affect only their recording row/detail. They do not
replace the current recipient, start capture, dismiss a sheet or scroll the root.
A stale response from another BB pairing is not merged into this instance.
An explicit pending-New context may adopt its resolved thread identity only
within that same context; unrelated compose state is unaffected.

## Walkthroughs for the approval pass

| ID | Action sequence | Required outcome |
|---|---|---|
| I01 | Idle → To → existing thread | Target changes; mic off; no send |
| I02 | Idle → To → X/system dismiss | Target/audio unchanged |
| I03 | Live capture → To → choose/X | Same capture continues; truthful indicator |
| I04 | Live capture → search | Explicit pause before dictation; no automatic resume |
| I05 | To → New thread | Local force-new context; no immediate spawn |
| I06 | Root history row → detail → Back | Same root scroll/draft/recipient restored |
| I07 | Detail → Play → Back | Only selected recording plays; playback stops on Back |
| I08 | Resolved detail → Reply → Record | New audio; exact thread; no capture on Reply itself |
| I09 | Paused unsent draft → another detail → Reply | Old draft parked intact; new pinned compose idle |
| I10 | Live capture → detail | Read-only inspection; Play/Reply blocked; Back does not pause |
| I11 | Auto audio received, target pending → detail | Receipt remains true; Reply unavailable |
| I12 | Offline known recipient → Reply | Pin exact cached ID; preserve audio; no fallback |
| I13 | Quick action after pinned paused compose | Park it; fresh Auto; no duplicate microphone |
| I14 | Repeated Finish tap / enqueue failure | One operation or recoverable paused draft; no false Queued |
| I15 | Receipt/route arrives during picker or another draft | Update original row only; focus/target stable |
| I16 | Delete received / unknown audio | Confirmation/non-retraction for received; uncertainty never treated as safe cancellation |

## Additional acceptance checks from the first Fable pass

| ID | Action sequence | Required outcome |
|---|---|---|
| I17 | Paused → New recording → parked detail → Continue | Exact draft restored paused; no capture/send; empty contexts never listed |
| I18 | Manual/Reply → Finish; New → Finish; select Auto → pending-New detail | Manual pin resets Auto; New shows Pending thread; Add recording reselects that same context |
| I19 | New → optional In/Model → first Finish | Separate X pickers, no nesting/wizard; frozen truthful metadata afterward |
| I20 | Auto routing ambiguous after audio receipt | Received fact retained, Needs attention with Resolve on BB; no watch resubmit |
| I21 | Consent pending/no audio; accidental Finish; quiet capture | No empty enqueue; Finish has no Undo; silence never sends or pauses; real-start haptic |

The old four-state concept and the initial tap storyboard are design history.
The v2 sheets govern prefix, glyph, history-chevron and state distinctions. Pixel
spacing is illustrative; native safe areas and accessibility are runtime gates.
