import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createFakePluginHost, experimental_scanPublicSdkOnly } from '@get-bb/plugin-sdk/testing';
import plugin from './server.ts';
import { Intake, sha256 } from './intake.ts';
import { response } from './protocol.ts';
import { audio, fixtureScope, fixtureToken, fixtureHeaders, makeManifest, declaration } from './fixtures.ts';

async function setup() {
  let host = createFakePluginHost({pluginId:'voice-terminal'});
  plugin(host.bb);
  const db = host.bb.storage.database();
  db.prepare('INSERT INTO credentials VALUES (?,?,?,?,0)').run('fixture-key',sha256(fixtureToken),JSON.stringify(fixtureScope),JSON.stringify(['thread-T','thread-U']));
  const call = async (input: unknown, headers: Record<string,string> = fixtureHeaders) => {
    const r = await host.harness.behavior.fetchHttp('POST','/v1/intake',{headers:{'content-type':'application/json',...headers},body:JSON.stringify(input)});
    return {status:r.status,body:response.parse(await r.json())};
  };
  const part = async (m: ReturnType<typeof makeManifest>, index:number, bytes = audio[index]) => {
    const r = await host.harness.behavior.fetchHttp('PUT','/v1/part',{headers:{...fixtureHeaders,'content-type':'application/octet-stream','x-vt-operation-id':m.operationId,'x-vt-manifest-sha256':declaration(m).manifestSha256,'x-vt-part-index':String(index)},body:bytes});
    return response.parse(await r.json());
  };
  const seal = (m: ReturnType<typeof makeManifest>) => call({v:1,kind:'seal',operationId:m.operationId,manifestSha256:declaration(m).manifestSha256});
  return {get host(){return host;},db,call,part,seal,reload:async()=>{host = await host.harness.lifecycle.reload(plugin);}};
}
const status = (op:string) => ({v:1,kind:'status',operationId:op});

test('HTTP boundary denies missing/wrong/revoked keys and isolates scopes without leaking receipt', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const m = makeManifest(); await s.call(declaration(m));
  for (const headers of [{}, {...fixtureHeaders,'x-vt-device-id':'wrong-device'}, {...fixtureHeaders,authorization:'Bearer wrong_token_0000000000000000000000000'}]) {
    assert.deepEqual(await s.call(status(m.operationId),headers),{status:401,body:{v:1,kind:'error',code:'unauthorized'}});
  }
  const other = {...fixtureScope,connectionId:'other-connection',deviceId:'other-watch',accountId:'other-account'};
  s.db.prepare('INSERT INTO credentials VALUES (?,?,?,?,0)').run('other-key',sha256(fixtureToken),JSON.stringify(other),'[]');
  const headers = {...fixtureHeaders,'x-vt-key-id':'other-key','x-vt-device-id':'other-watch'};
  assert.equal((await s.call(status(m.operationId),headers)).body.kind,'unknown');
  assert.deepEqual((await s.call(declaration(m),headers)).body,{v:1,kind:'error',code:'unauthorized'});
  s.db.prepare('UPDATE credentials SET revoked=1 WHERE key_id=?').run('fixture-key');
  assert.equal((await s.call(status(m.operationId))).status,401);
  assert.equal((s.db.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,0);
});

test('complete immutable intake survives lost response, duplicate/out-of-order part, concurrent seal and SDK reload', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const m = makeManifest();
  assert.equal((await s.call(declaration(m))).body.kind,'receiving');
  assert.equal((await s.seal(m)).body.kind,'error');
  assert.equal((await s.part(m,1)).kind,'receiving'); await s.part(m,1);
  assert.deepEqual(await s.part(m,0,Buffer.from('bad')),{v:1,kind:'error',code:'invalid'});
  await s.part(m,0);
  const [a,b] = await Promise.all([s.seal(m),s.seal(m)]);
  assert.equal(a.body.kind,'receipt'); assert.deepEqual(a,b);
  if (a.body.kind !== 'receipt') throw Error();
  assert.equal(a.body.validationProfile,'fixture-bytes-v1'); assert.deepEqual(a.body.sourceFrameCounts,[4,2]);
  assert.equal((s.db.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,1);
  await s.reload();
  assert.deepEqual((await s.call(status(m.operationId))).body,a.body);
  assert.deepEqual((await s.call(declaration(m,'abandon'))).body,a.body);
  assert.deepEqual((await s.seal(m)).body,a.body);
  const reopened = s.host.bb.storage.database();
  assert.equal((reopened.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,1);
  assert.deepEqual(reopened.prepare('SELECT bytes FROM parts ORDER BY part_index').all().map((r:any)=>r.bytes),audio);
  const stored = JSON.parse((reopened.prepare('SELECT manifest_json FROM intake').get() as {manifest_json:string}).manifest_json);
  assert.deepEqual(stored.audio,m.audio);
  assert.equal(s.host.harness.inspection.sdk.calls.length,0);
  assert.equal(s.host.harness.logEntries.length,0);
});

test('fence wins before late seal, target denial is durably nonaccepted, status unknown is not a fence', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const m = makeManifest();
  assert.deepEqual((await s.call(status(m.operationId))).body,{v:1,kind:'unknown',operationId:m.operationId,definitiveNonacceptance:false});
  const fence = (await s.call(declaration(m,'abandon'))).body;
  assert.equal(fence.kind,'fenced');
  await s.reload();
  assert.deepEqual((await s.call(declaration(m))).body,fence);
  assert.deepEqual(await s.part(m,0),fence);
  assert.deepEqual((await s.seal(m)).body,fence);
  const denied = makeManifest('denied',2,{kind:'thread',threadId:'deleted-thread'},[{operationId:m.operationId,sequence:1,intent:m.intent}]);
  const rejection = (await s.call(declaration(denied))).body;
  assert.equal(rejection.kind,'fenced');
  if (rejection.kind !== 'fenced') throw Error();
  assert.equal(rejection.reason,'target-unavailable'); assert.equal(rejection.definitiveNonacceptance,true);
  assert.deepEqual((await s.seal(denied)).body,rejection);
  assert.equal((s.host.bb.storage.database().prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,0);
});

test('identity conflict, malformed order and source layout cannot rewrite accepted intent or open a job', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const m = makeManifest(); await s.call(declaration(m));
  const changed = {...m,intent:{kind:'thread' as const,threadId:'thread-T'}};
  assert.deepEqual((await s.call(declaration(changed))).body,{v:1,kind:'error',code:'conflict'});
  for (const broken of [makeManifest('missing-prev',2), {...m,notificationContext:'forbidden'}, {...m,audio:{...m.audio,parts:[{...m.audio.parts[0],source:{...m.audio.parts[0].source,frames:9}}]}}]) {
    const input = {...declaration(m),manifestUtf8:JSON.stringify(broken),manifestSha256:sha256(JSON.stringify(broken))};
    assert.deepEqual((await s.call(input)).body,{v:1,kind:'error',code:'invalid'});
  }
  const dup = makeManifest('duplicate-seq',1);
  assert.equal((await s.call(declaration(dup))).body.kind,'error');
  assert.equal((s.db.prepare('SELECT count(*) n FROM intake').get() as {n:number}).n,1);
  const candidate = makeManifest('candidate',2,{kind:'thread',threadId:'thread-U'},[{operationId:m.operationId,sequence:1,intent:m.intent}]);
  candidate.audio.parts.forEach(p=>p.encoded.encoding='aac-lc-m4a-candidate');
  await s.call(declaration(candidate)); await s.part(candidate,0); await s.part(candidate,1);
  assert.deepEqual((await s.seal(candidate)).body,{v:1,kind:'error',code:'unsupported-audio'});
  assert.equal((s.db.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,0);
});

test('never-received BB predecessor blocks exact target; acknowledged fence releases, independent exact lanes do not wait', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const earlier = makeManifest();
  const later = makeManifest('later',2,{kind:'thread',threadId:'thread-T'},[{operationId:earlier.operationId,sequence:1,intent:earlier.intent}]);
  await s.call(declaration(later)); await s.part(later,0); await s.part(later,1); await s.seal(later);
  const i = new Intake(s.host.bb.storage); const grant = i.authorize(new Headers(fixtureHeaders));
  assert.deepEqual(i.barriers(grant,later.operationId),[earlier.operationId]);
  await s.call(declaration(earlier,'abandon'));
  assert.deepEqual(i.barriers(grant,later.operationId),[]);
  const independent = makeManifest('independent',3,{kind:'thread',threadId:'thread-U'},[...later.order.predecessors,{operationId:later.operationId,sequence:2,intent:later.intent}]);
  await s.call(declaration(independent));
  assert.deepEqual(i.barriers(grant,independent.operationId),[]);
  const same = makeManifest('same-lane',4,{kind:'thread',threadId:'thread-T'},[...independent.order.predecessors,{operationId:independent.operationId,sequence:3,intent:independent.intent}]);
  await s.call(declaration(same)); assert.deepEqual(i.barriers(grant,same.operationId),[later.operationId]);
  s.db.prepare("UPDATE jobs SET dispatch_state='unknown' WHERE operation_id=?").run(later.operationId);
  assert.deepEqual(i.barriers(grant,same.operationId),[later.operationId]);
  assert.equal(s.host.harness.inspection.sdk.calls.length,0);
});

test('committed source, receipt and fence survive separate process exit/reopen; interrupted transaction cannot fabricate receipt', ()=> {
  const dir = mkdtempSync(join(tmpdir(),'voice-terminal-proof-'));
  try {
    for (const phase of ['write','read']) {
      const r = spawnSync(process.execPath,['--experimental-strip-types','./restart-fixture.ts',join(dir,'fixture.db'),phase],{cwd:import.meta.dirname,encoding:'utf8'});
      assert.equal(r.status,0,r.stderr || r.stdout);
      assert.match(r.stdout,/PASS/);
    }
  } finally { rmSync(dir,{recursive:true,force:true}); }
});

test('job write failure returns no receipt and preserves original identity and bytes for same-ID retry', async t=> {
  const s = await setup(); t.after(()=>s.host.harness.lifecycle.dispose());
  const m = makeManifest(); await s.call(declaration(m)); await s.part(m,0); await s.part(m,1);
  s.db.exec("CREATE TRIGGER fixture_disk_failure BEFORE INSERT ON jobs BEGIN SELECT RAISE(ABORT, 'fixture disk failure'); END");
  assert.deepEqual(await s.seal(m),{status:503,body:{v:1,kind:'error',code:'storage-unavailable'}});
  assert.equal((await s.call(status(m.operationId))).body.kind,'receiving');
  assert.equal((s.db.prepare('SELECT count(*) n FROM jobs').get() as {n:number}).n,0);
  s.db.exec('DROP TRIGGER fixture_disk_failure');
  assert.equal((await s.seal(m)).body.kind,'receipt');
  assert.deepEqual(s.db.prepare('SELECT bytes FROM parts ORDER BY part_index').all().map((r:any)=>r.bytes),audio);
});

test('only public SDK imports and declared local dependencies are used', async()=> {
  const result = await experimental_scanPublicSdkOnly(import.meta.dirname, {allow:[/^better-sqlite3$/, /^@get-bb\/plugin-sdk\/testing$/]});
  assert.deepEqual(result.violations,[]); assert.deepEqual(result.privateDependencies,[]);
});
