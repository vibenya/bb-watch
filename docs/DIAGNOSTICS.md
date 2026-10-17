# Watch latency diagnostics

The app's private Application Support/BBWatch/diagnostics.log retains the newest
200 typed `v2` milestones. Each record has a millisecond wall timestamp. Related
request/delivery events share a random local `op` UUID and cumulative monotonic
`elapsed_ms`. `selection` is a random local screen-selection revision; it is not
a server thread ID. `foreground` is sampled at each milestone, and scene events
record active/inactive/background transitions. A long elapsed interval can
include suspension: these records do not claim CPU or server execution time.

For display latency, match `timeline.started`, `timeline.received`, and
`stage.applied` by `op`. A response rejected before publication emits `stage.discarded`; cancellation
can instead end in `timeline.failed`. Counts describe messages, not their content. Sidebar
`threads.applied` is separate from the completion of projects/questions refresh.

A delivery attempt links `delivery.started`, per-group `assembly.started` and
`assembly.finished`, `transcription.started` and `transcription.finished`, then
`send.started` and `send.accepted`. Subtract cumulative elapsed values for a
stage's duration. Transcription timing includes upload, network and server ASR;
it cannot separate those components. Group indices are local numeric positions;
`bytes` describes the actual upload file and `audio_ms` its recorded duration.
Cached groups emit `transcription.cached`. Failures end in `delivery.failed`;
the preceding milestone identifies the phase. A send acceptance record means
the HTTP response was received, not that the agent completed its turn.

Only typed event names, UUIDs, booleans and numeric metrics are accepted. Errors
record a whitelisted category and code, never descriptions, userInfo or custom
domains. Audio, messages, transcripts, URLs, credentials, server identifiers and
device identifiers are excluded. Existing legacy records are retained until they age out of the 200-line
bound; only new `v2` records have the typed-field privacy guarantee. These logs do not provide cross-server request correlation; match server
observations by time with that limitation, and never infer exact remote latency
from a nearby unrelated request.
