# Native transport and codec probe — bounded milestone

Status: native background upload **failed before intake on this simulator**;
native AAC-LC fixture feasibility **passed on host and simulator**. No production
protocol, audio receipt, cleanup, full UI or physical gate is accepted by this report.
The isolated identity remains `app.getbb.voiceprobe.phase0`. Swift 6 language mode,
watchOS minimum 26.0, Xcode 27.1 (27A9275), Swift 6.4 compiler, SDK 27.0; runtime
watchOS 26.1 on an isolated Apple Watch Ultra 2 simulator. No physical device,
signing secrets, microphone, imported recordings, provider, ASR or agent call.

## Native background URLSession result

[Sanitized observation](milestone1-native-transport.json) records the real native
session, file-backed task and delegate lifecycle. A loopback sink accepted only
one fixed 31-byte synthetic body. The original body SHA-256 is
`1006151669c73d95db4b338a34ebe0f5423d23a926b9887ce7d36869d2d73aac`.

Observed sequence: stable session creation → `getAllTasks` returned zero → durable
body and request plan → native `uploadTask(with:fromFile:)` → task identity persisted
→ resume → completion delegate `NSURLErrorDomain -1` → durable error observation.
After controlled app termination and ordinary relaunch, the stable session was
recreated, `getAllTasks` returned zero, the same error record and exact body remained,
and no replacement request was created. Exact private identities/logs are retained
outside the repository. Public evidence removes IDs, process IDs, paths and payloads.

The simulator CFNetwork log reports `NSCocoaErrorDomain 4099/4097` connecting to
`com.apple.nsurlsessiond`, then “failed to create a background NSURLSessionUploadTask,
as remote session is unavailable.” **Zero requests reached the sink.** This is an
actual native API failure, not a successful upload, server receipt or mocked result.
HTTP 200, response-body delivery, background-finished callbacks and WatchKit refresh
callbacks were **not observed**. Termination after server intake could not run.
The trial stopped after this concrete failure; no foreground Task, alternate
network client, workout or silent audio was substituted.

The reproducible driver uses a stable explicit invocation ID, cancels only its own
session tasks, and terminates its own loopback sink/app. A repeated ID cannot create
another OS task. Missing/ambiguous task behavior and observation disk-failure
readback remain covered by the host ledger suite. The script now waits for a *new*
post-relaunch `getAllTasks` event rather than satisfying its wait with an older one;
the recorded trial already contains the actual second event. The network trial
was not repeated merely for that driver assertion correction.

## Native AAC-LC measurements

Same `CandidateCodec.swift` and `CodecFixtures.swift` executed on both platforms.
[Host details](milestone2-codec-host.json) and [simulator details](milestone2-codec-simulator.json)
separate original bytes/hash, encoded container bytes/hash and lossy decoded
PCM format/hash. Every original remained byte-identical. Exact source rate/channel
count and actual returned frame count matched per part; no cross-rate frame sum.

| Synthetic part | Source format/layout | Rate / channels | Source frames | Host / simulator zero-lag correlation |
| --- | --- | --- | --- | --- |
| Short mono | float32 interleaved | 48000 / 1 | 480 | .999306 / .998102 |
| Append left | float32 interleaved | 48000 / 1 | 6000 | .999501 / .998535 |
| Append right | float32 interleaved | 48000 / 1 | 6000 | .999165 / .997656 |
| Route stereo | int16 planar | 44100 / 2 | 11025 | .999542 / .997787 |
| Route stereo | float32 planar | 32000 / 2 | 8000 | .999673 / .998451 |
| Route stereo | int16 interleaved | 48000 / 2 | 12000 | .999647 / .999076 |

The 700 Hz marker at the left end and 1200 Hz marker at the right start remained
in chronological order in separately decoded parts. Best measured signal lag
within ±32 frames was zero in every case. The fixtures model append/format
boundaries; they do not exercise a real hardware route change or interruption.
No stopped-time silence is synthesized. Original source formats are never silently
resampled to 16 kHz. Tiny M4A files often exceeded PCM size (e.g. 1920 source bytes
became about 61.7 kB); this is no storage-saving or G6 result.

Host packet-table valid frames matched each part. Its measured priming was 2112
frames, packet size 1024; remainders were 480, 80, 80, 175, 128 and 224. These are
observations of this encoder/container, **not constants for a protocol**. AVAudioFile
returned the valid-frame timeline, with manual trimming **zero**. Watch SDK does
not expose the AudioToolbox module used to inspect packet tables: watch priming,
padding and packet-table provenance are **unknown**, not inferred from host.
There is no extra leading/trailing trim based on the host packet table.

Four actual failure cases passed on both platforms: unsupported three-channel
source (validation), encoder-rejected 12345 Hz rate (`write-AAC-buffer`,
`com.apple.coreaudio.avfaudio -66567`), nonfinite source PCM (source read), and
output directory blocked by a file (`NSCocoaErrorDomain 516`). Each retained exact
source and published no completed candidate measurement. Partial files are retained
unreferenced, never used as fallback or accepted audio. The encoder rejects the
rate during buffer write, not writer creation; the test records that observed stage.

An early decoder experiment read past `AVAudioFile.length` and received the native
EOF error. The decoder now bounds requests by the file's own reported decoded
length and counts frames actually returned, without forcing the original length.
Host and simulator encoded/decoded locally; cross-platform decoder interchange,
actual watch codec availability, energy, long-duration capacity and bilingual
speech intelligibility/ASR fidelity remain **NOT RUN**. Tones prove none of them.

## Proposed future codec and transaction boundaries

Read-only feedback to the lead; **no edits/adoption of Sol's wire**:

- Keep immutable original source format/layout/hash, ordered segment ID and source
  frame range. Keep encoded container hash/bytes separately. A decoded hash names
  that decoder's lossy output; it must never be compared as source equality.
- Add decoder implementation/version, actual returned PCM format/rate/channels
  and frame count; identify the playable `[startFrame, frameCount]` range in that
  *returned PCM domain*, with its source segment/range/rate relation. For these
  fixtures the range is `[0, actualDecodedFrames]`, with manual trim zero. Require
  an explicit mapping policy if encoder/decoder rates or timeline lengths differ.
- Optional container packet count, packet size, priming and remainder must carry
  API/container provenance and an explicit unknown state. Keep container encoded
  frame domain distinct from already-trimmed decoder output; subtracting priming
  again would double-trim these measurements. A receipt needs a reviewed playable
  policy and admitted endpoint; `fixture-bytes-v1` never releases original audio.
- v2 Python seed/chain and exact example request/manifest hashes independently
  match. Persist Keychain request/lookup reservation *before* token creation, then
  read back that same item before the completed pairing transaction and exact
  request file. Recovery never remints after uncertain redemption. This earlier
  journal phase is a native requirement, not proof from a DTO flag.
- Validate checkpoint scope/epoch/request/hash and equality of covered sequence
  against local immutable facts; atomically persist the pointer before compaction.
  Binding opt-in needs a local durable action/result journal to reject duplicate
  callbacks, not an automatic pairing-triggered flush.
- Enter must freeze LOCAL Send scope/epoch/intent/sequence/source identity atomically
  and free compose even beyond 64 completely offline sends. Checkpoint acquisition
  and approved candidate mapping happen later. Publish exact wire bytes/hash once,
  durably before task creation; after publication/possible send never regenerate or
  rekey. Unknown local publication must read back before creating another version.
  The online 130-send fixture is not evidence for the wholly offline case. This
  separation and an offline/crash fixture remain integration work; no native v2
  network or production codec wiring was added.

## Checks and reproducibility

| Check | Result |
| --- | --- |
| Existing host capture/durability/SIGKILL/ledger checks | PASS |
| Explicit same-ID invocation and contradictory-body guard | PASS |
| Native host codec: six positive + four failure cases, append marker | PASS |
| Same native codec suite on owned watch simulator | PASS |
| Unsigned generic watchOS and watchSimulator SDK builds | PASS; no compiler warnings/errors |
| Native background file upload/delegate | FAIL before intake: daemon unavailable; body retained |
| Ordinary native session recreation and no automatic new task | OBSERVED |
| In-flight server acceptance/relaunch and WatchKit completion | NOT RUN / NOT OBSERVED |
| G3 / G4 / TG9 / TG10 / TG11 physical gates | NOT RUN |
| Production wire/receipt/codec admission; RU/EN speech | NOT RUN |

Commands from repository root (no signing/hardware actions):

```sh
xcodegen generate --spec native/project.yml
swift run --package-path native probe-checks
swift run --package-path native codec-checks "$PRIVATE_PROOFS/codec-host"
xcodebuild -project native/VoiceProbe.xcodeproj -scheme VoiceProbe \
  -sdk watchos -destination 'generic/platform=watchOS' \
  -derivedDataPath native/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project native/VoiceProbe.xcodeproj -scheme VoiceProbe \
  -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath native/DerivedDataSimulator CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Only with a lead-authorized exclusive simulator window and the isolated app already
installed on the owned simulator:

```sh
python3 native/scripts/simulator_transport.py \
  --simulator-id-file "$OWNED_SIM_ID_FILE" --artifacts "$PRIVATE_PROOFS/transport"
python3 native/scripts/simulator_codec.py \
  --simulator-id-file "$OWNED_SIM_ID_FILE" --artifacts "$PRIVATE_PROOFS/codec-simulator"
```

Private identity/process logs are not public artifacts. Sanitized check logs are
`milestone2-{host,codec,simulator}-checks.txt` and `milestone2-builds.txt`.
`milestone1-2-source-sha256.txt` records exact source inputs. Earlier Phase 0
proofs remain historical and unchanged. The next slice is a reviewed local-Send/
wire-publication crash fixture and codec timeline contract; actual transport
needs an exclusive hardware/admitted-fixture handoff. Full product UI remains gated.


Independent advisor review: exactly one pass after implementation and checks;
no actionable issue found. It confirmed the earlier observation-persistence
concern remains addressed. The owned app/sink were terminated and the owned
simulator shut down; exclusive window released. Unrelated simulators/apps/data
were untouched. No Git index, commit, branch or task closure action was taken.

Read-only v2 review inputs (SHA-256; this is not protocol acceptance):

```text
369740b5a26e07cef8a7ebf80fff8c186072977d10d84c2840a5c0d70c563e27  contracts/voice-terminal-v2.md
6373fb3925fe4babdc6951aa4569552229b01e4b03c910d592eeb1d2cc0f16bf  contracts/voice-terminal-v2.schema.json
9da6ef751baa58d935bab8e322c874b21d04d497d4468b1a87f2116e070beb7d  contracts/voice-terminal-v2.examples.json
```
