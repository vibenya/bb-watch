import { z } from 'zod';

const id = z.string().regex(/^[A-Za-z0-9_-]{1,96}$/);
const uint = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
export const hash = z.string().regex(/^[a-f0-9]{64}$/);
export const scope = z.strictObject({ instanceId: id, accountId: id, connectionId: id, deviceId: id });
export const intent = z.discriminatedUnion('kind', [
  z.strictObject({ kind: z.literal('bb') }),
  z.strictObject({ kind: z.literal('thread'), threadId: id }),
]);
const predecessor = z.strictObject({ operationId: id, sequence: uint.min(1), intent });
export const manifest = z.strictObject({
  v: z.literal(1), scope, operationId: id, intent,
  order: z.strictObject({ sequence: uint.min(1).max(64), predecessors: z.array(predecessor).max(63) }),
  audio: z.strictObject({
    parts: z.array(z.strictObject({ index: uint, segmentId: id,
      encoded: z.strictObject({ encoding: z.enum(['fixture-u8', 'aac-lc-m4a-candidate']), bytes: uint.min(1), sha256: hash }),
      source: z.strictObject({ sampleFormat: z.enum(['fixture-u8', 'float32', 'int16']),
        endian: z.literal('little'), interleaved: z.boolean(), sampleRateHz: uint.min(1),
        channels: uint.min(1).max(32), frames: uint.min(1), bytes: uint.min(1), sha256: hash })
    })).min(1).max(64),
    incompleteness: z.array(z.strictObject({ afterPartIndex: z.number().int().min(-1).max(63),
      reason: z.enum(['interruption', 'input-stall', 'write-failure', 'seal-timeout', 'crash-tail']) })).max(64),
  }),
});
const base = { v: z.literal(1), operationId: id };
export const request = z.discriminatedUnion('kind', [
  z.strictObject({ v: z.literal(1), kind: z.literal('declare'), manifestUtf8: z.string().max(65536), manifestSha256: hash }),
  z.strictObject({ v: z.literal(1), kind: z.literal('abandon'), manifestUtf8: z.string().max(65536), manifestSha256: hash }),
  z.strictObject({ ...base, kind: z.literal('seal'), manifestSha256: hash }),
  z.strictObject({ ...base, kind: z.literal('status') }),
]);
export const partHeaders = z.strictObject({ ...base, manifestSha256: hash, partIndex: uint.max(63) });
export const receipt = z.strictObject({ ...base, kind: z.literal('receipt'), scope,
  manifestSha256: hash, jobId: id, receiptId: id, acceptedAtMs: uint,
  validationProfile: z.enum(['fixture-bytes-v1', 'decoded-audio-v1']),
  partCount: uint.min(1), encodedBytes: uint.min(1), sourceFrameCounts: z.array(uint.min(1)).min(1).max(64),
});
export const response = z.discriminatedUnion('kind', [
  receipt,
  z.strictObject({ ...base, kind: z.literal('receiving'), manifestSha256: hash, receivedPartIndexes: z.array(uint) }),
  z.strictObject({ ...base, kind: z.literal('fenced'), scope, manifestSha256: hash, fenceId: id,
    reason: z.enum(['abandoned', 'target-unavailable']), acknowledgedAtMs: uint, definitiveNonacceptance: z.literal(true) }),
  z.strictObject({ ...base, kind: z.literal('unknown'), definitiveNonacceptance: z.literal(false) }),
  z.strictObject({ v: z.literal(1), kind: z.literal('error'), code: z.enum(['unauthorized', 'invalid', 'conflict', 'missing-parts', 'unsupported-audio', 'limit', 'storage-unavailable']) }),
]);
// Proposed control-plane exchange only. No pairing endpoint is registered in Phase 0.
export const pairing = z.discriminatedUnion('kind', [
  z.strictObject({ v: z.literal(1), kind: z.literal('redeem'), setupCode: z.string().min(6).max(64), deviceId: id, requestId: id }),
  z.strictObject({ v: z.literal(1), kind: z.literal('paired'), scope, keyId: id, deviceToken: z.string().min(32).max(256), scopes: z.tuple([z.literal('intake'), z.literal('threads-read')]) }),
  z.strictObject({ v: z.literal(1), kind: z.literal('rotate'), scope, requestId: id }),
  z.strictObject({ v: z.literal(1), kind: z.literal('revoke'), scope, requestId: id }),
]);
export const threadSnapshot = z.strictObject({ v: z.literal(1), scope, threadId: id,
  observedAtMs: uint, validUntilMs: uint, revision: id,
  activity: z.enum(['unknown', 'idle', 'working', 'question', 'done', 'failure']),
  title: z.string().max(512), excerpt: z.string().max(2048).nullable(),
});
export type Manifest = z.infer<typeof manifest>;
export type Scope = z.infer<typeof scope>;
export type ResponseBody = z.infer<typeof response>;
// Proposed internal facts. No core mutation worker is implemented in Phase 0.
export const dispatchFact = z.discriminatedUnion('state', [
  z.strictObject({ ...base, scope, state:z.literal('not-attempted') }),
  z.strictObject({ ...base, scope, state:z.literal('attempting'), attemptId:id, retryDisposition:z.literal('reconcile-only') }),
  z.strictObject({ ...base, scope, state:z.literal('unknown'), attemptId:id, retryDisposition:z.literal('reconcile-only') }),
  z.strictObject({ ...base, scope, state:z.literal('accepted'), attemptId:id, threadId:id, coreReference:id, retryDisposition:z.literal('never') }),
]);
