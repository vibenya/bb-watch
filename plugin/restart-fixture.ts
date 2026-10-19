// Separate-process storage fixture, NOT a loaded BB server or remote admission.
import Database from 'better-sqlite3';
import assert from 'node:assert/strict';
import { createFakePluginHost } from '@get-bb/plugin-sdk/testing';
import plugin from './v1-fixture-server.ts';
import { sha256 } from './intake.ts';
import { audio, fixtureScope, fixtureToken, fixtureHeaders, makeManifest, declaration } from './fixtures.ts';
const [path,phase] = process.argv.slice(2);
const db = new Database(path);
const host = createFakePluginHost({pluginId:'voice-terminal'});
plugin({...host.bb,storage:{...host.bb.storage,database:()=>db}});
const call = async (body:unknown) => {
  const r = await host.harness.behavior.fetchHttp('POST','/v1/intake',{headers:{...fixtureHeaders,'content-type':'application/json'},body:JSON.stringify(body)});
  return r.json() as Promise<any>;
};
const m = makeManifest();
const missing = makeManifest('abandoned',2,{kind:'bb'},[{operationId:m.operationId,sequence:1,intent:m.intent}]);
if (phase === 'write') {
  db.prepare('INSERT INTO credentials VALUES (?,?,?,?,0)').run('fixture-key',sha256(fixtureToken),JSON.stringify(fixtureScope),'[]');
  await call(declaration(m));
  for (const [index,bytes] of audio.entries()) {
    await host.harness.behavior.fetchHttp('PUT','/v1/part',{headers:{...fixtureHeaders,'content-type':'application/octet-stream','x-vt-operation-id':m.operationId,'x-vt-manifest-sha256':declaration(m).manifestSha256,'x-vt-part-index':String(index)},body:bytes});
  }
  const receipt = await call({v:1,kind:'seal',operationId:m.operationId,manifestSha256:declaration(m).manifestSha256});
  assert.equal(receipt.kind,'receipt');
  assert.equal((await call(declaration(missing,'abandon'))).kind,'fenced');
  await host.harness.lifecycle.dispose(); // clean SDK temp fixture, external DB remains open
  db.exec("BEGIN IMMEDIATE; INSERT INTO jobs VALUES ('fixture-connection','ghost','ghost-job','not-attempted')");
  console.log('PASS committed receipt/fence, exit mid-uncommitted transaction');
  process.exit(0); // intentionally no database close: next process must recover SQLite WAL
} else {
  const receipt = await call({v:1,kind:'status',operationId:m.operationId});
  assert.equal(receipt.kind,'receipt');
  assert.equal((db.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,1);
  assert.deepEqual(db.prepare('SELECT bytes FROM parts ORDER BY part_index').all().map((r:any)=>r.bytes),audio);
  assert.equal((await call({v:1,kind:'seal',operationId:missing.operationId,manifestSha256:declaration(missing).manifestSha256})).kind,'fenced');
  assert.deepEqual(await call({v:1,kind:'seal',operationId:m.operationId,manifestSha256:declaration(m).manifestSha256}),receipt);
  assert.equal(host.harness.inspection.sdk.calls.length,0);
  await host.harness.lifecycle.dispose(); db.close();
  console.log('PASS reopened bytes/receipt/fence, uncommitted ghost rolled back');
}
