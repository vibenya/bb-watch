import { randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import type { ExperimentalPluginRpcHandlerContext, PluginStorage } from '@get-bb/plugin-sdk';
import { z } from 'zod';
import { openStore } from './store.ts';
import { sameScope, requireCondition as need } from './order.ts';
import { scope, type Scope } from './protocol.ts';
import { grants, identity, paired, redeem, operatorRequest, type Grants, type Identity } from './protocol-v2.ts';
import { sha256 } from './intake.ts';
export interface Authority {
  current(): Promise<Identity|null>;
  operator(context:ExperimentalPluginRpcHandlerContext): Promise<{actorId:string}|null>;
  policy(scope:Scope): Promise<Grants|null>;
}
export class ControlPlane {
  db:ReturnType<typeof openStore>;
  constructor(storage:PluginStorage, privateAuthority:Authority, now:()=>number=Date.now) {
    this.db=openStore(storage);this.authority=privateAuthority;this.now=now;
  }
  private authority:Authority; private now:()=>number;
  async current() { const value=await this.authority.current();need(value,'identity-unverified');return identity.parse(value); }
  async checkedScope(s:Scope) {
    const current=await this.current();need(s.instanceId===current.instanceId && s.accountId===current.accountId,'identity-mismatch');
    const row=this.db.prepare('SELECT * FROM connections WHERE connection_id=? AND active=1').get(s.connectionId) as {scope_json:string;epoch:string;grants_json:string}|undefined;
    need(row && sameScope(scope.parse(JSON.parse(row.scope_json)),s),'unauthorized');
    const policy=await this.authority.policy(s);need(policy,'policy-unavailable');
    const finalIdentity=await this.current();need(JSON.stringify(finalIdentity)===JSON.stringify(current),'identity-mismatch');
    need(this.db.prepare('SELECT 1 FROM connections WHERE connection_id=? AND active=1 AND epoch=?').get(s.connectionId,row.epoch),'unauthorized');
    const approved=grants.parse(policy), enrolled=grants.parse(JSON.parse(row.grants_json));
    return {scope:s,epoch:row.epoch,grants:{...approved,allowNew:approved.allowNew && enrolled.allowNew,
      projects:approved.projects.filter(p=>enrolled.projects.includes(p)),
      threads:approved.threads.filter(t=>enrolled.threads.some(e=>e.threadId===t.threadId && e.projectId===t.projectId) && approved.projects.includes(t.projectId) && enrolled.projects.includes(t.projectId))}};
  }
  async authorize(headers:Headers) {
    const token=headers.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{32,256})$/)?.[1];
    const row=this.db.prepare('SELECT * FROM credentials WHERE key_id=? AND revoked=0').get(headers.get('x-vt-key-id')) as {token_hash:string;scope_json:string}|undefined;
    need(token && row && /^[a-f0-9]{64}$/.test(row.token_hash) && timingSafeEqual(Buffer.from(sha256(token),'hex'),Buffer.from(row.token_hash,'hex')),'unauthorized');
    const s=scope.parse(JSON.parse(row.scope_json));need(s.deviceId===headers.get('x-vt-device-id'),'unauthorized');
    const verified=await this.checkedScope(s);
    // Recheck after async identity/policy work; revocation cannot cross the read window.
    need(this.db.prepare('SELECT 1 FROM credentials WHERE key_id=? AND token_hash=? AND revoked=0').get(headers.get('x-vt-key-id'),sha256(token)),'unauthorized');
    return {...verified,allowedThreads:verified.grants.threads.map(t=>t.threadId)};
  }
  async operator(input:z.infer<typeof operatorRequest>, context:ExperimentalPluginRpcHandlerContext) {
    const actor=await this.authority.operator(context);need(actor,'operator-required');
    const current=await this.current();
    if(input.kind==='issue-code') {
      let repair:Scope|null=null;
      if(input.repairConnectionId) {
        const row=this.db.prepare('SELECT scope_json FROM connections WHERE connection_id=? AND active=1').get(input.repairConnectionId) as {scope_json:string}|undefined;
        need(row,'unauthorized');repair=scope.parse(JSON.parse(row.scope_json));await this.checkedScope(repair);
      }
      const pendingScope=repair??{instanceId:current.instanceId,accountId:current.accountId,connectionId:randomUUID(),deviceId:'pending-device'};
      const policy=await this.authority.policy(pendingScope);need(policy,'policy-unavailable');
      const approved=grants.parse(policy);const requestHash=sha256(JSON.stringify([input,current]));
      // Code itself is derived from an ephemeral return value and never stored raw.
      // An operator losing this reply must issue a NEW request/code; old code expires.
      const code=randomBytes(6).toString('hex');
      return this.db.transaction(()=> {
        need(!this.db.prepare('SELECT 1 FROM pair_codes WHERE request_id=?').get(input.requestId),'issue-reply-lost-reissue-explicitly');
        const expiresAtMs=this.now()+60000;
        this.db.prepare('INSERT INTO pair_codes (code_hash,request_id,request_hash,identity_json,connection_id,grants_json,expires_at) VALUES (?,?,?,?,?,?,?)').run(sha256(code),input.requestId,requestHash,JSON.stringify(current),repair?.connectionId??null,JSON.stringify(approved),expiresAtMs);
        return {v:2,kind:'pairing-code',requestId:input.requestId,setupCode:code,expiresAtMs};
      }).immediate();
    }
    await this.checkedScope(input.scope);
    return this.db.transaction(()=> {
      if(input.kind==='revoke') {
        this.db.prepare('UPDATE credentials SET revoked=1 WHERE scope_json=?').run(JSON.stringify(input.scope));
        this.db.prepare('UPDATE connections SET active=0 WHERE connection_id=?').run(input.scope.connectionId);
        return {v:2,kind:'revoked',scope:input.scope,requestId:input.requestId};
      }
      need(this.db.prepare('SELECT 1 FROM order_facts WHERE connection_id=? AND operation_id=?').get(input.scope.connectionId,input.operationId),'unknown-operation');
      const old=this.db.prepare('SELECT release_json FROM order_releases WHERE connection_id=? AND operation_id=?').get(input.scope.connectionId,input.operationId) as {release_json:string}|undefined;
      if(old) return JSON.parse(old.release_json).response;
      const result={v:2,kind:'order-released',requestId:input.requestId,scope:input.scope,operationId:input.operationId,releaseId:randomUUID(),reason:input.reason,confirmed:true};
      this.db.prepare('INSERT INTO order_releases VALUES (?,?,?)').run(input.scope.connectionId,input.operationId,JSON.stringify({response:result,actorId:actor.actorId,atMs:this.now()}));return result;
    }).immediate();
  }
  async redeem(input:z.infer<typeof redeem>) {
    const current=await this.current();
    const codeHash=sha256(input.setupCode),requestHash=sha256(JSON.stringify(input));
    const previous=this.db.prepare('SELECT * FROM redemptions WHERE request_id=?').get(input.requestId) as {request_hash:string;result_json:string}|undefined;
    if(previous?.request_hash===requestHash) {
      const result=paired.parse(JSON.parse(previous.result_json));await this.checkedScope(result.scope);
      need(this.db.prepare('SELECT 1 FROM credentials WHERE key_id=? AND revoked=0').get(result.keyId),'revoked');return result;
    }
    // Only NEW/contradictory attempts consume the budget; exact persisted retries
    // reconcile after expiry without minting anything or becoming a TTL bypass.
    const bucket=`${current.instanceId}:${Math.floor(this.now()/60000)}`;
    const budget=this.db.transaction(()=> {
      this.db.prepare('INSERT INTO rate_buckets VALUES (?,1) ON CONFLICT(bucket) DO UPDATE SET attempts=attempts+1').run(bucket);
      return (this.db.prepare('SELECT attempts FROM rate_buckets WHERE bucket=?').get(bucket) as {attempts:number}).attempts<=20;
    }).immediate();need(budget,'rate-limited');need(!previous,'redemption-conflict');
    const row=this.db.prepare('SELECT * FROM pair_codes WHERE code_hash=?').get(codeHash) as {identity_json:string;connection_id:string|null;grants_json:string;expires_at:number;attempts:number;used:number}|undefined;
    need(row && row.used===0 && row.attempts<5 && row.expires_at>this.now() && JSON.stringify(current)===row.identity_json,'pairing-denied');
    this.db.prepare('UPDATE pair_codes SET attempts=attempts+1 WHERE code_hash=?').run(codeHash);
    let s:Scope;
    let epoch:string=randomUUID();
    if(row.connection_id) {
      const existing=this.db.prepare('SELECT * FROM connections WHERE connection_id=? AND active=1').get(row.connection_id) as {scope_json:string;epoch:string}|undefined;
      need(existing,'unauthorized');s=scope.parse(JSON.parse(existing.scope_json));need(s.deviceId===input.deviceId,'pairing-denied');epoch=existing.epoch;
    } else s={instanceId:current.instanceId,accountId:current.accountId,connectionId:randomUUID(),deviceId:input.deviceId};
    const policy=await this.authority.policy(s);need(policy,'policy-unavailable');
    const issued=grants.parse(JSON.parse(row.grants_json)),active=grants.parse(policy);
    need(JSON.stringify(issued)===JSON.stringify(active),'policy-changed');
    const finalIdentity=await this.current();need(JSON.stringify(finalIdentity)===JSON.stringify(current),'identity-mismatch');
    const effective=row.connection_id?(await this.checkedScope(s)).grants:active;
    return this.db.transaction(()=> {
      const concurrent=this.db.prepare('SELECT * FROM redemptions WHERE request_id=?').get(input.requestId) as {request_hash:string;result_json:string}|undefined;
      if(concurrent) {need(concurrent.request_hash===requestHash,'redemption-conflict');return paired.parse(JSON.parse(concurrent.result_json));}
      // Async policy lookup may overlap another redemption; compare-and-set code consumption.
      need(this.db.prepare('UPDATE pair_codes SET used=1 WHERE code_hash=? AND used=0 AND expires_at>?').run(codeHash,this.now()).changes===1,'pairing-denied');
      if(row.connection_id) this.db.prepare('UPDATE credentials SET revoked=1 WHERE scope_json=?').run(JSON.stringify(s));
      else this.db.prepare('INSERT INTO connections VALUES (?,?,?,1,?)').run(s.connectionId,JSON.stringify(s),epoch,JSON.stringify(active));
      const keyId=randomUUID();
      this.db.prepare('INSERT INTO credentials VALUES (?,?,?,?,0)').run(keyId,input.tokenSha256,JSON.stringify(s),JSON.stringify(active.threads.map(t=>t.threadId)));
      const result=paired.parse({v:2,kind:'paired',scope:s,keyId,tokenSha256:input.tokenSha256,epoch,grants:effective,requestId:input.requestId,stagedAudioPolicy:'explicit-send-opt-in-required'});
      this.db.prepare('INSERT INTO redemptions VALUES (?,?,?)').run(input.requestId,requestHash,JSON.stringify(result));return result;
    }).immediate();
  }
}
