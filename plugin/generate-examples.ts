import { writeFileSync } from 'node:fs';
import { declaration, makeManifest } from './fixtures.ts';
import { manifest, request, receipt, response } from './protocol.ts';
const first = makeManifest();
const second = makeManifest('operation-2',2,{kind:'thread',threadId:'thread-T'},[{operationId:first.operationId,sequence:1,intent:first.intent}]);
const third = makeManifest('operation-3',3,{kind:'thread',threadId:'thread-U'},[...second.order.predecessors,{operationId:second.operationId,sequence:2,intent:second.intent}]);
const fixtureReceipt = receipt.parse({v:1,kind:'receipt',scope:first.scope,operationId:first.operationId,manifestSha256:declaration(first).manifestSha256,
  jobId:'fixture-job',receiptId:'fixture-receipt',acceptedAtMs:1000,validationProfile:'fixture-bytes-v1',partCount:2,encodedBytes:6,sourceFrameCounts:[4,2]});
const examples = {notice:'Synthetic documentation fixtures only. No production receipt/codec/admission proof.',
  manifests:[first,second,third].map(m=>manifest.parse(m)),
  requests:[declaration(first),{v:1,kind:'seal',operationId:first.operationId,manifestSha256:declaration(first).manifestSha256},
    {v:1,kind:'status',operationId:first.operationId},declaration(first,'abandon')].map(r=>request.parse(r)),
  responses:[fixtureReceipt,{v:1,kind:'unknown',operationId:'absent-operation',definitiveNonacceptance:false},
    {v:1,kind:'fenced',scope:first.scope,operationId:first.operationId,manifestSha256:declaration(first).manifestSha256,
      fenceId:'fixture-fence',reason:'abandoned',acknowledgedAtMs:1000,definitiveNonacceptance:true}].map(r=>response.parse(r)),
  orderExamples:[{case:'earlier BB missing, exact T complete',expect:'T blocked by operation-1'},
    {case:'operation-1 fence acknowledged, T complete',expect:'T barrier released'},
    {case:'earlier exact T missing, later exact U complete, no unresolved BB',expect:'U independent'},
    {case:'T core submission unknown, later same T',expect:'T blocked; original operation ID, no dispatch replay'}]};
writeFileSync(new URL('../contracts/voice-terminal-v1.examples.json',import.meta.url),JSON.stringify(examples,null,2)+'\n');
