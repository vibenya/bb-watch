// OS-process persistence fixture; no real BB server, Keychain or native app.
import Database from 'better-sqlite3';
import assert from 'node:assert/strict';
import { readFileSync,writeFileSync } from 'node:fs';
import { createFakePluginHost } from '@get-bb/plugin-sdk/testing';
import { createPlugin } from './server.ts';
import { currentIdentity,approved,operatorCaller,deviceToken,v2Manifest,declareV2 } from './integration-fixtures.ts';
import { sha256 } from './intake.ts';
const [path,phase]=process.argv.slice(2),db=new Database(path);
const host=createFakePluginHost({pluginId:'voice-terminal'});
const app=createPlugin({current:async()=>currentIdentity,policy:async()=>approved,operator:async c=>c.experimental_caller.kind==='plugin' && c.experimental_caller.pluginId==='fixture-operator'?{actorId:'fixture-operator'}:null},undefined,()=>phase==='write'?10000:100000)({...host.bb,storage:{...host.bb.storage,database:()=>db}});
const post=async(path:string,text:string,headers:Record<string,string>={})=>{
  const r=await host.harness.behavior.fetchHttp('POST',path,{headers:{'content-type':'application/json',...headers},body:text});return r.json() as Promise<any>;
};
if(phase==='write') {
  const issued=await host.harness.behavior.callRpc('v2.operator',{v:2,kind:'issue-code',requestId:'issue',repairConnectionId:null},operatorCaller) as any;
  const redemptionUtf8=JSON.stringify({v:2,kind:'redeem',requestId:'redeem',setupCode:issued.setupCode,deviceId:'fixture-watch',tokenSha256:sha256(deviceToken)});
  const pair=await post('/v2/redeem',redemptionUtf8);assert.equal(pair.kind,'paired');
  const headers={'x-vt-key-id':pair.keyId,'x-vt-device-id':pair.scope.deviceId,authorization:`Bearer ${deviceToken}`};
  const requestUtf8=JSON.stringify({v:2,kind:'checkpoint',requestId:'checkpoint',epoch:pair.epoch,base:null,facts:[{operationId:'missing-bb',sequence:1,intent:{kind:'bb'}}]});
  const ack=await post('/v2/checkpoint',requestUtf8,headers);assert.equal(ack.kind,'checkpoint');
  // Synthetic client record: covered sequence + ack saved together; source ledger retained.
  writeFileSync(`${path}.client.json`,JSON.stringify({pair,redemptionUtf8,requestUtf8,ack,coveredSequence:1,localOperations:['missing-bb'],keychainReference:'fixture-readback-reference'}));
  await host.harness.lifecycle.dispose();
  db.exec("BEGIN IMMEDIATE; INSERT INTO checkpoints VALUES ('uncommitted','ghost','ghost',99,'ghost')");
  console.log('PASS v2 committed checkpoint/redemption; client record persisted; interrupted transaction');process.exit(0);
} else {
  const client=JSON.parse(readFileSync(`${path}.client.json`,'utf8'));const pair=client.pair;
  const headers={'x-vt-key-id':pair.keyId,'x-vt-device-id':pair.scope.deviceId,authorization:`Bearer ${deviceToken}`};
  assert.deepEqual(await post('/v2/redeem',client.redemptionUtf8),pair); // already redeemed, now expired
  assert.deepEqual(await post('/v2/checkpoint',client.requestUtf8,headers),client.ack);
  assert.deepEqual(client.localOperations,['missing-bb']);
  const next=v2Manifest(pair,'successor',2,{kind:'thread',threadId:'thread-U'},client.ack.checkpoint);
  assert.equal((await post('/v2/intake',JSON.stringify(declareV2(next)),headers)).kind,'receiving');
  assert.deepEqual(app.order.barriers(pair.scope,'successor'),['missing-bb']);
  assert.equal(db.prepare("SELECT 1 FROM checkpoints WHERE checkpoint_id='uncommitted'").get(),undefined);
  assert.equal((db.prepare('SELECT count(*) n FROM credentials').get() as any).n,1);
  assert.equal(host.harness.inspection.sdk.calls.length,0);
  await host.harness.lifecycle.dispose();db.close();console.log('PASS v2 process reopen, exact retries, no remint/release, crash rollback');
}
