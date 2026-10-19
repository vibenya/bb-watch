# BB Watch — transition and error contract

19 October 2026 · **Design contract for the 3.0 voice terminal. Documentation
only: not implemented, not device-verified, no runtime gate is passed by this text.**

The [product specification](bb-watch-product-spec.md) owns scope and observable
outcomes, the [design](../design.md) owns visual hierarchy, and this file owns
event priority, transient controls, failures and recovery. Reliability mechanics
are inherited from the [architecture](bb-watch-architecture.md) (§3 watch
lifecycle, §4 intake, §5 dispatch); this file never relaxes them. Scenario IDs
in §13 supplement product acceptance P01–P22.

## 0. Authority

- Two product surfaces: the **recorder** and the **Threads sheet** (with inline
  current-thread peek). Native alerts, confirmation dialogs, the system permission
  prompt and the pairing form are overlays for setup and exceptions only.
- Current concept: [voice terminal v8](../docs/design/voice-terminal-v8.png).
  The stopped center control is a **red button with a white filled-circle REC
  glyph**. [v7](../docs/design/voice-terminal-v7.md) is historical; its panel 03
  microphone is superseded. Concepts are not geometry, HIG or runtime evidence.
- Error handling must not reintroduce removed UI: recording history, delivery
  detail, playback, Reply/New/project/model screens, visible timer, Send label,
  halo, a `Recording` title, or permanent status prose (`Received by BB`,
  `Resolve on BB`, `Paused · interrupted`).
- The watch's handoff ends at a verified durable receipt. ASR, routing and
  dispatch failures after receipt are recovered and notified in full BB; the
  first release mirrors none of them on the watch (§7.4).

## 1. Terms

| Term | Definition |
|---|---|
| Connection | One pairing with one BB instance/account and its per-watch credential. At most one is active; a previous connection's work is *frozen*. |
| Context | Where the next Enter goes: `BB` (unbound; the plugin routes from speech) or one exact authorized thread ID. One *current* context per connection. |
| Capture attempt | One Record/REC (or quick-start) acceptance. It has an ID before any audio exists, owns the input until it ends, and ends on `live`→stop, failure, cancel or context leave. Callbacks of an ended attempt are ignored and their input released. |
| Capture | The live microphone input of the current attempt. At most one on the device. |
| Draft | Unsent, editable audio of one context, created by the first real input buffer. At most one per context. |
| Usable audio | At least one real input frame that is durably committed or that Stop/Enter seals at once. No minimum duration, full chunk or checkpoint interval is required: a one-second recording seals immediately and can be sent. |
| Write owner | The single local writer of a draft's seal or an item's enqueue commit. A draft is editable only when no write owner for it can still commit. |
| Incompleteness mark | An immutable note at a segment boundary that audio may be missing there (interruption, input stall, write failure, seal timeout, crash tail). A user Stop never creates one. |
| Outbox item | Audio frozen by Enter with connection, context (routing intent) and Send sequence. Immutable identity. |
| Receipt | The plugin's durable statement that it holds the complete validated audio and one recoverable job (architecture §3.3). Not ASR, routing, thread delivery or agent completion. |
| Seal-free | The item's persisted state shows no seal request was ever created, a cancel is persisted, and OS-task reconciliation found no seal in flight. Only then can the watch guarantee it will not be sent. |
| Definitive non-acceptance | A specific BB answer that an identity was rejected without a job and is durably fenced against a later seal (TG4). Generic HTTP errors, 404s and timeouts are not. |
| Fence | BB's durable record that an identity is abandoned. It counts only once BB acknowledges it; a queued fence proves nothing. |
| Known-unavailable | BB has reported (list, link check or intake rejection) that a thread is deleted or not authorized for this connection. Unknown or stale is not known-unavailable. |
| Issue | An outbox item or retained artefact the user may need to know about or act on (§7.3). |
| W-restore, W-start, W-seal, W-finalize, W-drain, W-stall | Bounds for transient states, draining a write owner, and input stall; values come from gate G6. |

## 2. Invariants

| ID | Rule |
|---|---|
| INV-01 | One capture owner. A second start request reveals the existing capture; it never starts another. |
| INV-02 | The microphone starts only from Record/REC, the system-permission continuation of that same tap (DEF-07), or a configured quick-start (T-30). Never from launch, relaunch, link, context switch, pairing, interruption end or a late callback. |
| INV-03 | Only Enter sends. Selection, Close, links, pairing, quick-start, silence, interruption, backgrounding and exit never send. |
| INV-04 | Atomic enqueue: at every instant, including a crash or timeout during Enter, the usable audio is in exactly one place: the context's draft **or** one outbox item. |
| INV-05 | Only a committed enqueue (or a confirmed discard) frees compose. Returning to `ready` claims enqueue only, never receipt or delivery. |
| INV-06 | No audio is deleted before receipt except by an explicit user Discard/Delete. Failures, corruption and timeouts never delete audio and never reset the store; audio is never deleted to clear an indicator. Local deletion never clears ordering or unconfirmed state. |
| INV-07 | A draft or outbox item never changes connection or context silently. Retarget is an explicit user action on a draft, or on an item with definitive non-acceptance. |
| INV-08 | Intake is idempotent by recording ID and retried automatically under that ID. The watch never creates a new identity for audio whose seal may have occurred. Core dispatch is the plugin's single automatic attempt; the watch has no control that triggers, repeats or cancels it. |
| INV-09 | Send order is preserved per actual recipient, with the product spec's unbound-job barrier (§7.6). A barrier never blocks recording or enqueue. |
| INV-10 | The lower row's glyph shows only BB-reported thread state. Upload, ASR, routing and receipt never change it. Stale or unknown is neutral, never Done. |
| INV-11 | Late facts never move UI: receipts, routing results, refreshes and errors never change the current context, a draft, another item's target, focus or a live capture, and never raise an alert. |
| INV-12 | No duration cap. Only storage, interruption, write failure, input stall or user action stops capture. |
| INV-13 | No history. Received and normally in-flight items are never listed; only issues (§7.3), and only while they exist. |
| INV-14 | Logs exclude audio, transcripts, thread titles, credentials and link payloads. |
| INV-15 | Visible text is limited to thread titles, `BB`, the catalogue in §12 and the pairing form's field labels. |
| INV-16 | Every transient state has a bounded exit (§4). None waits on the network. |
| INV-17 | No draft becomes editable, and no restore retry starts, while an earlier write owner or recovery could still commit. The old owner is drained and the durable state read back first; if that cannot be done within W-drain, input is blocked (`store-blocked`), never a false `ready`. |
| INV-18 | Incompleteness marks are carried, unchanged, from the draft into the frozen manifest and through the plugin. Append never erases a mark or inserts silence. |

## 3. Recorder states

Waveform: real input amplitude entering at the leading edge, filling left to
right; when full, the oldest bars leave on the left. Silence draws the flat
baseline, never synthetic bars. Stopped shows the saved waveform static and
dim; append continues after it. Stopped time adds no silent audio.

The **issues indicator** (§7.3) has one fixed position in the input region,
outside the X / center / Enter slots and the lower row. It is visible in every
state except `restoring` and `store-blocked`, and inert during transient states.

| State | Entered when | Left | Center | Right | Lower row | Entry haptic · VO |
|---|---|---|---|---|---|---|
| `restoring` | Launch or relaunch | — | inert | — | inert | — |
| `store-blocked` | Local store or write ownership cannot be established (T-03, T-38) | — | neutral Retry glyph `Retry` (hint: saved recordings unavailable); never captures | — | inert | failure · alert A-STORE or A-STORE-REOPEN |
| `ready` | Current context has no draft | — | lime mic `Record` | — | active | — |
| `ready-blocked` | Mic permission denied or restricted | — | neutral slashed mic `Record` (hint: microphone off) | — | active | — |
| `starting(new)` | Record accepted | — | lime mic, pressed, inert; no waveform | — | inert | — |
| `starting(append)` | REC accepted | X inert | red REC pressed, inert | Enter inert | inert | — |
| `live` | First real input buffer | X `Discard recording` | square `Stop and save` | lime curved Enter `Send recording` | active | start · `Recording` |
| `stopping` | Stop, X, context leave, unexpected stop | inert | inert | inert | inert | — |
| `stopped` | Seal durable, usable audio present | X `Discard recording` | red REC `Continue recording` | lime curved Enter `Send recording` | active | stop · `Stopped` (user); failure · `Recording stopped` (unexpected) |
| `finalizing` | Enter accepted | inert | inert | Enter shows brief progress, inert | inert | — |

Transient states (`restoring` ≤ W-restore, `starting` ≤ W-start, `stopping` ≤
W-seal, `finalizing` ≤ W-finalize, each plus at most W-drain) ignore every
control, indicator and lower-row tap. If one lasts long it stays visibly inert,
with no waveform, timer or percentage, and leaves by the bounded exits below.
`store-blocked` is not a dead end: its center Retry stays available after the
alert is dismissed.

## 4. Transitions

| ID | From | Event [guard] | To | Effects |
|---|---|---|---|---|
| T-01 | restoring | local recovery complete | `stopped` if current context has a draft, else `ready`/`ready-blocked` | never `live`; outbox reconciliation runs afterwards in the background; deferred link/quick-start re-evaluated |
| T-02 | restoring | one draft or item fails validation | restoring continues | that artefact quarantined as E10; others restore normally |
| T-03 | restoring | store unreadable, ownership not established, or W-restore exceeded | store-blocked | A-STORE; nothing reset or deleted |
| T-04 | store-blocked | center Retry, or `Try again` in A-STORE [previous recovery drained within W-drain] | restoring | a new local recovery; never overlaps the previous one; no capture |
| T-04b | store-blocked | Retry [previous recovery or write owner not drained within W-drain] | store-blocked | A-STORE-REOPEN; next launch starts with no prior owner |
| T-05 | ready | Record [permission granted, space ≥ reserve] | starting(new) | — |
| T-06 | ready | Record [permission not yet asked] | system prompt | grant → starting(new) (DEF-07); deny → `ready-blocked`, no extra alert |
| T-07 | ready-blocked | Record | ready-blocked | A-MIC-OFF |
| T-08 | ready, stopped | Record/REC [space < reserve] | unchanged | A-STORAGE-START |
| T-09 | starting | first real input buffer | live | start haptic; new draft (new) or new segment of the same draft (append) |
| T-10 | starting | activation error, or no buffer within W-start | prior state, unchanged | failure haptic; A-MIC-UNAVAILABLE; no empty draft; attempt ended |
| T-11 | starting | app moves to the background (Crown press, app switch) | prior state, unchanged | no alert; attempt ended; capture never begins in the background. Wrist down or Always On while the app stays frontmost is not this event (G3, TG10) |
| T-11b | any | a callback (first buffer, activation, seal) of an ended attempt or drained owner arrives | unchanged | ignored; any input it opened is released; no haptic, waveform or draft |
| T-12 | live | Stop | stopping → stopped | stop haptic when sealed |
| T-13 | live | Enter [context not known-unavailable] | finalizing | capture stops, seals, enqueues in one step |
| T-14 | live | X | stopping → stopped + D-DISCARD | audio sealed before the dialog |
| T-15 | live | OS interruption; input stall ≥ W-stall; capture lost in the background (G3) | stopping → stopped | incompleteness mark at the boundary; failure haptic; no alert; no automatic restart |
| T-16 | live | free space reaches reserve | stopping → stopped | A-STORAGE-STOP; no mark (a deliberate safe stop, audio complete to here) |
| T-17 | live, stopping | write/checkpoint error, or seal exceeds W-seal [usable audio remains] | stopped with committed audio, after the seal writer is drained | incompleteness mark; A-SAVE-PARTIAL; unsealed tail quarantined; a pending switch, link or pairing is **not** applied |
| T-18 | live, stopping | same [no usable audio] | `ready` (no draft), after drain | A-REC-FAILED; raw data quarantined; pending switch/link/pairing not applied |
| T-19 | stopped | REC [permission, space] | starting(append) | — |
| T-20 | stopped | REC [permission denied or restricted] | stopped, unchanged | A-MIC-OFF; X and Enter stay usable |
| T-21 | stopped | Enter [context not known-unavailable] | finalizing | — |
| T-22 | live, stopped | Enter [context known-unavailable] | (live → stopping →) stopped + D-UNAVAILABLE | `Send to BB` → finalizing into this connection's BB context; `Cancel` → stopped |
| T-23 | stopped | X | stopped + D-DISCARD | `Discard` → `ready` (draft deleted); `Cancel`/dismiss → stopped |
| T-24 | finalizing | enqueue committed | ready (same context) | queued haptic; VO `Queued` |
| T-25 | finalizing | commit write fails or W-finalize passes after the last segment sealed | commit writer drained, durable state read back: committed → as T-24; not committed → stopped, draft complete | not committed: failure haptic, A-NOT-QUEUED. A late commit can never follow an editable draft |
| T-26 | finalizing | sealing the last segment fails or times out [usable audio remains] | stopped with committed audio, after drain | incompleteness mark; failure haptic; A-NOT-QUEUED-PARTIAL |
| T-27 | finalizing | same [no usable audio] | ready, after drain | A-REC-FAILED; raw data quarantined |
| T-28 | ready, ready-blocked, live, stopped | tap lower row | same + Threads sheet | live capture continues under the sheet |
| T-29 | ready, ready-blocked, live, stopped | tap issues indicator | same + Threads sheet, Issues expanded | live capture continues; no alert |
| T-30 | ready / stopped | quick-start [configured; guards of T-05–T-08, T-19, T-20] | starting(new) / starting(append) in the visible context | — |
| T-31 | starting, live, stopping, finalizing | quick-start | unchanged, recorder revealed | never a second capture, never Enter |
| T-32 | sheet | Close, system dismissal, pick current row | underlying state | nothing changes |
| T-33 | sheet | pick other context | (live → stopping →) destination's `stopped` or `ready` | origin keeps its draft; no capture, no send; T-17/T-18 abort the switch |
| T-34 | sheet | pairing row | (live → stopping →) pairing form | form Close changes nothing |
| T-35 | any | inbound link | §8 | — |
| T-36 | any | crash, termination, force quit | restoring at next launch | §10 |
| T-37 | restoring, store-blocked | link or quick-start arrives | deferred | re-evaluated after T-01; dropped if the store stays blocked |
| T-38 | stopping, finalizing | write owner not drained, or durable state not readable, within W-drain | store-blocked | A-STORE-REOPEN; no editable draft; the next restore lets the durable state decide: draft or item, never both |

Any action that changes or may change the current context or connection (pick,
link Open, pairing) stops and seals a live capture first; viewing (sheet, peek,
Issues, item dialogs) does not.

## 5. Touch and gestures

- TCH-1 Controls act on release inside, as system buttons. No hold-to-talk; a
  long press has no action.
- TCH-2 A touch that began before the current state was presented does nothing
  on release (held initiating touch).
- TCH-3 After a state change, every newly presented control ignores taps for a
  re-arm interval R (usability gate TG-U), including a large `ready` microphone
  that overlaps the area where Enter was. A deliberate later tap works.
- TCH-4 Observable double-tap outcomes: Record×2 → one capture, `live`;
  REC×2 → one append, `live`; Stop×2 → `stopped`, no append; Enter×2 → one
  item, `ready`, no capture; X×2 → one dialog.
- TCH-5 Near-simultaneous Stop/Enter/X: the first accepted event wins; the
  transient state rejects the rest. No audio loss, at most one item.
- TCH-6 Irreversible actions never move into a slot that was a safe action in
  the previous state. X stays left, Stop/REC center, Enter right; the issues
  indicator never moves and never overlaps them.
- TCH-7 Crown scrolls the sheet; no recorder function. System hand-gesture
  shortcuts are not adopted (DEF-12). No custom swipes; system sheet dismissal
  equals Close.

## 6. Contexts and the Threads sheet

### 6.1 Lower row

One row: activity glyph, actual title (or `BB`), chevron. Never transport state.

| Glyph | Source fact | Notes |
|---|---|---|
| routing | Context is `BB` | No activity; no peek chevron |
| idle | BB reports idle | Exact BB state mapping is part of TG2 |
| working | BB reports a running turn | Motion only when allowed (§11) |
| question | BB reports a pending question/interaction | No answer controls; voice reply semantics TG7 |
| done | BB reports the latest turn completed | Only from fresh BB data |
| failed | BB reports the latest turn failed | Not red (DEF-10); not a delivery failure |
| unknown | No fresh BB state (TG2 freshness window), unreachable, or no source | Neutral; never Done |
| unavailable | Known-unavailable | Title dimmed; context kept, not replaced |
| not paired | No active connection | `BB` with dimmed routing glyph; VO adds "not paired" |

The current context persists per connection across Enter, relaunch and
quick-start until the user picks another or applies a link. A route or receipt
never changes it. A known-unavailable current thread stays current until changed.

### 6.2 Sheet content (top to bottom)

1. Pairing row, only when needed: `Pair with BB` (unpaired) or `Pair again`
   (credential rejected).
2. `Issues` row with count, only while issues exist (§7.3).
3. Current context row: glyph, title, check; chevron for a thread.
4. Other threads: authorized recent threads in shared Chats order. A context that
   holds a draft is always listed, marked with a small mic glyph, even when not
   recent, hidden or unavailable.
5. `BB` routing row, when BB is not current.

Offline or unreachable: cached rows with `unknown` glyphs. No cache and no
connection: rows 1–3 and 5 plus `Can't load threads`. First load shows a native
progress indicator; the `BB` row stays usable.

### 6.3 Peek

The current thread's chevron expands inline: a bounded original BB excerpt and
its status glyph. Stale data carries `Not current`. Without an activity source
(TG2) the chevron is absent. No actions, no reader route. Hidden in Always On.

### 6.4 Switching with audio

- Pick while `live`: stop and seal into the origin, then switch (T-33). A seal
  failure keeps the origin current (T-17/T-18).
- Pick while `stopped`: the origin keeps its draft; switch.
- The destination shows its own draft as `stopped` (REC/Enter) or `ready`.
- Selecting the current context is a no-op; it never creates a second draft.
- Outbox items are untouched by any switch.

## 7. Outbox, delivery and issues

### 7.1 Item phases (watch view)

`queued` → `transferring` → `received` (the item leaves the watch's view).
Side phases: `waiting` (an attempt could not reach BB), `held` (needs a user
decision or a BB-side change), `unconfirmed` (a seal may have occurred and no
receipt can be obtained automatically under the active connection),
`not-paired` (Enter while unpaired), `frozen` (previous connection),
`removing` (deleted locally, fence not yet acknowledged), `damaged`
(quarantined at restore).

### 7.2 Retry classes

- Intake (declare, parts, seal, status) retries automatically under the same
  recording ID for as long as the item exists: bounded background attempts as
  the OS allows (architecture §3.4), plus reconciliation after every foreground
  and relaunch. Never a second job. Intake is not a BB mutation.
- Intake retry stops on definitive non-acceptance, credential rejection or a
  connection change. `Check again` (E7) re-runs status for the same ID now.
- Dispatch of transcript to a thread is the plugin's single automatic attempt.
  Ambiguous acceptance is reconciled on BB; the watch cannot repeat it.
- No watch action creates a new identity for audio whose seal may have occurred.

### 7.3 Discoverability without history

- DSC-1 **Issues indicator** in the input region, fixed position (§3), visible
  during capture too. *Attention* variant (exclamation shape, non-red, non-lime)
  if any issue needs a decision; *waiting* variant (small neutral dot) if only
  E1/E8 exist. Tapping it opens the Threads sheet with Issues expanded (T-29).
  It never changes Stop/REC/Enter/X, the lower row or the thread glyph. Hit area
  and discoverability are TG-U.
- DSC-2 **Haptic**: one notification haptic when an item newly needs attention
  while the app is frontmost; deferred until capture stops; once per item.
- DSC-3 **Issues row** in the Threads sheet. It expands inline, oldest first, one
  line per item: context label (thread title or `BB`) and reason. Tapping an item
  opens a native dialog with its actions.
- DSC-4 Issues from every context of the active connection appear regardless of
  the current context or recent list; a frozen connection is one entry.
- DSC-5 VoiceOver: indicator "Issues, <n>. Opens Threads."
- DSC-6 Nothing else: no list of received or in-flight items, no success state,
  no automatic alert.

| Kind | Trigger | Variant | Reason | Actions | Clears when |
|---|---|---|---|---|---|
| E1 waiting | Attempt could not reach BB (no network, computer asleep, unreachable) | waiting | `Waiting for BB` | Delete | received; delete completed (§7.5) |
| E2 pairing | Credential rejected | attention | `Pairing needed` | Pair again; Delete | same-identity repair resumes intake (TG5); delete completed |
| E3 not paired | Enter while unpaired (staged), or an unpaired draft after pairing | attention | `Not paired` | unpaired: Pair with BB; paired: Send to BB (D-E9 wording); Delete | bound via D-PAIR-SEND or Send to BB; deleted |
| E4 target | Definitive non-acceptance of the thread (TG4) | attention | `Thread unavailable` | Send to BB; Delete | replaced; deleted |
| E5 BB full | Intake reports BB storage quota | attention | `BB storage full` | Delete | accepted on a later automatic retry; delete completed |
| E6 rejected | Definitive non-acceptance of the audio after one automatic re-upload | attention | `Couldn't upload` | Try again; Delete | received; deleted |
| E7 unconfirmed | Seal may have occurred; receipt not obtainable automatically (e.g. same-BB re-pair without continuity) | attention | `Not confirmed` | Check again; Delete local copy | receipt seen; fence acknowledged; released on BB |
| E8 previous BB | Drafts/items of a frozen connection | waiting | `Previous BB` | Delete | that BB re-paired (resumes); deleted (§7.5) |
| E9a imported | Legacy recording the migration classified unsent (P22) | attention | `Imported` | Send to BB (D-E9, names the connection); Delete | sent as a new item; deleted |
| E9b imported unknown | Legacy recording with unknown delivery | attention | `Imported · not confirmed` | Delete local copy | released on BB only; deleting the copy keeps the entry, like E7 |
| E10 damaged | Restore cannot validate a draft or item (T-02) | attention | `Damaged` | Delete (dialog for its known state, else D-DELETE-COPY) | deleted; its ID reconciles as received |

Legacy items the old build saw accepted by BB create no issue and are not a
receipt: they are never resent and never reclaimed under RET-3 (Q3). Imported
audio is never sent or deleted without the user's action, and never becomes a
draft.
Damaged artefacts are never sent; if the item's ID is readable, status
reconciliation continues for it, without re-upload.

### 7.4 After receipt

A received item leaves the watch's view. ASR, routing, dispatch and acceptance
problems are BB's to show and notify (product spec P14); the watch shows no
mirror and offers no retry. A read-only mirror is a deferred extension (TG6),
not part of the first release. No local notifications for issues (DEF-13).

### 7.5 Delete semantics

| Item state | Dialog | Effect | Entry afterwards |
|---|---|---|---|
| Seal-free, never reached BB, no later item lists it | D-DELETE | audio deleted | clears |
| Seal-free, but some intake step reached BB or a later item lists it | D-DELETE | audio deleted; fence queued | `Removing` (no actions) until BB acknowledges the fence; later same-lane items keep waiting |
| Definitive non-acceptance (E4, E6) | D-DELETE | audio deleted; BB already fenced it | clears |
| Seal may have occurred (E7, or any item not provably seal-free) | D-DELETE-COPY | local audio deleted only | stays `Not confirmed` with `Check again` until receipt, fence or release on BB |
| E9a imported unsent | D-DELETE | audio deleted | clears |
| E9b imported unknown | D-DELETE-COPY | local audio deleted only | stays `Imported · not confirmed` until released on BB |
| E8 previous BB | D-PREV-DELETE, body built from the classes present | drafts and seal-free items deleted; local copies of possibly sealed items deleted | entry removed; their ledger stays and reconciles if that BB is re-paired |

`Delete` is offered only when one of these rows applies; the dialog shown is
the one for the item's actual state. `Send to BB` (E4, E9a) enqueues a new
item with the same audio in the active connection's BB context; the old item is
removed only after the new one is committed. E4 exists only with TG4; without
it, a target rejection offers Delete only.

### 7.6 Order and fences

- ORD-1 BB dispatches same-recipient items in Enter order, whatever the arrival
  order of their audio (architecture §5.1).
- ORD-2 An earlier item of the same connection that BB has not received delays
  later items that share its recipient, even when those were received. An
  earlier `BB` (unbound) item delays every later item it might address, as the
  product spec's barrier, until it is resolved or explicitly released on BB.
- ORD-3 Only an acknowledged fence, a definitive non-acceptance or a release on
  BB releases later items (TG4). Local deletion alone releases nothing.
- ORD-4 Known independent recipients never wait on each other.
- ORD-5 None of this blocks capture, Enter or context changes.
- ORD-6 When an issue is an ordering barrier, its dialog adds
  `Later recordings wait for this one.`

### 7.7 Retention

- RET-1 Drafts persist until Enter or Discard; no expiry.
- RET-2 Outbox items persist until receipt or a completed Delete (§7.5).
- RET-3 After a verified complete receipt, local audio becomes eligible for
  bounded automatic reclamation (values in G6). Unsent, unaccepted and
  unconfirmed audio never is. A durable receipt/order ledger remains. A legacy
  build's BB acceptance is not a receipt and never makes audio eligible.
- RET-4 Fences, tombstones and unconfirmed ledgers outlive local audio.
- RET-5 Unrecoverable raw data and damaged artefacts are quarantined, never
  sent, and deleted only with their draft or by an explicit Delete.

## 8. Inbound links (gate TG1)

Until TG1 passes, the app handles no inbound link and the release makes no link
claim. A link carries at least a BB identity and an exact thread ID. A title in a
link is a display hint only and never selects. Actual payload, invocation paths
and any invocation token are defined by TG1, not assumed here.

Validation, in order; the first failure decides and changes nothing:

| Step | Failure | Result |
|---|---|---|
| L1 parse | malformed or unknown | A-LINK-BAD |
| L2 pairing | unpaired | A-LINK-UNPAIRED |
| L2 pairing | different BB, including a previous pairing | A-LINK-OTHER |
| L3 redelivery | the same invocation delivered twice in one activation | applied once |
| L4 thread | BB reports deleted or not authorized | A-LINK-UNAVAILABLE |
| L4 thread | unreachable and thread not in this connection's cache | A-LINK-OFFLINE |
| L4 thread | in cache or confirmed by BB | accepted (cached title, glyph `unknown` until fresh) |

No permanent link blacklist: a later user reopen of the same notification is a
new invocation and applies again. A link to the current context is a no-op.

Application of an accepted link:

| Recorder state | Behavior |
|---|---|
| ready, ready-blocked, stopped | Switch context; origin keeps its draft; destination shows its draft or `ready` |
| live | D-LINK-LIVE while capture continues. `Open` → stop, seal, switch (T-17/T-18 abort). `Keep recording` → link dropped |
| starting, stopping, finalizing, restoring | Deferred, then re-evaluated against the settled state. A frozen operation is never modified |
| store-blocked | Deferred; dropped if the store stays blocked |
| sheet open | Sheet closes without selection, then apply |
| D-DISCARD open | Resolved as Cancel, then apply |
| other alert | Dismissed, then apply |
| system permission prompt | Deferred until answered |

Freshness: a deferred link is dropped silently if the user made an explicit
context choice after the link arrived (context revision changed). A link never
starts the microphone, sends, discards, retargets a draft or outbox item, or
falls back to a similar title or another thread.

## 9. Setup, permission, pairing, connectivity

### 9.1 First launch and permission

- First launch: `ready`, context `BB`, not paired. No forced onboarding.
  Recording, stop, append, Enter and discard all work unpaired.
- Microphone permission is requested on the first Record tap, never at launch
  (T-06). Denial at the prompt leads to `ready-blocked` without an extra alert.
- Permission removed later: Record and REC behave as denied (T-07, T-20).
  Existing drafts stay sendable and discardable; no audio is touched.
- Whether the app can open Settings directly is TG12; until proven, A-MIC-OFF
  is text only.

### 9.2 Pairing form

Opened from the sheet's pairing row; a setup overlay, not a product surface.
Fields follow architecture §4.2 as revised by gate G1b. Close changes nothing.

### 9.3 Pairing outcomes

- Unpaired Enter only stages audio with BB routing intent (E3); it cannot upload.
- First pairing with staged items: one dialog D-PAIR-SEND naming the displayed
  connection. `Send` binds those staged items to it and starts intake; `Not now`
  binds nothing and they stay E3 with `Pair with BB`/`Send to BB`. Entering a
  code alone never sends. Already bound work is never rebound by this dialog.
- An unpaired draft (not yet Entered) is not adopted by pairing: it appears as
  an E3 entry whose `Send to BB` (D-E9 wording, naming the connection) enqueues
  it, or `Delete` discards it.
- Credential rejected: E2 for affected items; the sheet shows `Pair again`;
  capture, drafts and the cached thread list keep working.
- Re-pair to the same BB identity: contexts, drafts and items continue. With
  continuity (TG5), items reconcile under their IDs. Without it, seal-free items
  resume under the new pairing; possibly sealed items become E7 and are
  resolved on BB.
- Pair a different BB: the previous connection freezes (E8). The current context
  becomes the new connection's `BB`. No draft, item or thread choice crosses.
  Re-pairing the previous BB later unfreezes its work.

### 9.4 Connectivity

- Offline or computer asleep: capture, stop, append, Enter, discard, cached peek
  and switching to cached threads work. Items become E1 after a failed attempt
  and resume without another Enter. No wake or ETA claim.
- Glyphs become `unknown` when data is not fresh.

## 10. Interruptions, storage, background, crash

- INT-1 OS interruption (call, Siri, alarm, another audio app) while `live`:
  T-15. No automatic resume when it ends. Device taxonomy: TG11.
- INT-2 Two different conditions, never conflated. (a) Wrist down or Always On
  while the app stays frontmost: not a backgrounding event; capture and
  `starting` continue (TG10). (b) Actual background (Crown press, app switch):
  `starting` ends (T-11); a `live` capture continues only if G3 proves it.
  Neither is a user Stop. If input actually stops, T-15 applies; the app never
  shows a moving waveform without input. Which platform events each produces is
  part of G3/TG10.
- INT-3 Input stall (no buffers for W-stall): T-15.
- INT-4 During `finalizing`, leaving the foreground does not split the commit:
  enqueue completes or not atomically (INV-04).
- INC-1 Incompleteness marks (INV-18) are recorded for T-15, T-17, T-26 and a
  crash tail (LIFE-1), with the cause class when known and the affected segment
  boundary. User Stop, storage-reserve stop (T-16) and Discard record none.
- INC-2 Marks are immutable, survive append, travel in the frozen manifest and
  reach full BB so it can explain missing audio. The watch shows no mark beyond
  the one-time alert. Exact wire fields are gate TG13.
- STO-1 Start blocked below the reserve (T-08). Reaching it while live: T-16,
  all committed audio kept. Write failure or seal timeout: T-17/T-18; during
  Enter: T-25–T-27.
- STO-2 No count limit on drafts or items; only storage limits capture.
- STO-3 BB quota is E5, not a watch storage error.
- LIFE-1 `restoring` is local only and bounded by W-restore. It recovers each
  context's draft from sealed parts and the aligned committed prefix, presents
  `stopped`, and never starts the microphone. Recovered audio is never sent
  automatically. A draft that was `live` at exit gets an incompleteness mark and
  shows A-SAVE-PARTIAL once, when first presented. A capture with no usable
  audio leaves no draft; its raw data is quarantined. An Enter interrupted by the
  crash is decided by the durable state: draft or item, never both (INV-04).
- LIFE-2 A single unreadable draft or item is quarantined as E10 (T-02); the
  rest of the app works. An unreadable store, unestablished ownership or a
  restore past W-restore yields `store-blocked` with Retry (T-03, T-04). A retry
  never overlaps a previous recovery (T-04b). Nothing is reset or deleted.
- LIFE-3 After T-01 the recorder is usable at once; outbox reconciliation runs
  in the background and precedes any re-upload of an item.
- LIFE-4 The app does not claim to know why it cold-started.

## 11. Presentation

### 11.1 Haptics

| Event | Haptic |
|---|---|
| First real input buffer (T-09) | start |
| User Stop sealed (T-12) | stop |
| Enqueue committed (T-24) | queued: distinct from start, stop and failure; not "delivered" |
| Start failure, unexpected stop, enqueue failure, store blocked | failure |
| Item newly needs attention (DSC-2) | notification, never during capture |
| Receipt, routing, refresh, context switch, sheet, peek | none |

### 11.2 Motion

- Short opacity/content transitions between control sets; positions are stable.
- The waveform is data, not decoration: no pulse, glow, halo or idle motion.
- Reduce Motion: no rotation, sliding or interpolated scrolling; the waveform
  updates in place; the working glyph is static.

### 11.3 Always On (TG10)

The layout and control identity stay the same, so `live` (square) is
distinguishable from `stopped` (REC). No animation; the waveform freezes or
updates only at the system's reduced cadence and never implies input that is
not arriving. Peek excerpts and issue text are hidden; titles stay.

### 11.4 Accessibility

- VoiceOver names: `Record`, `Stop and save`, `Continue recording`,
  `Send recording`, `Discard recording`, `Retry` (store-blocked); lower row: "<title or BB>, <glyph
  state>, Threads"; indicator per DSC-5. Announcements: `Recording`, `Stopped`,
  `Recording stopped`, `Queued`.
- Red is not the only state signal: REC differs from the lime mic by glyph.
- Largest Dynamic Type: titles truncate on one line in the lower row; the sheet
  scrolls with the Crown; the three controls stay reachable without scrolling.

## 12. Copy catalogue

Any other visible text is a defect (INV-15). Dialog buttons follow system order;
destructive buttons use the system destructive style.

| ID | Title | Body | Buttons |
|---|---|---|---|
| A-MIC-OFF | Microphone off | Allow access in Settings. | OK |
| A-MIC-UNAVAILABLE | Microphone unavailable | — | OK |
| A-STORAGE-START | Watch storage full | — | OK |
| A-STORAGE-STOP | Watch storage full | Recording stopped and saved. | OK |
| A-SAVE-PARTIAL | Recording stopped | Some audio may be missing. | OK |
| A-REC-FAILED | Recording failed | — | OK |
| A-NOT-QUEUED | Not sent | Recording kept. | OK |
| A-NOT-QUEUED-PARTIAL | Not sent | Recording kept. Some audio may be missing. | OK |
| A-STORE | Can't open saved recordings | Recording is paused until they open. | Try again · OK |
| A-STORE-REOPEN | Can't open saved recordings | Reopen BB Watch. | OK |
| A-LINK-BAD | Can't open link | — | OK |
| A-LINK-UNPAIRED | Pair with BB first | — | OK |
| A-LINK-OTHER | This link is for another BB | — | OK |
| A-LINK-UNAVAILABLE | Thread unavailable | — | OK |
| A-LINK-OFFLINE | Can't open this thread offline | — | OK |
| D-DISCARD | Discard recording? | — | Discard · Cancel |
| D-UNAVAILABLE | Thread unavailable | Send to BB instead? | Send to BB · Cancel |
| D-LINK-LIVE | Open <title>? | This recording stays saved here. | Open · Keep recording |
| D-PAIR-SEND | Send <n> saved recordings to <BB label>? | — | Send · Not now |
| D-DELETE | Delete recording? | It won't be sent. | Delete · Cancel |
| D-DELETE-COPY | Delete local copy? | If BB didn't get it, it's lost. If BB did, it may still be sent. | Delete · Cancel |
| D-PREV-DELETE | Delete recordings from previous BB? | Unsent ones are lost. / Some may already be on that BB. (lines per class present) | Delete · Cancel |
| D-E4 | Thread unavailable | — | Send to BB · Delete · Cancel |
| D-E6 | Couldn't upload | — | Try again · Delete · Cancel |
| D-E7 | Not confirmed | BB may already have it. | Check again · Delete local copy · Cancel |
| D-E9 | Send to <BB label>? | — | Send to BB · Delete · Cancel |

Sheet strings: `Threads`, `Pair with BB`, `Pair again`, `Issues`, `Removing`,
`Can't load threads`, `Not current`, and the reasons in §7.3. Barrier suffix:
`Later recordings wait for this one.`

## 13. Acceptance scenarios

Pass rule: a build passes when every scenario is observed as written. A gated
scenario needs recorded device/integration evidence; an open or failed core gate
(§14.3) blocks release and is not replaced by its safe behavior.

### Capture and send

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| CAP-01 | P01 | `ready`, permission granted, space OK | tap Record | `starting` with no waveform; on first real buffer `live`, start haptic once; X/square/Enter; no timer, title or Send text | — |
| CAP-02 | P02 | `starting` | no buffer within W-start | prior state unchanged, failure haptic, A-MIC-UNAVAILABLE, no draft | G6 |
| CAP-03 | P01 | `live` in silence | — | flat baseline advancing; no synthetic bars | — |
| CAP-04 | P03 | `live` | tap Stop | `stopped` after seal; static dim waveform; red REC with white filled circle; stop haptic | — |
| CAP-05 | P03 | `stopped` | REC, speak, Enter | one item containing saved then new audio in order; no silent gap for stopped time | — |
| CAP-06 | P02 | `stopped` | REC fails to start | `stopped` unchanged, alert, audio intact | — |
| CAP-07 | P16 | `live` for 60+ minutes, frontmost | — | no stop by duration; only storage, interruption or user | G6 |
| CAP-08 | P02 | `ready-blocked` | tap Record | A-MIC-OFF; no prompt, no capture | — |
| CAP-09 | P02 | first launch, permission not asked | tap Record | system prompt; grant → `starting` without another tap; deny → `ready-blocked`, no extra alert | — |
| CAP-10 | P02 | `stopped`, permission revoked since | tap REC | A-MIC-OFF; `stopped` unchanged; Enter and X still work | — |
| CAP-11 | P01 | `starting` ended by T-10 or T-11 | the old attempt's first buffer arrives late | ignored; input released; no waveform, haptic or draft | — |
| CAP-12 | P01 | `starting` | wrist lowered while the app stays frontmost | not treated as background; `live` on first buffer or T-10 at W-start | G3, TG10 |
| CAP-13 | P03 | `stopped` in A, quick-start configured | quick-start | append to A's draft; visible context A and its waveform; start haptic only on the first real buffer | TG9 |
| SND-01 | P04 | `live` | Enter | capture stops; one item with all audio; `ready` in the same context; queued haptic; no visible success | — |
| SND-02 | P04 | `stopped` | Enter | same as SND-01 | — |
| SND-03 | P05 | `finalizing` | crash at any instant | after relaunch exactly one of {draft `stopped`, outbox item} holds the usable audio | — |
| SND-04 | P05 | `finalizing` after the last segment sealed | outbox write fails (e.g. no space) or W-finalize passes before commit | `stopped`, draft complete, A-NOT-QUEUED, failure haptic | G6 |
| SND-05 | P05 | `live` | Enter; sealing the last segment fails | `stopped` with committed audio, A-NOT-QUEUED-PARTIAL; with no usable audio `ready` and A-REC-FAILED | — |
| SND-06 | P06 | `ready` after Enter, item not received | tap Record | new capture in the same context; earlier item unaffected | — |
| SND-07 | P09 | context thread with glyph idle | Enter; upload completes | glyph stays idle until BB reports the thread working | TG2 |
| SND-08 | P11 | item received | — | no haptic, no text; indicator clears if it was the last issue | — |
| SND-09 | P04 | `live` for about one second | Enter | one item with that audio at once; no wait for a checkpoint interval or full chunk | — |
| DIS-01 | P18 | `stopped` | X → Discard | draft deleted; `ready`; context unchanged | — |
| DIS-02 | P18 | `stopped` | X → Cancel or dismiss | `stopped` unchanged | — |
| DIS-03 | P18 | `live` | X | sealed first, then D-DISCARD; Cancel → `stopped`, not `live` | — |
| DIS-04 | P05 | outbox item exists, context `ready` | — | no recorder control can discard or edit the item | — |

### Taps and races

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| TAP-01 | P04 | `ready` | double tap Record | one capture, `live` | TG-U |
| TAP-02 | P04 | `stopped` | double tap REC | one append, `live`, not stopped | TG-U |
| TAP-03 | P04 | `live` | double tap Stop | `stopped`, no append | TG-U |
| TAP-04 | P04 | `live` or `stopped` | double tap Enter | one item, `ready`, no capture | TG-U |
| TAP-05 | P04 | finger down on Stop | interruption changes state before release | release does nothing | — |
| TAP-06 | P04 | `live` | Stop and Enter within R | exactly one effect; at most one item; no audio loss | TG-U |
| TAP-07 | P04 | `live` | Enter then X quickly | one item; no dialog | — |
| TAP-08 | P04 | `ready` | long press Record, release inside | starts on release only | — |
| TAP-09 | P07 | any transient state | tap lower row or issues indicator | ignored | — |

### Contexts and glyphs

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| CTX-01 | P08 | fresh install or new pairing | — | row shows `BB` with routing glyph; never a last-used thread | — |
| CTX-02 | P07 | `ready` in BB | pick thread T | sheet closes; row shows T's actual title; no capture, no send | — |
| CTX-03 | P08 | context T | Enter twice, relaunch | context still T | — |
| CTX-04 | P07 | `live` in A | pick B | A sealed and kept as `stopped` draft; B shows its draft or `ready`; mic off; A listed with mic glyph | — |
| CTX-05 | P07 | A holds a draft | return to A | `stopped` with A's draft; REC appends; Enter sends to A | — |
| CTX-06 | P07 | `live` in A, seal fails during switch | pick B | stays in A (`stopped` + A-SAVE-PARTIAL, or `ready` + A-REC-FAILED if nothing usable); switch not applied | — |
| CTX-07 | P07 | `stopped` in A | pick A | sheet closes; no second draft | — |
| CTX-08 | P07 | `live` | open sheet, Close | still `live`; nothing changed | — |
| CTX-09 | P08 | context BB | plugin routes an earlier item to thread X | context stays BB; row unchanged | — |
| CTX-10 | P13 | A holds a draft; A drops out of the recent list | open sheet | A listed with mic glyph | — |
| CTX-11 | P10 | current T known-unavailable, draft present | Enter | D-UNAVAILABLE; Send to BB → item in BB context; Cancel → draft kept | — |
| CTX-12 | P08 | archived or hidden T selected | Enter | sent to exact T; BB decides acceptance; never a substitute thread | TG8 |
| CTX-13 | P08 | child thread selected | Enter | exact child ID used; row shows child title | — |
| CTX-14 | P09 | current thread | expand peek | bounded excerpt + glyph; stale shows `Not current`; no actions; Close → recorder unchanged | TG2 |
| GLY-01 | P09 | activity data stale or source absent | — | `unknown` glyph; never Done | TG2 |
| GLY-02 | P09 | BB reports a pending question | Enter a voice reply | question glyph stays until BB changes it; no claim the question was answered | TG7 |
| GLY-03 | P09 | upload, ASR or routing in progress | — | glyph unchanged by them | — |
| GLY-04 | P21 | Reduce Motion on, thread working | — | static working glyph | — |

### Links

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| LNK-01 | P10 | `ready`, valid link to T | open link | context T; `ready` or T's draft; mic off; nothing sent | TG1 |
| LNK-02 | P10 | `live` in A | open link to T | D-LINK-LIVE while capturing; Keep recording → still `live` in A; Open → A sealed as draft, context T | TG1 |
| LNK-03 | P10 | `stopped` in A | open link to T | context T; A keeps its draft | TG1 |
| LNK-04 | P10 | `finalizing` | open link | applied after the item is committed; the item keeps its original context | TG1 |
| LNK-05 | P10 | link to the current thread | open | no change, no alert | TG1 |
| LNK-06 | P10 | one invocation delivered twice in one activation | — | applied once | TG1 |
| LNK-07 | P10 | link to T applied, user then picked U | reopen the same notification later | context T again | TG1 |
| LNK-08 | P10 | link deferred during `stopping` | user picks U before it settles | link dropped; context U | TG1 |
| LNK-09 | P10 | link for another BB | open | A-LINK-OTHER; context unchanged | TG1 |
| LNK-10 | P10 | unpaired | open link | A-LINK-UNPAIRED | TG1 |
| LNK-11 | P10 | thread deleted or unauthorized | open link | A-LINK-UNAVAILABLE; no title match | TG1 |
| LNK-12 | P10 | offline | link to uncached / cached thread | A-LINK-OFFLINE / context switches, glyph `unknown` | TG1 |
| LNK-13 | P10 | malformed link | open | A-LINK-BAD | TG1 |
| LNK-14 | P10 | app not running, a draft was live at last exit | open link | recovery first (`stopped` draft kept), then link applied; never `live` | TG1 |
| LNK-15 | P10 | sheet or D-DISCARD open | open link | sheet closed without selection / discard cancelled; then link applied | TG1 |

### Outbox and issues

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| OUT-01 | P11 | network off | Enter items in A, B and BB | all kept; after failed attempts waiting indicator; sheet `Issues 3`, each `Waiting for BB` | — |
| OUT-02 | P11 | OUT-01 | network returns | items deliver without another Enter; indicator and row disappear; no success list | G4 |
| OUT-03 | P12 | seal response lost | reconcile | same recording ID; one job; no duplicate | G4 |
| OUT-04 | P19 | credential rejected | — | E2 items, attention indicator, `Pair again`; capture unaffected | — |
| OUT-05 | P13 | definitive non-acceptance of target T | Send to BB | new item in BB context; old removed only after enqueue; old identity cannot become a job | TG4 |
| OUT-06 | P13 | E6 item in context A | user records and sends in B | B's items proceed; indicator visible in B, including while `live`; A's entry in Issues | — |
| OUT-07 | P13 | `live` in B with an issue in A | tap issues indicator | sheet with Issues expanded; capture continues; Close → still `live` | — |
| OUT-08 | P15 | items 1 then 2 to T; 2 uploads first | — | BB dispatches 1 before 2 | G4 |
| OUT-09 | P15 | item 1 to T held, item 2 to T received | delete item 1 (seal-free) | entry `Removing`; 2 waits until BB acknowledges the fence; dialog showed the barrier suffix | TG4 |
| OUT-10 | P15 | item to T held | send to known-independent U | U not delayed | — |
| OUT-11 | P15 | earlier BB-context item held on the watch | later exact-thread item received | later item waits until the earlier resolves or is released on BB | TG3, TG4 |
| OUT-12 | P14 | received item fails ASR, routing or dispatch, or acceptance is unknown | — | no watch issue, retry, re-upload or alert; recovery and notification in BB | — |
| OUT-13 | P18 | E1 item, seal-free, never reached BB | Delete | D-DELETE; audio deleted; entry clears; never uploaded later | — |
| OUT-14 | P18 | item whose seal may have occurred | Delete local copy | D-DELETE-COPY with both warnings; entry stays `Not confirmed` with Check again | — |
| OUT-15 | P12 | E7 item | Check again after BB reconciles | same ID resolves to received or fenced; entry clears; no new identity | TG5 |
| OUT-16 | P13 | item needs attention while `live` | — | indicator switches to attention; no haptic or alert during capture; one notification haptic after stop | — |
| OUT-17 | P11 | items pending | relaunch | recorder usable after local restore; statuses reconciled before any re-upload; same IDs; no Enter | G4 |
| OUT-18 | P18 | item received | relaunch | no re-upload (ledger); local audio reclaimed only per RET-3 | G6 |

### Setup, storage, interruption, lifecycle, presentation

| ID | P | Given | When | Then | Gate |
|---|---|---|---|---|---|
| SET-01 | P19 | first launch, unpaired | record, stop, append, Enter | all work; E3 item, attention indicator; row `BB` (VO "not paired") | — |
| SET-02 | P19 | unpaired | open sheet, `Pair with BB`, Close form | nothing changes | — |
| SET-03 | P19 | E3 items exist | pairing succeeds | D-PAIR-SEND; Send binds and uploads; Not now binds nothing | G1b |
| SET-04 | P19 | same BB re-paired | — | drafts and items continue; no duplicate job | TG5 |
| SET-05 | P19 | different BB paired | — | previous work frozen as `Previous BB`; context `BB` of new; no old audio reaches the new BB | — |
| SET-06 | P19 | E8 with drafts, seal-free and possibly sealed items | Delete | D-PREV-DELETE names both classes; entry removed; ledger kept | — |
| SET-07 | P19 | `live` | tap pairing row | capture sealed before the form opens | — |
| SET-08 | P22 | legacy recordings imported | open sheet | unsent ones `Imported` (Send to BB naming the connection, Delete); unknown ones `Imported · not confirmed` (Delete local copy, entry stays); legacy-accepted ones absent, kept, never resent or reclaimed; nothing sent, deleted or made a draft automatically | — |
| SET-09 | P19 | unpaired: one staged item and one stopped draft | pairing succeeds | D-PAIR-SEND for the staged item only; the draft appears as `Not paired` with Send to BB / Delete; nothing uploads without a choice | G1b |
| STO-01 | P18 | space below reserve | tap Record | A-STORAGE-START; no capture | G6 |
| STO-02 | P18 | `live` | space reaches reserve | `stopped`, committed audio kept, A-STORAGE-STOP | G6 |
| STO-03 | P18 | `live` with usable audio | write error or seal past W-seal | `stopped` with committed prefix, A-SAVE-PARTIAL; tail quarantined; never sent automatically | G6 |
| STO-04 | P18 | `live`, nothing committed yet | write error | `ready`, A-REC-FAILED, raw data quarantined, Enter not offered | — |
| STO-05 | P18 | BB quota | intake retry | E5; resumes automatically when BB accepts | — |
| LIF-01 | P05 | one item's manifest unreadable at launch | relaunch | that item `Damaged` in Issues; other drafts and items restore; recorder usable | — |
| LIF-02 | P05 | store unreadable or restore past W-restore | launch | `store-blocked`, A-STORE with Try again; no reset, no deletion, no fake `ready` | G6 |
| LIF-03 | P11 | offline | launch with pending items | recorder usable after local restore; no wait on network | — |
| LIF-04 | P05 | `finalizing` | commit write passes W-finalize | writer drained and state read back: item committed → `ready`; not committed → `stopped` with A-NOT-QUEUED; never an editable draft that later also commits | G6 |
| LIF-05 | P05 | `finalizing` or `stopping` | writer cannot be drained within W-drain | `store-blocked`, A-STORE-REOPEN, no editable draft; after relaunch exactly one of draft or item | G6 |
| LIF-06 | P05 | `store-blocked`, A-STORE dismissed with OK | tap center Retry | new restore starts only after the previous one ended; no capture; success → `ready`/`stopped` | — |
| INT-01 | P17 | `live` | phone call | `stopped`; prior audio kept; no resume after the call | TG11 |
| INT-02 | P17 | `live` | wrist down 5 min | `live` throughout with all audio sealed | G3 |
| INT-03 | P17 | `live` | Crown press, return | as INT-02 | G3 |
| INT-04 | P17 | `live` | input stalls | `stopped` after W-stall, failure haptic | G6 |
| INT-05 | P17 | `live` | force quit, relaunch | `stopped` with audio up to the last checkpoint plus recoverable tail; A-SAVE-PARTIAL once; mic off | — |
| INT-06 | P17 | `starting` | app backgrounded | no capture; prior state | — |
| INT-07 | P16 | `live`, interrupted by a call | REC, speak, Enter | one item; manifest carries one incompleteness mark at that boundary; no inserted silence | TG13 |
| INT-08 | P16 | `live` | user Stop, REC, Enter | one item; no incompleteness mark | TG13 |
| PRE-01 | P21 | Reduce Motion | all states | no rotation, pulse or sliding; states distinguishable | — |
| PRE-02 | P21 | Always On while `live` | — | square visible, no animation, no implied input; peek/issue text hidden | TG10 |
| PRE-03 | P21 | VoiceOver | every state | names per §11.4; stopped center is `Continue recording`, never Play or Microphone | — |
| PRE-04 | P20 | every recorder state and the Threads sheet outside its pairing and Issues rows | — | no timer, Send label, Recording title, `Received by BB`, `Resolve on BB`, halo, history or playback. §12 text appears only in its alerts, dialogs, pairing row and Issues row | — |
| PRE-05 | P21 | every state | — | red appears only on REC and on system destructive dialog buttons | — |
| PRE-06 | P20 | diagnostics enabled | full scenario run | logs contain no audio, transcript, title, credential or link payload | — |

## 14. Classification

### 14.1 Blockers (resolve before building the affected path)

| ID | Blocker | Affected |
|---|---|---|
| BLK-1 | Routing-intent intake for the `BB` context (TG3): manifest, receipt, unbound-barrier semantics | Enter in the default context |
| BLK-2 | Definitive non-acceptance, fences and BB-side release for never-received items (TG4) | §7.5, ORD-2/3, OUT-05/09/11 |
| BLK-3 | Remote admission of plugin intake (architecture G1b) | all delivery |

### 14.2 Chosen defaults (adopted)

| ID | Default |
|---|---|
| DEF-01 | X while live seals first, then asks |
| DEF-02 | Act on release; held and pre-transition touches ignored; re-arm interval R |
| DEF-03 | Late issues never raise an alert; indicator + one haptic + Issues row |
| DEF-04 | Pairing and Issues rows appear only when needed, above the current row |
| DEF-05 | Quick-start in `stopped` appends to that draft (product spec §3, accepted by the lead) |
| DEF-06 | Link during capture asks D-LINK-LIVE; capture continues meanwhile |
| DEF-07 | First permission grant continues the same tap into `starting` |
| DEF-08 | Enter on a known-unavailable thread offers `Send to BB`; context unchanged |
| DEF-09 | Unpaired Enter creates E3 items, bound only via D-PAIR-SEND |
| DEF-10 | Red reserved for REC (and system destructive buttons); failed glyph is neutral by shape |
| DEF-11 | Offline links open only cached threads |
| DEF-12 | System hand-gesture shortcut not adopted |
| DEF-13 | No local notifications for issues |
| DEF-14 | Frozen previous-connection work is one `Previous BB` entry |
| DEF-15 | Issues surface: input-region indicator plus conditional Issues row (lead-adopted) |
| DEF-16 | Bounded reclamation only after verified receipt (RET-3; product spec §6) |
| DEF-17 | No post-receipt mirror in the first release (§7.4) |
| DEF-18 | Damaged artefacts are quarantined per item; an unreadable store blocks input with a center Retry, never resets |
| DEF-19 | An unpaired draft is never adopted by pairing; it becomes an explicit `Not paired` entry |

### 14.3 Runtime gates

Core gates block release when open or failed. Their safe behavior is required
anyway and never replaces the proof. Feature gates withhold only the named
feature and its claims.

| Gate | Class | Proof | Required safe behavior |
|---|---|---|---|
| G1b | core | Remote admission of intake (architecture) | — |
| G3 | core | Capture through wrist down, Crown press, other app (architecture) | T-15 if input actually stops; no standalone/wrist-down claim before proof |
| G4 | core | Background declare/parts/seal/receipt chain (architecture) | No delivery-timing claim |
| G6 | core | Values: storage reserve, W-restore, W-start, W-seal, W-finalize, W-drain, W-stall, part caps, reclamation bounds | — |
| TG13 | core | Manifest/wire fields for incompleteness marks and their boundaries, carried to BB | No claim that BB explains missing audio |
| TG2 | core | Thread activity/excerpt source on the watch and its freshness window | `unknown` glyph when not fresh |
| TG3 | core | Unbound routing intake and ordering contract | BLK-1 |
| TG4 | core | Definitive non-acceptance, fence acknowledgement, BB-side release | BLK-2; without it E4 offers Delete only |
| TG10 | core | Always On behavior of a frontmost recorder during capture | Static truthful frame |
| TG11 | core | Device interruption taxonomy and resulting committed audio | T-15 for any lost input |
| TG-U | core | Re-arm interval R, indicator discoverability and hit areas on 49 mm and the smaller size | — |
| TG1 | feature | BB notification → standalone watch app: payload, invocation paths, cold/warm launch, device destination, auth, redelivery | No link handling or claim |
| TG5 | feature | Same-BB re-pair keeps device identity or allows status lookup | §9.3 path without continuity |
| TG7 | feature | What BB does with a message to a thread with a pending question | No claim it answers the question |
| TG8 | feature | BB acceptance for archived/hidden exact targets | BB intake decides |
| TG9 | feature | Configurable quick-start entry on Ultra 2 | No quick-start claim |
| TG12 | feature | Whether the app can open Settings for permission | Text-only A-MIC-OFF |
| TG6 | deferred | Post-receipt processing status readable by the watch | Not in the first release |

## 15. Open questions

No product decision in this contract is waiting on the user. Resolved: the
manifest carries incompleteness marks (INC-1/2, product spec §7; wire fields
TG13). Engineering questions that stay inside gates:

- Q2 What exact BB answer constitutes definitive non-acceptance, and how does BB
  release a barrier for an item it never received, including E9b imports (TG4)?
- Q3 Legacy-accepted audio is kept and never auto-reclaimed (product spec §7).
  The first release gives it no watch removal route; whether a later explicit
  cleanup path is needed is a storage question for G6, not a watch surface.
