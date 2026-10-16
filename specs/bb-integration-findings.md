# BB integration findings

Verified 2026-10-16 against installed BB 0.46.0 and primary get-bb/bb main source. No credentials accessed, no writes to BB, no test messages sent.

## Independent watch authentication

BB already supports separately revocable mobile machine credentials; do not copy the desktop/server credential. User generates a one-use, ten-minute code in BB Settings → Mobile → Add mobile device. Watch can accept code with apex (default `https://getbb.app`).

1. `POST https://getbb.app/api/connect/redeem-machine`, JSON `{ "code": "user-entered", "deviceName": "Apple Watch" }`. Response `{credential, machineId, serverUrl}`. Validate returned server URL is HTTPS and a direct child hostname of approved apex before storing credential in watch Keychain. Codes can fail already-used/expired/machine-limit. Redemption timeout is ambiguous: do not silently mint or retry side effects.
2. `POST {serverUrl}/api/connect/desktop-session`, header `x-bb-connect-machine: <credential>`, no body. Response `{cookie:{domain,expiresAt,name,value}}`. Install secure HTTP-only cookie scoped to validated server; ordinary mobile SDK uses cookie-backed requests. Refresh session before expiry using retained machine credential. Never persist cookie or credential in outbox/logs.
3. Calls below target returned `serverUrl`, not localhost. BB host must remain online and connected. Neither iPhone relay nor a public tokenville proxy is required.

Primary source: [redeem-machine](https://github.com/get-bb/bb/blob/main/packages/connect-client/src/redeem-machine.ts), [desktop-session](https://github.com/get-bb/bb/blob/main/packages/connect-client/src/desktop-session.ts), [mobile cookie installation](https://github.com/get-bb/bb/blob/main/apps/mobile/src/lib/session/cookie-store.ts), [pairing format](https://github.com/get-bb/bb/blob/main/packages/connect-client/src/mobile-pairing.ts).

## Native HTTP adapter contracts

All paths below prefixed `/api/v1`. Installed primary artifact: `/Applications/bb.app/Contents/Resources/app.asar.unpacked/node_modules/bb-app/server/dist/start-server.js` (unminified bundled source with original source-path comments).

| Operation | Method/path | Contract |
|---|---|---|
| Projects | GET `/projects` | Project array; decode id/name, preserve unknown fields |
| Threads | GET `/threads?projectId=…&archived=false&limit=50&offset=0` | Thread array; id, title, projectId and real status; SDK contract at lines 44945+ |
| Thread detail | GET `/threads/{id}?include=environment` | Thread with optional environment; do not infer running from delivery |
| Create+first prompt | POST `/threads` | `{projectId,origin:"sdk",environment:{type:"project-default"},input:[{type:"text",text:"…"}]}`; title/provider optional; HTTP 201 thread. Environment may reject project without valid default; expose failure, retain recording |
| Existing prompt | POST `/threads/{id}/send` | `{input:[{type:"text",text:"…"}],mode:"queue-if-active"}`. Response `{ok:true,delivery:"sent"}` or `{ok:true,delivery:"queued",queuedMessage:{…}}`. Modes also auto/start/steer/steer-if-active; use queue-if-active to preserve work |
| Transcribe | POST `/system/voice-transcription` | multipart `file` (nonempty real audio), optional `prompt`; response `{text:string}`. Provider configured in BB AI services. No committed audio-upload session protocol here |
| History | GET `/threads/{id}/timeline?segmentLimit=30` | `{rows:[…],maxSeq,timelinePage:{hasOlderRows,olderCursor,…},…}`. Older pagination requires BOTH beforeAnchorSeq and beforeAnchorId from olderCursor. It is a structured timeline, not array of chat messages |
| Incremental events | GET `/threads/{id}/events?afterSeq=N&order=asc&limit=N` | Sequenced event history; persist last applied sequence, refresh timeline after reconnect. Full event envelope decoder must follow server contract, not guesses |
| Pending questions | GET `/threads/{id}/interactions` | Array of pending interaction objects; GET `/…/interactions/{interactionId}` reads current state including resolved |
| Answer question | POST `/threads/{id}/interactions/{interactionId}/resolve` | `{kind:"user_answer",answers:{"question-id":{selected:["option-value"],freeText:"optional"}}}`; response current interaction object |

Prompt input discriminators are text/image/localImage/localFile (no audio). Transcribe chunks then submit one text input. Persist each chunk transcript before proceeding; do not send incomplete transcription silently. Transcription file formats/size limits depend on selected service and remain unverified.

## Important reliability boundary

**Ordinary BB create/send has no request idempotency field or supported Idempotency-Key contract in installed 0.46.0.** Send schema fields are input/model/serviceTier/reasoningLevel/permissionMode/executionInputSources/mode/senderThreadId/pluginSubmission/sendAt. Creation likewise has no client operation ID. The bundle's `idempotencyKey` belongs to automations, not message send. A local UUID alone does not prevent duplicates after BB accepts and response is lost.

Therefore direct adapter can deliver real prompts, but cannot claim A13 exactly-once on timeout. Persist an `acceptanceUnknown` state and require reconciliation before any re-send. Matching transcript text is not proof of identity. A durable backend inbox plus receipt is needed, but even a wrapper cannot promise exactly-once across a crash between BB send and receipt persistence unless BB gains durable operation identity/reconciliation. Do not implement blind timeout retry or label it accepted.

## Interaction schemas and races

`payload.kind:"user_question"` contains questions `{id,prompt,shortLabel?,multiSelect,options?:[{value,label,description?}],allowFreeText}`. Answer keys use question IDs; selected uses option values, never labels/index. Current bounds: selected ≤4, freeText ≤4096 characters. Respect multiSelect and allowFreeText. Voice text where free text prohibited must be a separately labeled clarification, never fabricated option selection.

Resolution service (bundle lines 220491+) atomically transitions pending→resolving. Repeating the identical resolution when resolving/resolved returns current interaction; a competing different resolution raises conflict. There is no explicit expected-version field. Keep 10-second Undo intent entirely on watch, persist absolute deadline, fetch latest interaction immediately before commit. Conflict preserves draft and displays stale/resolved state. `/respond` with `{value:…}` is for plugin-specific interactions, not generic user question answers. Approval decisions have allow_once/allow_for_session/deny schemas and must not be treated as ordinary text choices.

## Remaining unverified integration work

- No live mutation/end-to-end pairing performed. A real watch credential, cookie session, transcription and one accepted prompt still require device run.
- Timeline decoder: only `kind:"conversation"` rows are chat; they contain `id,threadId,turnId?,sourceSeqStart,sourceSeqEnd,startedAt,createdAt,messageSeq,text,role` with role user/assistant. Other row kinds must remain distinct. Conversation schema verified at installed bundle lines 44289–44350; nested turn-summary history may require expansion for full older conversation.
- Native remote push/APNs for standalone watch not demonstrated. Foreground HTTP catch-up works; background delivery must not be promised based on WebSocket availability.
- No BB summary or speech-generation HTTP contract was found here. System TTS can read full text; a shorter summary must be explicitly derived, never replace original.
- Exact error JSON envelopes, event return shape, audio provider limits and physical watch availability are not established by this research.

Use this source-backed direct adapter now for auth/list/history/transcribe/send/interaction resolution, while retaining explicit acceptance-unknown handling. Full product completion remains blocked on exactly-once backend support and physical LTE validation.

Conflict error verified in installed source at lines 220083+: HTTP 409, code `invalid_request`, message `Pending interaction <id> is already <status>`. Plugin generic payload resolution via wrong endpoint returns HTTP 400 `invalid_request` (`Plugin interactions must be submitted through the respond endpoint`).

## Executed adapter contract check

`native/Checks/BBClientContractCheck.swift` drives the actual Foundation URLSession path with a URLProtocol HTTP fixture. It validates credential handshake and cookie on subsequent requests; BB nullable title/history shape; conversation-only message filtering; supported single question versus explicitly unsupported multiquestion; accepted interaction status; positive queued send receipt; deliberately lost acknowledgement and no automatic resend. This checks HTTP interoperability and uncertainty policy, not live BB/device delivery.

Run on macOS:

```sh
swiftc native/Sources/BBWatch/BBClient.swift native/Checks/BBClientContractCheck.swift -o /tmp/bb-watch-contract-check
/tmp/bb-watch-contract-check
```

Passed 2026-10-16. Positive receipt control exposed an initial fixture weakness (URLSession exposes request payload through httpBodyStream); fixture now consumes the stream and validates actual JSON before simulating acknowledgement loss. Cookie wire assertion failed before adapter explicitly attached its scoped authentication cookie; passes after fix. Production sessions reject redirects, retain cookies only in adapter memory, and avoid shared cookie storage. Redirect rejection itself has not been exercised on a real TLS server.

Update: the adapter now loads active threads through sidebar-bootstrap and reads the latest timeline only. Older history/thread pagination and complete multiquestion/free-text UI remain follow-up work, not supported behaviors implied by decoder success.
