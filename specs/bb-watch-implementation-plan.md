# Voice terminal 3.0 — clean implementation plan

19 October 2026. Implementation authorized; platform and integration gates remain
open. This plan sequences work; it does not turn document review into runtime
proof. The product specification, design and transition contract own behavior.
The reviewed 3.0 packet plus the user's plugin-only routing clarification is the
input to the fresh build. Earlier architecture is an engineering reference for
the lead, not the builder's current protocol.

## Work split and cost control

| Owner | Work | First result |
|---|---|---|
| Sol 6.1 | Plugin, installed SDK/Jev boundary, intake protocol, persistence/order/fences, ASR and dispatch | Versioned contract and fixture proofs; exact integration blockers |
| Astra | Native SwiftUI watch app, capture/durability, file-backed background uploader, Action Button shortcut, accessibility and transitions | Clean build and bounded platform probes; no full UI before transport gate handoff |
| Lead | Shared contract acceptance, gates, integration, independent review, migration and release | Verified end-to-end evidence; no blind acceptance claim |

Use normal processing rather than an accelerated tier. Keep one owner per module,
one shared contract and narrow handoffs; do not have both models implement the
same layer. Use synthetic fixtures for failures; no live prompts for tests.
No monetary/time estimate is asserted before recording actual execution usage.
Do not add another model session for scaffolding or formatting. Cheap models may
later handle bounded fixtures/docs when that saves more work than the handoff.

## Preparation and preservation

Create a fresh orphan branch in an isolated worktree containing only current
product/design/transition material, this plan and neutral builder instructions.
Do not fork an old agent session. Do not copy source, old reviews, history notes,
recordings, credentials, signing or generated build directories. Shared Git
history is still reachable: this is design isolation, not a security boundary.
The canonical main checkout and installed app remain available for recovery.
The new build must not replace or uninstall the installed app before migration
and real-device acceptance. Migration is a separate lead-owned adapter; imports
never send and legacy acceptance never authorizes source cleanup.

## Required shared boundary

Watch sends immutable audio plus either unbound BB intent or an exact authorized
thread ID. Unbound routing gets authorized recent thread/message context only
inside the plugin/Jev integration; no notification context is collected by the
watch. Ordinary launch has mic off. Configured quick-start respects the current
context (initially BB), including a deliberate sticky manual target. It does not
infer a target from the last notification. Stop saves; REC appends; Enter enqueues.

Sol first verifies the installed SDK declarations, scoped plugin HTTP admission,
voice service, recent thread/message access, execution catalog, dispatch and
existing Jev service. An existing user's conceptual workflow is not proof of a
callable API. If no suitable Jev adapter exists, report the exact missing boundary
and implement a separately specified adapter; never fabricate one or scrape
provider session transcripts. Persist authorized bounded route decisions.

Publish a versioned JSON contract/schema under contracts/ with examples covering:

- Pairing, per-watch identity, revocation, key rotation/repair and wrong-device
  denial. No master/mobile-session fallback or credentials in logs.
- Immutable manifest, compressed parts, hashes/frame counts, interruption marks,
  frozen recipient intent and Send sequence/predecessors.
- Idempotent declare/part/seal/status and a complete-audio durable receipt.
  A duplicate request must not create a new job; accepted bytes must survive
  restart. Local source stays until verified receipt.
- Acknowledged abandon fences, definitive non-acceptance and unknown acceptance;
  no new ID or mutation replay for possibly accepted work. Ordering barriers,
  unresolved BB destinations and independent safe lanes have explicit examples.
- Thread activity/peek with freshness and authorization; no upload/ASR progress
  masquerading as thread activity.

Use the SDK's supported durable storage and narrow background-service APIs.
Confirm actual database/runtime semantics before choosing a storage design.
The wire names are not specified by this plan: both builders use the same
verified contract. Astra may propose changes but Sol owns contracts/ until freeze.

## Phase 0 — resolve blockers with the smallest probes

Sol owns BLK-1/TG3 (unbound intake/order) and BLK-2/TG4 (fence/nonacceptance);
G1a/G1b remote admission belongs to Sol with the lead owning installation/network
coordination. Loopback success or a mocked route does not close remote admission.
No production setting, tunnel, plugin install or account mutation without the
lead's concrete review; keys are never printed. No live agent send/spawn as proof.

Astra owns a minimal native proof harness for capture/checkpoint/append and
file-backed background-session reconciliation, plus the Action Button shortcut
entry. It can build for simulator/device without installation. Platform proofs
G3/G4/TG9/TG10/TG11 require actual hardware evidence coordinated by the lead.
No overlapping simulator/device ownership. No UI theater to substitute for
background execution; no workout session or silent audio to keep the app alive.

Compression is required by the intended release. Retain original PCM, seal AAC-LC
M4A as a candidate, decode on the computer to PCM16 for ASR. Validate bilingual
RU/EN, frame order, priming/padding, duration, names, numbers and negations at
part boundaries. Previous codec assumptions are not release evidence. No live
ASR calls until the lead supplies a bounded fixture/call plan; use offline decode
and fake ASR while developing. Rejected quality means revise format, not silently
ship an uncompressed substitute. Measure part sizing and budgets, do not invent
latency promises. W-wait and all storage/transient bounds are G6 decisions.

Gate reports under proofs/ identify code revision, fixture, actual environment,
measurements, pass/fail/not-run, and remaining dependency. Builds, simulation,
fixture transport and physical behavior must be reported separately. Blocked
hardware work can leave scripts ready; it never counts as a passed gate.

## Production implementation and integration

After the lead accepts the shared contract and BLK-1..3 evidence, Sol completes
the plugin and Astra completes the two watch surfaces. No full UI implementation
before the production-shaped G4 transport feasibility handoff; the native proof
harness is permitted before that handoff. Do not fabricate delivery endpoints or
an artificial automatic gate pass just to unlock the next phase.

Plugin owns source retention, segmented ASR/cache, Jev routing/model decision,
single automatic dispatch attempt and BB-side recovery after receipt. Watch owns
one mic/writer, atomic enqueue, background task ledger, stopped draft per context,
Issues recovery, no implicit sends, neutral unknown activity, privacy and Keychain.
Implement all transition guards and relevant acceptance scenarios, including
same-touch reuse, late callbacks, storage drain, account isolation and lost seal
response. Prefer focused behavioral checks over tests mirroring functions.

Each owner runs appropriate checks and exactly one independent advisor review
after substantial implementation; correct concerns and re-verify. The lead then
runs combined contract/build/state tour checks and an independent integration
review. No install, live-user delivery, publication or migration is delegated by
this plan. Release requires the product's open core gates and the actual device
acceptance; the lead owns those actions and source integration into main.
