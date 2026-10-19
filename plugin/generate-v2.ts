import { writeFileSync } from 'node:fs';
import { z } from 'zod';
import * as protocol from './protocol-v2.ts';
import { makeManifest } from './fixtures.ts';
import { sha256 } from './intake.ts';
import { checkpointSeed, extendFactsHash } from './order.ts';
const names=['manifest','request','partHeaders','intakeResponse','receipt','fact','order','checkpointRef','checkpointRequest','checkpointResponse','grants','identity','operatorRequest','operatorResponse','redeem','paired','bindingOptIn','pairingTransaction','checkpointCommit','jevAnswer','computerDecision','contextEvidence'] as const;
const schema={$schema:'https://json-schema.org/draft/2020-12/schema',$id:'urn:bb:voice-terminal:2:offline-proposal',title:'Voice terminal v2 — bounded offline proposal, NOT frozen',
  $defs:Object.fromEntries(names.map(name=>[name,z.toJSONSchema(protocol[name])]))};
writeFileSync(new URL('../contracts/voice-terminal-v2.schema.json',import.meta.url),JSON.stringify(schema,null,2)+'\n');
const scope={instanceId:'fixture-instance',accountId:'fixture-account',connectionId:'fixture-connection',deviceId:'fixture-watch'},epoch='fixture-epoch';
const fact=protocol.fact.parse({sequence:1,operationId:'missing-bb',intent:{kind:'bb'}});
const request=protocol.checkpointRequest.parse({v:2,kind:'checkpoint',requestId:'checkpoint-request',epoch,base:null,facts:[fact]});
const checkpoint=protocol.checkpointRef.parse({checkpointId:'fixture-checkpoint',epoch,throughSequence:1,factsHash:extendFactsHash(checkpointSeed(scope,epoch),fact)});
const m=protocol.manifest.parse({...makeManifest(),v:2,scope,operationId:'successor',intent:{kind:'thread',threadId:'thread-U'},order:{epoch,sequence:2,checkpoint,predecessors:[]}});
const grants=protocol.grants.parse({revision:'fixture-policy',threads:[{threadId:'thread-U',projectId:'project-P'}],projects:['project-P'],allowNew:false});
const redemption=protocol.redeem.parse({v:2,kind:'redeem',requestId:'pair-request',setupCode:'012345abcdef',deviceId:scope.deviceId,tokenSha256:'1'.repeat(64)});
const examples={notice:'Synthetic DTO examples, not admission/Keychain/checkpoint receipts or runtime proof.',
  checkpointRequest:request,checkpointResponse:protocol.checkpointResponse.parse({v:2,kind:'checkpoint',scope,requestId:request.requestId,checkpoint}),
  successorManifest:m,declare:protocol.request.parse({v:2,kind:'declare',manifestUtf8:JSON.stringify(m),manifestSha256:sha256(JSON.stringify(m))}),
  redemption,paired:protocol.paired.parse({v:2,kind:'paired',scope,epoch,keyId:'fixture-key',tokenSha256:redemption.tokenSha256,requestId:redemption.requestId,grants,stagedAudioPolicy:'explicit-send-opt-in-required'}),
  pairingTransaction:protocol.pairingTransaction.parse({v:2,requestId:redemption.requestId,deviceId:scope.deviceId,keychainReference:'fixture-keychain-reference',tokenSha256:redemption.tokenSha256,tokenReadBackVerified:true,exactRequestSha256:sha256(JSON.stringify(redemption)),requestFileReference:'fixture-redemption-file'}),
  checkpointCommit:protocol.checkpointCommit.parse({v:2,scope,epoch,checkpoint,coveredSequence:1,exactRequestSha256:sha256(JSON.stringify(request)),requestId:request.requestId,localLedgerRetained:true}),
  stagedOptIn:protocol.bindingOptIn.parse({v:2,kind:'staged-send-opt-in',scope,epoch,stagedIds:['staged-audio-1'],confirmed:true}),
  forbidden:[{case:'checkpoint ack lost',action:'retry exact durable file/requestId; retain full local facts until ack committed'},
    {case:'Keychain inaccessible',action:'freeze same transaction; never mint a replacement token'},
    {case:'early BB unresolved',action:'all possible lanes remain blocked despite checkpoint'},
    {case:'early BB resolved T but core unknown',action:'T blocked; known U independent'},
    {case:'explicit operator release of unknown',action:'order release only; original attempt stays reconcile-only'}]};
writeFileSync(new URL('../contracts/voice-terminal-v2.examples.json',import.meta.url),JSON.stringify(examples,null,2)+'\n');
