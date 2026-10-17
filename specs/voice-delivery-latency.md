# Voice delivery latency baseline

Investigated 2026-10-17. This is a local processing baseline, not a measured
watch-to-BB latency improvement. The transcription issue remains open.

## Current pipeline

The source of truth is `native/Sources/BBWatch/AppModel.swift` (`deliver`,
`transcribe`, `assemble`) and `native/Sources/BBWatch/BBClient.swift`
(`transcribe`).

After Send, recording is finalized locally. The delivery path groups the saved
CAF checkpoints into approximately 30 seconds of audio. For each group it:

1. Reads a persisted transcript cache if present.
2. Otherwise assembles a WAV on a detached utility task.
3. Uploads that WAV to `system/voice-transcription` and awaits its text.
4. Persists that group's text atomically, then removes only the temporary WAV.

Groups are processed sequentially, joined in recording order, and only then sent
as one message. Cache keys include the first and last chunk names and the count,
so extending a short group invalidates its previous result. Original chunks stay
on disk after failures. Connection identity is checked after assembly and ASR.
The send boundary persists an uncertain delivery state before the mutation; an
ambiguous send must not be automatically replayed to improve apparent latency.

The transport WAV retains the input processing format; there is no compression
or resampling in `assemble`. `BBClient` builds an in-memory multipart body from
the WAV. Its request duration includes upload and remote transcription; a single
client duration cannot separate those two stages.

## Measured local baseline

A temporary Swift executable combined the production `AudioWriter`,
`DurableStore` types and an unchanged copy of the production `assemble` body.
It generated mono float32 440 Hz synthetic audio in 250 ms buffers, finalized
15 real two-second CAF checkpoints, and assembled the same 30-second group five
times. Every output was opened with `AVAudioFile`; sample count and sample rate
were checked. This used the macOS host and local temporary storage, without a
microphone, live transcription, authentication or a message to BB.

| Sample rate | WAV bytes | Assembly durations, ms |
|---|---:|---|
| 16,000 Hz | 1,924,096 | 4.89, 3.02, 3.04, 2.84, 3.45 |
| 48,000 Hz | 5,764,096 | 7.09, 7.22, 8.76, 8.06, 6.64 |

The measurement covers CAF reads and WAV writes/finalization. It excludes
recording, generation, multipart construction, upload, ASR, message acceptance,
agent execution and screen refresh. It does not establish watch CPU/storage
performance, real input format, or representative tail latency. Sample-order
verification remains covered by the existing audio checkpoint integration check;
this small timing experiment only verified output length/rate.

These host measurements do not justify changing assembly or parallelizing ASR.
The observed WAV sizes make upload time worth measuring, but are not evidence
that upload is the dominant delay on the user's network.

## Next measured experiment

Use stage telemetry on a physical watch for user-initiated sends. Record audio
seconds, group count, WAV byte count, cache hits and monotonic elapsed durations
for assembly, the transcription request and message acceptance. Correlate each
request with the BB endpoint duration using an opaque request identifier, without
logging transcripts, audio, credentials, recipient identifiers or sensitive URLs.
Distinguish app suspension and connection errors from completed foreground sends.

Measure Wi-Fi and standalone LTE separately, including a short recording and a
multi-group recording. Report per-stage distributions and unsuccessful attempts,
not only a successful end-to-end example. Separate the time after BB acceptance
until the reply appears: that is synchronization latency, not ASR time.

If upload dominates, evaluate a server-supported audio encoding against the
baseline with sample integrity and recognition-quality checks. If ASR dominates,
first establish server concurrency/rate limits and per-group timing before
considering bounded parallel requests. Any implementation must preserve ordered
text, durable per-group cache, original audio, connection identity and the
non-replayable send boundary. No optimization or device latency claim was made
in this investigation.
