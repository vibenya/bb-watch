# Chats and watch integration evidence

Verified 2026-10-16 against installed BB 0.46.0 and installed `chat-sidebar` plugin commit `d9addf7502aa06ef5b335495a4415654e20be145`. Read-only research; no pairing, prompts or plugin configuration mutations performed.

## Shared list contract

Plugin source root: `https://github.com/seoperin/bb-plugin-chat-sidebar/tree/d9addf7502aa06ef5b335495a4415654e20be145`.

- `lib/model.ts:83`: pins sort by `pinSortKey` lexicographically; keyed pins precede unkeyed pins, whose fallback is `pinnedAt` ascending. Equal keys retain incoming order.
- `lib/model.ts:100`: hide hidden and archived threads. Fold each thread through `parentThreadId ?? lifecycleOwnerThreadId`, stopping at a missing ancestor or a cycle. Root activity is maximum `updatedAt/latestAttentionAt` across its family. Pins come first; other rows sort by family activity descending.
- `lib/model.ts:409`: trimmed, case-insensitive substring search covers root display title, project name, root branch, folded children's display titles. It is local list search, not full conversation search.
- `hooks/use-pinned-order.ts`: pin order is global across folders. SDK `threads.reorderPinned` writes `PATCH /api/v1/threads/:id/pin-order` with `{previousThreadId,nextThreadId}` (nullable neighbors). Pin/unpin use POST `/threads/:id/pin` and `/unpin`.

`native/Sources/BBWatch/ChatList.swift` projects these ordering, ancestry and search semantics into Foundation values for the watch UI. It does not implement plugin status-lane ranking of children, unread aggregation, folders, archive navigation, quiet-thread controls or project grouping. The watch uses server title/titleFallback as display-title inputs; provider-derived fallback parity is not established.

## One bootstrap, selective questions

Installed server artifact: `/Applications/bb.app/Contents/Resources/app.asar.unpacked/node_modules/bb-app/server/dist/start-server.js`.

`GET /api/v1/sidebar-bootstrap` has no query. Response:

```json
{"sections":[],"projects":[{"id":"…","name":"…","threads":[]}],"personalProject":{"id":"…","name":"…","threads":[]}}
```

The real objects contain additional fields. Flatten project and personal-project threads, deduplicating by ID. Unlike the former `threads?limit=50` adapter, bootstrap includes all active threads for public projects and personal project. Evidence: response schema at line 42107, builder at 183301–183365.

Each thread-list entry has `hasPendingInteraction:boolean`, `pinSortKey:string|null`, `pinnedAt:number|null`, `parentThreadId`, `lifecycleOwnerThreadId`, `latestAttentionAt`, `updatedAt`, `visibility`, `archivedAt`, `title`, `titleFallback`, and `environmentBranchName` (schema around 18966–19010). Timestamps are server numeric millisecond values; retain their ordering without converting units.

There is no global pending-interaction HTTP endpoint in this installed version. Publish threads after bootstrap; fetch `/threads/:id/interactions` only for entries with `hasPendingInteraction == true`, with bounded concurrency and separate question-loading failure. An interaction failure must not suppress a successfully loaded chat list. Refresh the interaction immediately before committing a response because the flag is a snapshot.

## Shared plugin configuration

`server.ts` and `lib/rpc.ts` declare server-backed folder layout, colors, and settings. Authenticated clients can call:

- POST `/api/v1/plugins/chat-sidebar/rpc/folders_get`, body `null`; response `{ok:true,result:{layout,revision}}`.
- POST `/api/v1/plugins/chat-sidebar/rpc/colors_get`, body `null`; response `{ok:true,result:{"project-id":"color-id"}}`.
- `folders_set` input `{layout,baseRevision}` returns current state plus `ok`. A stale revision is refused, preserving newer device edits.

The generic RPC envelope and client caller permission are verified in server artifact lines 193945–193965 and 194825–194904. Do not copy an internal plugin caller token; ordinary authenticated clients omit that header.

Folder layout version is `1`; at most 40 custom folders plus five generator entries, folder names at most 40 characters, IDs lowercase alphanumeric 1–40 characters, per-rule lists at most 500 IDs, rule text at most 200 characters, waiting threshold 0–43,200 minutes. Color map caps at 500 projects. The last 20 replaced layouts are retained. These limits come from `lib/folders.ts`, `lib/rpc.ts`, `lib/folder-store.ts`. Layout `null` means derive folders from plugin settings; treating it as an empty folder list would be wrong.

Selected folder and collapsed headings live in browser localStorage (`lib/storage.ts`); search query is React state (`components/chat-list.tsx:130`). Those conveniences currently do not synchronize between devices.

## Native plugin UI boundary

Chats `app.tsx` registers a React `experimental_threadList` slot. The current mobile README (`get-bb/bb/apps/mobile/README.md`) describes an Expo native shell around the server web interface: threads, projects, plugins and server settings run inside the page. iOS inherits plugin UI through this WebView, not through a native Swift plugin-view SDK.

The watch can share authenticated server state and plugin configuration while rendering SwiftUI. General arbitrary plugin UI customization requires a new bounded declarative watch contract or individual native plugin adapters. Neither is an existing capability established by this research. No watchOS arbitrary React/WebView compatibility is claimed.

## Verification

`native/Checks/ChatListCheck.swift` uses external-shaped JSON to exercise shared pin order, family activity lifting, parent and lifecycle-owner folding, hidden/archive exclusion, missing ancestors, cycle termination, and case-insensitive title/project/branch/child search. It is a pure Foundation check; it does not prove live device rendering or live plugin RPC.

```sh
swiftc native/Sources/BBWatch/BBClient.swift native/Sources/BBWatch/ChatList.swift native/Checks/ChatListCheck.swift -o /tmp/bb-watch-chat-list-check
/tmp/bb-watch-chat-list-check
```
