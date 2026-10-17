# Voice delivery latency and transcription transport

2026-10-17. Transcription is isolated in `TranscriptionPipeline`; the shipping
format is **16-bit PCM WAV**. Original Float32 CAF checkpoints are unchanged.
Real ASR measurements below use synthetic OS speech through the existing BB
service, not a physical watch or private recordings.

## Current pipeline

`AppModel.deliver` owns the durable queue, recipient identity and irreversible
send boundary. `TranscriptionPipeline` owns grouping, cache lookup, PCM assembly,
ASR and cleanup off MainActor. Approximately 30-second boundaries and existing
cache names are retained, so completed groups survive upgrades and retries.

The pipeline reads each original CAF once into a reusable PCM buffer and writes
16-bit WAV at the original sample rate/channel count. It does not resample,
remove speech, trim silence or use perceptual audio compression. Float32→Int16 quantization is
not bit-identical or mathematically lossless. Only the temporary upload is
quantized; saved original recordings remain intact.

Each completed transcript group is persisted atomically before the next request.
Sequential ASR preserves text order; verified upstream concurrency quotas are
unavailable. Cancellation and connection generation are checked across ASR
boundaries. Unique temporary uploads are removed on success/failure/cancellation;
original chunks are never deleted. ASR may reauthenticate once after 401;
ambiguous BB send/create mutations are never replayed.

## Real ASR comparison

The official `bb voice transcribe <file> --type audio/wav --json` command reaches
the existing `system/voice-transcription` service using normal CLI authorization.
No credentials were extracted and no agent prompt was dispatched. The fixture
contains generic English and Russian OS-TTS speech: 18.052 seconds, 866,496 mono
48kHz frames, 44 reference words. Six ASR calls total, with reversed-order WAV/AAC
repeats and then two calls validating the replacement PCM16 format.

| Format | Audio bytes | Total CLI response time, seconds | Reference coverage |
|---|---:|---|---|
| Former Float32 WAV | 3,470,080 | 3.716, 3.229 | 44/44 words in both calls |
| Shipping PCM16 WAV | 1,737,088 | 2.829, 1.778 | 44/44 words in both calls |
| Rejected AAC M4A experiment | 171,413 | 2.561, 4.142 | English 26 words omitted in both calls |

PCM16 reduces this fixture's upload bytes by **49.94%**. Normalized word edits
were zero in its two responses; order and negations were retained. This is one
synthetic bilingual example, not a general recognition-accuracy guarantee.
Maximum sample quantization error was 0.000015258789 (half a 16-bit LSB), measured
SNR 84.42dB, and host preparation took 17.045ms for this fixture.

The small number of calls, host upload and variable backend latency do not prove
a stable latency multiplier or watch/LTE improvement. The API returns only text;
actual per-call provider/model metadata is unavailable. CLI duration includes
transport and service processing, which this measurement cannot separate.

AAC was rejected despite substantially smaller files: the omission reproduced
in both reverse-order calls. Decoded English audio had the complete frame count,
0.9967 correlation and 0.9961 RMS ratio to source; missing encoded frames do not
explain it. An upstream/container/language effect is possible, but its cause is
unproven. No AAC option or fallback is shipped in the production pipeline.

## Reproducible local checks

```sh
./native/check.sh
swiftc -swift-version 6 native/Sources/BBWatchCore/DurableStore.swift \
  native/Sources/BBWatch/BBClient.swift native/Sources/BBWatch/Diagnostics.swift \
  native/Sources/BBWatch/TranscriptionPipeline.swift \
  native/Checks/TranscriptionWireFixture.swift \
  native/Checks/TranscriptionPerformanceCheck.swift -o /tmp/BBTranscriptionPerformance
/tmp/BBTranscriptionPerformance
```

The performance executable compares the original Float32 assembly path with the
current PCM16 pipeline on identical 30-second, 48kHz synthetic tone checkpoints.
Its URLProtocol transport is local on macOS: it does not measure HTTP/radio/ASR. Warm medians in the final host comparison: assembly 5.266→2.204ms, local total 6.450→2.863ms; audio 5,764,096→2,884,096 bytes. These are synthetic nonoptimized host timings.
The behavioral check reopens encoded WAV, verifies checkpoint order, duration and
quantization bounds, durable segment retry/relaunch/extension, bounded auth
recovery, cancellation/connection isolation, cleanup and unchanged originals.

watchOS Foundation does not reliably intercept this custom URLProtocol mock;
fixture hosts use `.invalid` so an unsupported run fails closed. Watch-runtime
encoder checks run separately without authentication or ASR calls. Simulator
encoding/playback evidence does not establish physical microphone or speaker quality.

## Remaining physical measurement

For user-initiated sends, collect content-free diagnostic timestamps, audio
seconds, encoded byte count, cache hits and stage durations on the physical watch.
Measure Wi-Fi and standalone LTE separately, short and multi-group recordings,
successes and failures. Separate upload/ASR from BB acceptance, agent work and
screen refresh. Do not log audio, transcripts, credentials, recipient IDs or URLs.

Installed BB contract research found a possible cloud→Codex fallback longer than
the watch's current 90-second ASR timeout. That remains an external reliability
limit; it must not produce an invented success or a replayed BB mutation. There
is no claim of maximum theoretical transcription speed or measured energy saving.
