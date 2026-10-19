# Voice terminal implementation workspace

Build from the current product, design, transition contract and implementation
plan only. Start with specs/bb-watch-implementation-plan.md. This is a fresh
implementation: do not inspect Git ancestors, another checkout, archived app
code, prior reviews or prior agent transcripts. Global skill instructions still
apply; installed SDK declarations and public Apple documentation are permitted.

Sol owns plugin/, contracts/ and proofs/plugin/. Astra owns native/ and
proofs/watch/. The lead owns product/design contracts and combined integration.
Do not commit, checkout, reset, stash, delete another owner's file or modify Git
index: the lead serializes commits in this shared worktree. Send boundary findings
to the parent. Do not spawn additional agents without parent coordination.

Phase 0 only until lead gate handoff: minimal native proof harness and plugin
contract/fixtures. Full UI requires transport feasibility; production integration
requires verified shared protocol and BLK-1..3 proof. Hardware/build/simulator
ownership is coordinated, not concurrent. No live agent prompts, ASR calls,
plugin installs, tunnel/config changes, signing-secret reads or device actions
without a concrete parent handoff. Never read credentials or user recordings.

No notification history on the watch. Unbound BB uses Jev's computer-side recent
thread/message context. Exact manual thread intent is binding. Keep audio and
identity/receipt/order ledgers; no replay after ambiguous mutation acceptance.
Run appropriate behavioral checks and one independent advisor pass after
substantial implementation. Treat mocks/simulator and physical evidence separately.
