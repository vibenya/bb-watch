import { z } from 'zod';
import { manifest as manifestV1, scope, intent, hash, receipt as receiptV1, response as responseV1, partHeaders as partHeadersV1 } from './protocol.ts';
export const id = z.string().regex(/^[A-Za-z0-9_-]{1,96}$/);
const uint = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
export const fact = z.strictObject({operationId:id,sequence:uint.min(1),intent});
export const checkpointRef = z.strictObject({checkpointId:id,epoch:id,throughSequence:uint.min(1),factsHash:hash});
export const order = z.strictObject({epoch:id,sequence:uint.min(1),checkpoint:checkpointRef.nullable(),predecessors:z.array(fact).max(64)});
export const manifest = manifestV1.extend({v:z.literal(2),order});
export const request = z.discriminatedUnion('kind',[
  z.strictObject({v:z.literal(2),kind:z.literal('declare'),manifestUtf8:z.string().max(65536),manifestSha256:hash}),
  z.strictObject({v:z.literal(2),kind:z.literal('abandon'),manifestUtf8:z.string().max(65536),manifestSha256:hash}),
  z.strictObject({v:z.literal(2),kind:z.literal('seal'),operationId:id,manifestSha256:hash}),
  z.strictObject({v:z.literal(2),kind:z.literal('status'),operationId:id}),
]);
export const checkpointRequest = z.strictObject({v:z.literal(2),kind:z.literal('checkpoint'),requestId:id,epoch:id,base:checkpointRef.nullable(),facts:z.array(fact).min(1).max(64)});
export const checkpointResponse = z.strictObject({v:z.literal(2),kind:z.literal('checkpoint'),scope,requestId:id,checkpoint:checkpointRef});
export const grants = z.strictObject({revision:id,threads:z.array(z.strictObject({threadId:id,projectId:id})).max(64),projects:z.array(id).max(64),allowNew:z.boolean()});
export const identity = z.strictObject({instanceId:id,accountId:id,revision:id});
export const operatorRequest = z.discriminatedUnion('kind',[
  z.strictObject({v:z.literal(2),kind:z.literal('issue-code'),requestId:id,repairConnectionId:id.nullable()}),
  z.strictObject({v:z.literal(2),kind:z.literal('revoke'),scope,requestId:id}),
  z.strictObject({v:z.literal(2),kind:z.literal('release-order'),scope,operationId:id,requestId:id,confirmed:z.literal(true),reason:z.enum(['abandon-missing','proceed-despite-unknown'])}),
]);
export const redeem = z.strictObject({v:z.literal(2),kind:z.literal('redeem'),requestId:id,setupCode:z.string().regex(/^[a-f0-9]{12}$/),deviceId:id,tokenSha256:hash});
export const paired = z.strictObject({v:z.literal(2),kind:z.literal('paired'),requestId:id,scope,keyId:id,tokenSha256:hash,epoch:id,grants,stagedAudioPolicy:z.literal('explicit-send-opt-in-required')});
export const bindingOptIn = z.strictObject({v:z.literal(2),kind:z.literal('staged-send-opt-in'),scope,epoch:id,stagedIds:z.array(id).min(1).max(64),confirmed:z.literal(true)});
export const operatorResponse = z.discriminatedUnion('kind',[
  z.strictObject({v:z.literal(2),kind:z.literal('pairing-code'),requestId:id,setupCode:z.string(),expiresAtMs:uint}),
  z.strictObject({v:z.literal(2),kind:z.literal('revoked'),requestId:id,scope}),
  z.strictObject({v:z.literal(2),kind:z.literal('order-released'),requestId:id,scope,operationId:id,releaseId:id,reason:z.string(),confirmed:z.literal(true)}),
]);
export const errorResponse = z.strictObject({v:z.literal(2),kind:z.literal('error'),code:z.string().max(64)});
const execution = z.strictObject({providerId:id,model:z.string().min(1).max(160)});
export const jevAnswer = z.discriminatedUnion('kind',[
  z.strictObject({kind:z.literal('existing'),threadId:id,projectId:id,execution,confidence:z.number().min(0).max(1),spokenConflict:z.boolean()}),
  z.strictObject({kind:z.literal('new'),projectId:id,execution,confidence:z.number().min(0).max(1),spokenConflict:z.boolean()}),
  z.strictObject({kind:z.literal('hold'),reason:z.enum(['ambiguous','conflict','insufficient-context'])}),
]);
export type Manifest = z.infer<typeof manifest>;
export type Fact = z.infer<typeof fact>;
export type CheckpointRef = z.infer<typeof checkpointRef>;
export type Grants = z.infer<typeof grants>;
export type Identity = z.infer<typeof identity>;
export const pairingTransaction = z.strictObject({v:z.literal(2),requestId:id,deviceId:id,
  keychainReference:id,tokenSha256:hash,tokenReadBackVerified:z.literal(true),
  exactRequestSha256:hash,requestFileReference:id});
export const checkpointCommit = z.strictObject({v:z.literal(2),scope,epoch:id,
  checkpoint:checkpointRef,coveredSequence:uint.min(1),exactRequestSha256:hash,
  requestId:id,localLedgerRetained:z.literal(true)});

export const receipt=receiptV1.extend({v:z.literal(2)});
export const partHeaders=partHeadersV1.extend({v:z.literal(2)});
export const intakeResponse=z.union(responseV1.options.map(option=>option.extend({v:z.literal(2)})));
export const contextEvidence=z.array(z.strictObject({threadId:id,updatedAtMs:uint,
  messages:z.array(z.strictObject({seq:uint,createdAtMs:uint,textSha256:hash})).max(2)})).max(4);
export const computerDecision=z.strictObject({v:z.literal(2),scope,operationId:id,kind:z.enum(['existing','hold']),reason:z.string().max(64).optional(),
  threadId:id.optional(),projectId:id.optional(),execution:execution.extend({permissionMode:z.enum(['accept-edits','auto','full']),reasoningLevel:z.enum(['none','low','medium','high','xhigh','max','ultra','ultracode']),serviceTier:z.string().max(160),source:z.enum(['client/thread/start','client/turn/requested','client/turn/start']),seq:uint.optional()}).optional(),
  confidence:z.number().min(0).max(1).nullable(),evidenceRevision:hash,contextEvidence,policyRevision:id,observedAtMs:uint});
