# Voice terminal 3.0 — transition and error review

**Historical consistency receipt:** pinned inputs below describe the initial
3.0 packet. Subsequent bounded Fable corrections are evaluated in the
[final Fable review](voice-terminal-v3-fable-final-review.md); its new hashes and
verdict govern those changes. This receipt is not approval of later edits.

19 October 2026. Documentation/design review by the dedicated transition/error
designer. No implementation, build, device, provider, ASR, Jev or runtime call
was made. Output: [transition/error contract](../bb-watch-transition-contract.md).

Inputs: [v7 design](../../docs/design/voice-terminal-v7.md) (historical), the
[v8 concept](../../docs/design/voice-terminal-v8.png) with the red REC correction,
the 3.0 [product specification](../bb-watch-product-spec.md) and
[design](../../design.md), and the [architecture](../bb-watch-architecture.md)
and [event contract](../watch-event-contract.md) for reliability invariants and
gates only. Not inspected: native source, recordings, session history.

The automated advisor pass timed out once and was not retried; it approved
nothing. ID references and scenario counts were checked mechanically.

## Final consistency review (third pass, 10:45)

**Verdict: consistent. The final product specification, design and transition
contract agree; no edit to the root-owned files is required.** This is a
documentation consistency result only. It is not user approval of content, not
implementation approval, and no runtime gate has passed. Implementation stays
blocked by BLK-1 to BLK-3; release stays blocked by every open core gate.

Scope: full read of the final product specification and design below, the
transition contract after the third-pass corrections, and the v8 concept. The
architecture remains a 2.0 baseline that the product specification itself says
must be updated before a rewrite; it was not re-reviewed here.

| Pinned file | SHA-256 |
|---|---|
| specs/bb-watch-product-spec.md | 89b9564cc30a3f8f92af4d857c5dc73bcea31117051ba8f9afcc61429b0610db |
| design.md | 465d2cd6de4d30cb38114165648a5bb968334dc8b30653de59a029138a73aea6 |
| specs/bb-watch-transition-contract.md | ae2430ff33fa6d5c0ada37b884327b2bd5e6fb1124cc44bc1a714a30021c1254 |
| docs/design/voice-terminal-v8.png | 578061fcc5d1be82ee8b8cb31310c5e06026e29255005a1181737ad5035ad083 |

Any later edit to a pinned file reopens this verdict for that file.

Contract counts: 40 transition rows (T-01–T-38 with T-04b, T-11b); 120
acceptance scenarios (CAP 13, SND 9, DIS 4, TAP 9, CTX 14, GLY 4, LNK 15,
OUT 18, SET 9, STO 5, LIF 6, INT 8, PRE 6); 55 are gated, 65 need no gate;
every product acceptance ID P01–P22 has at least one scenario. Issues catalogue
E1–E10 (E9a/E9b); blockers BLK-1–3; defaults DEF-01–19; gates: core G1b, G3,
G4, G6, TG2, TG3, TG4, TG10, TG11, TG13, TG-U; feature TG1, TG5, TG7, TG8, TG9,
TG12; deferred TG6.

Readback of earlier conflicts against the final text:

| ID | Earlier conflict | Final text | Status |
|---|---|---|---|
| C1 | Unpaired Enter has no pairing identity | Product spec §3: unpaired Enter only stages audio with BB intent; explicit Send confirmation binds to the displayed connection; bound work never rebound. Contract §9.3 matches | Resolved |
| C2 | Quick-start append may merge an old thought | Product spec §3 accepts it as deliberate, with visible context, waveform and real-capture haptic. Contract DEF-05, CAP-13 | Resolved |
| C3 | Whether incompleteness reaches BB | Product spec §7: marks and boundaries travel in the immutable manifest; Stop is not incomplete; append keeps gaps; wire fields need proof. Contract INV-18, INC-1/2, TG13, INT-07/08 | Resolved |
| C4 | Issue text vs banned copy | Product spec §7 allows rare issue/setup text inside the explicit recovery UI. Contract PRE-04 now scopes the ban to ordinary surfaces | Resolved |

Wording note, not a contradiction: the design diagram says "First usable
buffer"; the contract defines the first real input buffer as establishing
`live` and as usable audio with no minimum duration, so both read the same.

## Third-pass lead findings — dispositions

| ID | Finding | Disposition in the contract |
|---|---|---|
| R1 | Store-blocked disabled mic contradicted Retry and stranded the user | Center is a neutral `Retry` control that never captures and stays after the alert (§3, T-04, LIF-06) |
| R2 | A timed-out local commit could become editable and commit late | INV-17 and terms *write owner*, W-drain: T-25 drains and reads back (committed → `ready`; not committed → `stopped`); T-38 and A-STORE-REOPEN when ownership cannot be established; T-04/T-04b prevent overlapping restores; LIF-04/05 |
| R3 | Legacy acceptance treated as a receipt | Legacy-accepted audio kept, never resent, never reclaimed (RET-3, §7.3); E9b local deletion keeps the entry like E7; E9a sends only with a choice naming the connection; SET-08 |
| R4 | PRE-04 contradicted the approved catalogue | Ban scoped to ordinary recorder and sheet; catalogue text only in its overlays and rows |
| R5 | Incompleteness must reach BB | INV-18, INC-1/2; Stop and storage-reserve stop make no mark; wire fields TG13 (core); old Q1 closed |
| R6 | Quick-start append accepted | DEF-05 noted as accepted; CAP-13 |
| R7 | Background vs wrist-down; late callbacks | T-11 limited to actual background; INT-2 separates (a) frontmost wrist-down/Always On from (b) background; T-11b and *capture attempt* ignore callbacks of ended attempts; CAP-11/12 |
| R8 | Usable audio must not imply a wait | Terms redefined: attempt ID precedes audio; first real buffer → `live` and a draft; short recordings seal at once; SND-09 |

Second-pass dispositions (L1–L9) stand as recorded below.

## Second-pass lead findings — dispositions

| ID | Lead finding | Disposition |
|---|---|---|
| L1 | `Send again` created a new identity for possibly sealed audio | Removed; `Check again` on the same ID; INV-08 |
| L2 | Local deletion is not reconciliation | Seal-free, definitive non-acceptance and fence terms; §7.5 delete table; `Removing` until fence acknowledged |
| L3 | Indicator hidden during capture; `Not delivered` untrue | Indicator visible during capture; heading `Issues` |
| L4 | No post-receipt mirror | Removed; §7.4; TG6 deferred |
| L5 | Reclamation, adopted surface, legacy | RET-3, DEF-15/16; legacy refined in R3 |
| L6 | Permanent link suppression | Only same-activation redelivery deduplicated; reopen applies; deferred-link freshness |
| L7 | Zero-audio and finalizing failures; revoked permission on REC | T-17/T-18, T-25–T-27, T-20; partial-audio copy |
| L8 | Gates are proofs | Core/feature/deferred classes; safe behavior never replaces proof |
| L9 | Bounded transients, corruption, no reset, red exemption | INV-16, `store-blocked`, E10 `Damaged`, PRE-05 exemption |

## First-pass findings on v7

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| F1 | blocker (doc) | v7 showed a gray microphone in the stopped center slot | v8 red REC; v7 historical |
| F2 | blocker | Default `BB` context needs unbound routing intake | BLK-1 / TG3 |
| F3 | blocker | Older failures in other contexts had no place | Issues indicator and row (DEF-15) |
| F4 | major | Stuck items block later ones invisibly | ORD-2/3/6; TG4 / BLK-2 |
| F5 | major | No surface for received local copies | RET-3 |
| F6 | major | No pairing entry or unpaired behavior | Pairing row; E3; D-PAIR-SEND |
| F7 | major | Overlapping hit areas across states | TCH-2/3/4, TAP-01–09, TG-U |
| F8 | major | Links undefined in many states | §8 application table |
| F9 | medium | Thread glyph source unproven | TG2 |
| F10 | medium | Status mark could move the primary target | Fixed indicator position (TCH-6) |
| F11 | medium | Haptics during capture | DSC-2 deferral |
| F12 | medium | Interrupted vs stopped looked alike | Haptic/VO, A-SAVE-PARTIAL, incompleteness marks |
| F13 | minor | No exception copy | Closed catalogue (§12) |

## Main failure cases

1. Computer asleep or offline: items wait, waiting indicator, no false success,
   automatic resume (OUT-01/02).
2. Credential revoked or a different BB paired: work held or frozen, never sent
   to the wrong account; unpaired work binds only by explicit choice (OUT-04,
   SET-05/06/09).
3. Thread deleted after selection: draft kept, explicit `Send to BB` (CTX-11, OUT-05).
4. Older stuck item blocks later ones to the same recipient; visible from any
   context, even while recording (OUT-06/07/09/11).
5. Seal sent, receipt unknown: no new identity, same-ID `Check again`, local
   deletion keeps the issue (OUT-14/15).
6. Audio received, then ASR, routing or dispatch fails: BB owns recovery; the
   watch stays silent (OUT-12).
7. Interruption, storage limit, write failure, seal timeout or crash during
   capture: committed audio kept, honest partial copy, mark carried to BB, mic
   never restarts by itself (INT-01–08, STO-01–04).
8. Crash, timeout or hung writer during Enter: audio in exactly one place,
   never an editable draft that also commits (SND-03–05, LIF-04/05).
9. Corrupt item or unreadable store at launch: per-item quarantine, or input
   blocked with Retry; nothing reset (LIF-01/02/06).
10. Double taps, late callbacks and links across state changes: one effect, no
    lost audio, no send (TAP-01–09, CAP-11, LNK-02/08).

## Handoff

- Files written: `specs/bb-watch-transition-contract.md`,
  `specs/reviews/voice-terminal-opus-review.md`. Both are frozen as of this
  review; no other file was changed by this designer.
- No product decision is waiting on the user. Engineering questions Q2 (TG4)
  and Q3 (legacy storage, G6) stay inside their gates.
- Implementation blockers: BLK-1 routing intake, BLK-2 fences and definitive
  non-acceptance, BLK-3 remote admission. The architecture must absorb the
  3.0 changes before a rewrite, as the product specification states.
