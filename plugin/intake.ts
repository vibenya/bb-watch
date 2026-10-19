import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import type { PluginStorage } from '@get-bb/plugin-sdk';
import { manifest, scope, type Manifest, type Scope, type ResponseBody } from './protocol.ts';

export const sha256 = (bytes: string | Uint8Array) => createHash('sha256').update(bytes).digest('hex');
export const MAX_PART_BYTES = 1024 * 1024;
const MAX_AUDIO_BYTES = 8 * MAX_PART_BYTES;
class IntakeError extends Error {
  code: Extract<ResponseBody, {kind:'error'}>['code'];
  constructor(code: Extract<ResponseBody, {kind:'error'}>['code']) { super(code); this.code = code; }
}
const fail = (code: IntakeError['code']): never => { throw new IntakeError(code); };
type RecordRow = { manifest_hash: string; manifest_json: string; result_json: string | null };
type LedgerRow = { operation_id: string; sequence: number; intent_json: string };
export type Grant = { scope: Scope; allowedThreads: string[] };

// No filesystem path supplied by the plugin: the BB host owns opening/closing this DB.
export class Intake {
  private db: ReturnType<PluginStorage['database']>;
  constructor(storage: PluginStorage) {
    this.db = storage.database();
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('synchronous = FULL');
    storage.migrate(this.db, [
      `CREATE TABLE credentials (key_id TEXT PRIMARY KEY, token_hash TEXT NOT NULL,
       scope_json TEXT NOT NULL, allowed_threads_json TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)`,
      `CREATE TABLE ledger (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, sequence INTEGER NOT NULL,
       intent_json TEXT NOT NULL, PRIMARY KEY(connection_id,operation_id), UNIQUE(connection_id,sequence))`,
      `CREATE TABLE intake (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, manifest_hash TEXT NOT NULL,
       manifest_json TEXT NOT NULL, result_json TEXT, PRIMARY KEY(connection_id,operation_id))`,
      `CREATE TABLE parts (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, part_index INTEGER NOT NULL,
       bytes BLOB NOT NULL, PRIMARY KEY(connection_id,operation_id,part_index))`,
      `CREATE TABLE jobs (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, job_id TEXT NOT NULL UNIQUE,
       dispatch_state TEXT NOT NULL DEFAULT 'not-attempted', PRIMARY KEY(connection_id,operation_id))`,
    ]);
  }
  authorize(headers: Headers): Grant {
    const keyId = headers.get('x-vt-key-id');
    const token = headers.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{32,256})$/)?.[1];
    if (!keyId || !token) return fail('unauthorized');
    const row = this.db.prepare('SELECT * FROM credentials WHERE key_id=? AND revoked=0').get(keyId) as
      {token_hash:string; scope_json:string; allowed_threads_json:string} | undefined;
    if (!row || !/^[a-f0-9]{64}$/.test(row.token_hash) || !timingSafeEqual(Buffer.from(row.token_hash, 'hex'), Buffer.from(sha256(token), 'hex'))) return fail('unauthorized');
    const identity = scope.parse(JSON.parse(row.scope_json));
    if (identity.deviceId !== headers.get('x-vt-device-id')) return fail('unauthorized');
    const allowedThreads = JSON.parse(row.allowed_threads_json);
    if (!Array.isArray(allowedThreads) || !allowedThreads.every(x => typeof x === 'string')) return fail('unauthorized');
    return {scope:identity, allowedThreads};
  }
  private row(g: Grant, op: string) {
    return this.db.prepare('SELECT * FROM intake WHERE connection_id=? AND operation_id=?').get(g.scope.connectionId, op) as RecordRow | undefined;
  }
  private result(g: Grant, op: string): ResponseBody {
    const row = this.row(g, op);
    if (!row) return {v:1, kind:'unknown', operationId:op, definitiveNonacceptance:false};
    if (row.result_json) return JSON.parse(row.result_json);
    const parts = this.db.prepare('SELECT part_index FROM parts WHERE connection_id=? AND operation_id=? ORDER BY part_index').all(g.scope.connectionId,op) as {part_index:number}[];
    return {v:1, kind:'receiving', operationId:op, manifestSha256:row.manifest_hash, receivedPartIndexes:parts.map(p=>p.part_index)};
  }
  private validate(g: Grant, text: string, digest: string): Manifest {
    if (Buffer.byteLength(text) > 65536 || sha256(text) !== digest) return fail('invalid');
    const m = manifest.parse(JSON.parse(text));
    for (const key of Object.keys(g.scope) as (keyof Scope)[]) if (m.scope[key] !== g.scope[key]) return fail('unauthorized');
    const prev = [...m.order.predecessors].sort((a,b)=>a.sequence-b.sequence);
    if (prev.length !== m.order.sequence-1 || prev.some((p,i)=>p.sequence !== i+1 || p.operationId === m.operationId) || new Set(prev.map(p=>p.operationId)).size !== prev.length) return fail('invalid');
    if (m.audio.parts.some((p,i)=>p.index !== i) || m.audio.incompleteness.some(x=>x.afterPartIndex >= m.audio.parts.length)) return fail('invalid');
    if (m.audio.parts.some(p=>p.encoded.bytes > MAX_PART_BYTES) || m.audio.parts.reduce((n,p)=>n+p.encoded.bytes,0) > MAX_AUDIO_BYTES) return fail('limit');
    for (const p of m.audio.parts) {
      const width = p.source.sampleFormat === 'float32' ? 4 : p.source.sampleFormat === 'int16' ? 2 : 1;
      if (p.source.bytes !== p.source.frames*p.source.channels*width) return fail('invalid');
    }
    return m;
  }
  private register(g: Grant, m: Manifest, text: string, digest: string) {
    for (const ref of [...m.order.predecessors, {operationId:m.operationId, sequence:m.order.sequence, intent:m.intent}]) {
      const existing = this.db.prepare('SELECT * FROM ledger WHERE connection_id=? AND (operation_id=? OR sequence=?)').all(g.scope.connectionId,ref.operationId,ref.sequence) as LedgerRow[];
      const intent = JSON.stringify(ref.intent);
      if (existing.some(r=>r.operation_id !== ref.operationId || r.sequence !== ref.sequence || r.intent_json !== intent)) return fail('conflict');
      this.db.prepare('INSERT OR IGNORE INTO ledger VALUES (?,?,?,?)').run(g.scope.connectionId,ref.operationId,ref.sequence,intent);
    }
    const row = this.row(g,m.operationId);
    if (row && (row.manifest_hash !== digest || row.manifest_json !== text)) return fail('conflict');
    this.db.prepare('INSERT OR IGNORE INTO intake VALUES (?,?,?,?,NULL)').run(g.scope.connectionId,m.operationId,digest,text);
  }
  private fence(g: Grant, m: Manifest, digest: string, reason: 'abandoned'|'target-unavailable'): ResponseBody {
    const current = this.result(g,m.operationId);
    if (current.kind === 'receipt' || current.kind === 'fenced') return current;
    const result: ResponseBody = {v:1,kind:'fenced',scope:g.scope,operationId:m.operationId,manifestSha256:digest,
      fenceId:randomUUID(),reason,acknowledgedAtMs:Date.now(),definitiveNonacceptance:true};
    this.db.prepare('UPDATE intake SET result_json=? WHERE connection_id=? AND operation_id=?').run(JSON.stringify(result),g.scope.connectionId,m.operationId);
    return result;
  }
  handle(g: Grant, input: import('zod').infer<typeof import('./protocol.ts').request>): ResponseBody {
    return this.db.transaction((): ResponseBody => {
      if (input.kind === 'status') return this.result(g,input.operationId);
      if (input.kind === 'declare' || input.kind === 'abandon') {
        const m = this.validate(g,input.manifestUtf8,input.manifestSha256);
        this.register(g,m,input.manifestUtf8,input.manifestSha256);
        if (input.kind === 'abandon') return this.fence(g,m,input.manifestSha256,'abandoned');
        if (m.intent.kind === 'thread' && !g.allowedThreads.includes(m.intent.threadId)) return this.fence(g,m,input.manifestSha256,'target-unavailable');
        return this.result(g,m.operationId);
      }
      const row = this.row(g,input.operationId);
      if (!row) return this.result(g,input.operationId);
      if (row.manifest_hash !== input.manifestSha256) return fail('conflict');
      const current = this.result(g,input.operationId);
      if (current.kind !== 'receiving') return current;
      const m = manifest.parse(JSON.parse(row.manifest_json));
      if (m.intent.kind === 'thread' && !g.allowedThreads.includes(m.intent.threadId)) return this.fence(g,m,input.manifestSha256,'target-unavailable');
      if (current.receivedPartIndexes.length !== m.audio.parts.length) return fail('missing-parts');
      // Real codec/frame validation is deliberately unavailable in Phase 0.
      if (m.audio.parts.some(p=>p.encoded.encoding !== 'fixture-u8' || p.source.sampleFormat !== 'fixture-u8')) return fail('unsupported-audio');
      const bytes = this.db.prepare('SELECT bytes FROM parts WHERE connection_id=? AND operation_id=? ORDER BY part_index').all(g.scope.connectionId,input.operationId) as {bytes:Buffer}[];
      if (bytes.some((b,i)=>b.bytes.byteLength !== m.audio.parts[i].source.bytes || sha256(b.bytes) !== m.audio.parts[i].source.sha256)) return fail('invalid');
      const jobId = randomUUID();
      const receipt: ResponseBody = {v:1,kind:'receipt',operationId:m.operationId,scope:g.scope,manifestSha256:row.manifest_hash,
        jobId,receiptId:randomUUID(),acceptedAtMs:Date.now(),validationProfile:'fixture-bytes-v1',
        partCount:m.audio.parts.length,encodedBytes:m.audio.parts.reduce((n,p)=>n+p.encoded.bytes,0),sourceFrameCounts:m.audio.parts.map(p=>p.source.frames)};
      this.db.prepare('INSERT INTO jobs (connection_id,operation_id,job_id) VALUES (?,?,?)').run(g.scope.connectionId,m.operationId,jobId);
      this.db.prepare('UPDATE intake SET result_json=? WHERE connection_id=? AND operation_id=?').run(JSON.stringify(receipt),g.scope.connectionId,m.operationId);
      return receipt;
    }).immediate();
  }
  part(g: Grant, op: string, digest: string, index: number, bytes: Uint8Array): ResponseBody {
    return this.db.transaction((): ResponseBody => {
      const row = this.row(g,op);
      if (!row) return this.result(g,op);
      if (row.manifest_hash !== digest) return fail('conflict');
      const result = this.result(g,op);
      if (result.kind !== 'receiving') return result;
      const m = manifest.parse(JSON.parse(row.manifest_json));
      const part = m.audio.parts[index];
      if (!part || part.encoded.bytes !== bytes.byteLength || part.encoded.sha256 !== sha256(bytes)) return fail('invalid');
      this.db.prepare('INSERT OR IGNORE INTO parts VALUES (?,?,?,?)').run(g.scope.connectionId,op,index,Buffer.from(bytes));
      return this.result(g,op);
    }).immediate();
  }
  // Read-only precursor to a worker. A receipt alone never releases an order barrier.
  barriers(g: Grant, operationId: string): string[] {
    const row = this.row(g,operationId);
    if (!row) return ['unknown-operation'];
    const m = manifest.parse(JSON.parse(row.manifest_json));
    if (m.intent.kind === 'bb') return ['unresolved-route'];
    return m.order.predecessors.filter(p=> {
      const result = this.result(g,p.operationId);
      if (result.kind === 'fenced') return false;
      if (p.intent.kind === 'thread' && p.intent.threadId !== (m.intent as {threadId:string}).threadId) return false;
      const job = this.db.prepare('SELECT dispatch_state FROM jobs WHERE connection_id=? AND operation_id=?').get(g.scope.connectionId,p.operationId) as {dispatch_state:string}|undefined;
      return job?.dispatch_state !== 'accepted';
    }).map(p=>p.operationId);
  }
}
export function errorBody(error: unknown): ResponseBody {
  return {v:1,kind:'error',code:error instanceof IntakeError ? error.code : error instanceof SyntaxError || (error as {name?:string})?.name === 'ZodError' ? 'invalid' : 'storage-unavailable'};
}
