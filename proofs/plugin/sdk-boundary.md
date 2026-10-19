# Installed SDK / Jev boundary — Phase 0, 19 October 2026

Research used current workspace specs/design, installed SDK declarations/test runtime,
read-only installed plugin inventory and RPC discovery signatures, and parent-authorized
Jev prototype signatures/policy. No ancestors, old watch app, other app checkout,
transcripts, credentials, recordings, user messages or thread titles were read.

## Version and declarations

`bb --version` → **0.46.0**. `bb plugin types plugin`, then
`bb plugin types --check plugin` → exact `@get-bb/plugin-sdk` **0.6.37** pin matches.
`plugin/package-lock.json` locks it and all local dependencies. Node v22.23.1,
Darwin arm64. Authoritative file: `plugin/node_modules/@get-bb/plugin-sdk/bundled-types/bb-plugin-sdk.d.ts`.
SHA-256 `56648d7a63433fc4e3234220f89b1442808585fa70bddc6f0a7cc73fb2eadec8`.
Testing declarations SHA-256
`eb809257de75d533ec9353c4f33b6bb2776577163bd014aaa58adddc0ccce3f8`.

Signatures below are from that pinned file; line numbers are for this pin only.

| Capability | Actual declaration | Limit / disposition |
|---|---|---|
| HTTP | L22898 `type PluginHttpAuthMode = "local" \| "none" \| "token"`; L22930 `route(method: string, path: string, handler: PluginHttpHandler, opts?: {auth?: PluginHttpAuthMode}): void` | Mounted `/api/v1/plugins/<id>/http/<path>`. Route argument starts `/`. `local` uses local Origin/Host + JSON non-GET; `token` accepts plugin-wide token header/query; `none` supplies no SDK auth. No scoped per-watch credential in these modes. Fixture handlers implement deny-by-default per-device bearer/hash checks with `none`; remote outer admission is unproven. |
| Durable SQL | L22328 `database(): Database.Database` | Host-owned `<dataDir>/plugins/<id>/data.db`, better-sqlite3, WAL, busy_timeout=5000, shared handle closed by host on reload/dispose. Proof additionally sets synchronous=FULL. BLOB parts and atomic jobs/receipts fit supported SQL; no production plugin filesystem paths. |
| Migration | L22336 `migrate(db: Database.Database, statements: string[]): void` | Ordered append-only statement indexes/hashes, one migration transaction. Five initial tables; not shipped/frozen. |
| KV | L22311 `get<T>(key:string):Promise<T\|undefined>` / `set(key:string,value:unknown):Promise<void>` | JSON, 256KiB per value. Not used for source bytes/atomic multirow receipt. |
| Private settings | L22240 `PluginSettingDescriptor`, `secret?: true`; L22303 `settings.define<Ds>(descriptors: Ds): PluginSettingsHandle<Ds>` | Supported configuration boundary for future Jev key. No settings defined/read or key copied now. Credential hashes live in plugin SQL fixture, no raw production key provisioning. |
| Background | L22973 `service(name:string, service:{start(signal:AbortSignal):void\|Promise<void>}):void` | Host abort on dispose, capped restart backoff. Supports future recoverable job scanner; not registered in Phase 0. |
| Thread candidates | L18308 `list(args?: ThreadListArgs):Promise<ThreadListResult>` | Filters include projectId/environmentId, archived, limit, offset (L17876). Requires plugin-side connection authorization and a bounded candidate policy; SDK access itself is broader than watch grants. Not called. |
| Original BB context | L18351 `timeline(args:ThreadTimelineArgs):Promise<ThreadTimelineResult>`; L18316 `message(args:ThreadMessageArgs):Promise<ThreadMessageResult>`; L18244 `events.list(args:ThreadEventsListArgs):Promise<ThreadEventsListResult>` | Timeline has threadId, segmentLimit, beforeAnchorSeq/Id, afterSequence and deferContent/includeNestedRows/summaryOnly string booleans (L15184,18174). message has threadId+seq and before/after (L18182). Events support threadId, seq bounds, limit, asc/desc and types (L18158). Use original bounded messages on computer after authorization; no provider transcript scraping or notification context. No content calls made. |
| Current thread | L18299 `get(args:ThreadGetArgs):Promise<ThreadGetResult>` | ThreadResponse or ThreadWithIncludesResponse; activity/freshness and original excerpt mapping still require TG2 adapter proof. No title read. |
| Voice transcription | L17773 `transcribeVoice(args:SystemVoiceTranscriptionArgs):Promise<SystemVoiceTranscriptionResult>`; L17704 `{file:Blob; prompt?:string; signal?:AbortSignal}`; L10497 response `{text:string}` | Available via `bb.sdk.system`. No persistent segment job, per-source cache or audio fidelity guarantee implied. No call made; future decode-to-PCM16 and complete ordered ASR result ledger required. |
| Execution catalog | L17767 `executionOptions(args?:SystemExecutionOptionsArgs):Promise<SystemExecutionOptionsResult>`; args extends `{environmentId?:string;hostId?:string;providerId?:string}` with signal | Actual selected environment/provider catalog must validate Jev output; existing-thread model policy cannot be silently overridden. No catalog/provider call made. |
| Existing dispatch | L18338 `send(args:ThreadSendArgs):Promise<ThreadSendResult>`; L18063 extends SendMessageRequest plus threadId | Request schema L13197–13337 has input, mode, optional execution settings and `pluginSubmission:{data:JsonValue,pluginId:string}`. Response L13343 discriminates `delivery:'sent'`/`'queued'`. No declared caller idempotency key/reconcile-by-operation contract found. Metadata is not dedupe evidence. No send made. |
| New dispatch | L18339 `spawn(args:ThreadSpawnArgs):Promise<ThreadSpawnResult>`; L18020–18033 base CreateThreadRequest plus input or prompt | Returns ThreadResponse (L17960). No operation idempotency/reconciliation semantics established. New-thread create/acceptance ambiguity remains open; no spawn made. |
| Cross-plugin call | L17456 `experimental_discoverRpc(args?):Promise<PublishedPluginRpcMethod[]>`; L17464 `callRpc<TOutput>(args:PluginRpcArgs<TOutput>):Promise<TOutput>` | Discovery signatures only were queried. No Jev routing registration found. |

## Existing Jev versus missing BB adapter

`bb plugin list --json` was reduced to plugin IDs/versions/status. No Jev plugin is
installed by name. `bb plugin rpc list --json` was reduced to pluginId+method;
only bb-account fetch/status/wait and provider usage list/get signatures were
published. This cannot rule out private/non-discoverable integrations; it proves
no suitable discoverable RPC was found, not that Jev does not exist.

Parent explicitly authorized these current integration references:
`~/satchel/.satchel-automation/jev-router/README.md`, `router.py`, and
`factory/factory.py` L249–267. Only source signatures/policy read; never executed,
never read fallback `.env`, secrets or decisions logs. Prototype signatures:

```python
ask_jev(state: dict, timeout: float = 8.0) -> dict  # answers map
route_for(task: str, recent: str = "") -> tuple[str, str, str, dict]
```

The existing hosted call is `POST https://api.typesafe.ai/v1/systemone` with
`{model:"jev-latest",state,questions}` → `answers`. Current prototype grades
model difficulty/frontier need over supplied `{task,recent}`; it is NOT a BB
thread resolver and does not fetch BB history. Its capable-model fallback is
not an acceptable destination fallback. No service/API request was made.

Missing explicit boundary: a computer-side adapter must obtain authorized bounded
SDK candidate threads/original messages, apply user/project/existing-thread policy,
ask Jev only about that supplied state, validate confidence/IDs/execution catalog,
and persist one route/model decision. Its minimal proposed internal function and
hold/target rules are in `contracts/README.md`. Private key configuration,
confidence calibration, candidate budgets, new-thread policy and reconciliation
remain unimplemented. Exact frozen manual target bypasses destination routing;
spoken conflict holds. Watch sends only audio plus BB/exact-thread intent.
