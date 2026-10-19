import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { PluginStorage } from '@get-bb/plugin-sdk';
import { openStore, type Store } from './store.ts';
import { checkpointRequest, type CheckpointRef, type Manifest, type Fact } from './protocol-v2.ts';
import type { Scope } from './protocol.ts';
import { createHash } from 'node:crypto';
const digest = (s:string)=>createHash('sha256').update(s).digest('hex');
export const checkpointSeed=(scope:Scope,epoch:string)=>digest(JSON.stringify([2,scope.instanceId,scope.accountId,scope.connectionId,scope.deviceId,epoch]));
export const extendFactsHash=(prior:string,f:Fact)=>digest(JSON.stringify([prior,f.sequence,f.operationId,f.intent.kind,f.intent.kind==='thread'?f.intent.threadId:null]));
export function sameScope(a:Scope,b:Scope) { return a.instanceId===b.instanceId && a.accountId===b.accountId && a.connectionId===b.connectionId && a.deviceId===b.deviceId; }
export function requireCondition(ok:unknown, code='conflict'): asserts ok { if (!ok) throw new Error(code); }
export class OrderLedger {
  db: Store;
  constructor(storage:PluginStorage) {this.db=openStore(storage);}
  connection(scope:Scope) {
    const row=this.db.prepare('SELECT * FROM connections WHERE connection_id=? AND active=1').get(scope.connectionId) as {scope_json:string;epoch:string;grants_json:string}|undefined;
    requireCondition(row && sameScope(JSON.parse(row.scope_json),scope),'unauthorized');return row;
  }
  private base(scope:Scope,epoch:string,ref:CheckpointRef|null) {
    requireCondition(this.connection(scope).epoch===epoch,'wrong-epoch');
    if (!ref) return {through:0,hash:checkpointSeed(scope,epoch)};
    const row=this.db.prepare('SELECT * FROM checkpoints WHERE checkpoint_id=?').get(ref.checkpointId) as {connection_id:string;epoch:string;through_sequence:number;facts_hash:string}|undefined;
    requireCondition(row && row.connection_id===scope.connectionId && row.epoch===epoch && ref.epoch===epoch && row.through_sequence===ref.throughSequence && row.facts_hash===ref.factsHash,'invalid-checkpoint');
    return {through:row.through_sequence,hash:row.facts_hash};
  }
  private facts(scope:Scope,epoch:string,start:number,facts:Fact[]) {
    let expected=start;
    for (const f of facts) {
      requireCondition(f.sequence===++expected,'order-gap');
      const rows=this.db.prepare('SELECT * FROM order_facts WHERE connection_id=? AND (sequence=? OR operation_id=?)').all(scope.connectionId,f.sequence,f.operationId) as {sequence:number;operation_id:string;intent_json:string;epoch:string}[];
      requireCondition(rows.every(r=>r.epoch===epoch && r.sequence===f.sequence && r.operation_id===f.operationId && r.intent_json===JSON.stringify(f.intent)));
      this.db.prepare('INSERT OR IGNORE INTO order_facts VALUES (?,?,?,?,?)').run(scope.connectionId,epoch,f.sequence,f.operationId,JSON.stringify(f.intent));
    }
  }
  register(m:Manifest) {
    const b=this.base(m.scope,m.order.epoch,m.order.checkpoint);
    requireCondition(m.order.sequence===b.through+m.order.predecessors.length+1,'order-gap');
    this.facts(m.scope,m.order.epoch,b.through,[...m.order.predecessors,{operationId:m.operationId,sequence:m.order.sequence,intent:m.intent}]);
  }
  checkpoint(scope:Scope,input:z.infer<typeof checkpointRequest>, requestUtf8:string) {
    return this.db.transaction(()=> {
      const b=this.base(scope,input.epoch,input.base);
      const requestHash=digest(requestUtf8);
      const old=this.db.prepare('SELECT * FROM checkpoint_requests WHERE connection_id=? AND request_id=?').get(scope.connectionId,input.requestId) as {request_hash:string;response_json:string}|undefined;
      if(old) {requireCondition(old.request_hash===requestHash);return JSON.parse(old.response_json);}
      this.facts(scope,input.epoch,b.through,input.facts);
      let factsHash=b.hash;
      for(const f of input.facts) factsHash=extendFactsHash(factsHash,f);
      const through=b.through+input.facts.length;
      this.db.prepare('INSERT OR IGNORE INTO checkpoints VALUES (?,?,?,?,?)').run(randomUUID(),scope.connectionId,input.epoch,through,factsHash);
      const row=this.db.prepare('SELECT * FROM checkpoints WHERE connection_id=? AND epoch=? AND through_sequence=?').get(scope.connectionId,input.epoch,through) as {checkpoint_id:string;facts_hash:string};
      requireCondition(row.facts_hash===factsHash);
      const result={v:2,kind:'checkpoint',scope,requestId:input.requestId,checkpoint:{checkpointId:row.checkpoint_id,epoch:input.epoch,throughSequence:through,factsHash}};
      this.db.prepare('INSERT INTO checkpoint_requests VALUES (?,?,?,?)').run(scope.connectionId,input.requestId,requestHash,JSON.stringify(result));return result;
    }).immediate();
  }
  barriers(scope:Scope,operationId:string) {
    const current=this.db.prepare('SELECT * FROM order_facts WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId) as {sequence:number;intent_json:string}|undefined;
    if(!current) return ['unknown-operation'];
    const destination=(op:string,intent:string):string|null=> {
      const i=JSON.parse(intent);if(i.kind==='thread') return i.threadId;
      const d=this.db.prepare('SELECT decision_json FROM route_decisions WHERE connection_id=? AND operation_id=?').get(scope.connectionId,op) as {decision_json:string}|undefined;
      const decision=d?JSON.parse(d.decision_json):null;return decision?.kind==='existing'?decision.threadId:null;
    };
    const target=destination(operationId,current.intent_json);if(!target)return ['unresolved-route'];
    const predecessors=this.db.prepare('SELECT * FROM order_facts WHERE connection_id=? AND sequence<? ORDER BY sequence').all(scope.connectionId,current.sequence) as {operation_id:string;intent_json:string}[];
    return predecessors.filter(p=> {
      if(this.db.prepare('SELECT 1 FROM order_releases WHERE connection_id=? AND operation_id=?').get(scope.connectionId,p.operation_id))return false;
      const result=this.db.prepare('SELECT result_json FROM intake WHERE connection_id=? AND operation_id=?').get(scope.connectionId,p.operation_id) as {result_json:string|null}|undefined;
      if(result?.result_json && JSON.parse(result.result_json).kind==='fenced')return false;
      const lane=destination(p.operation_id,p.intent_json);if(lane && lane!==target)return false;
      const attempt=this.db.prepare('SELECT state FROM core_attempts WHERE connection_id=? AND operation_id=?').get(scope.connectionId,p.operation_id) as {state:string}|undefined;
      return attempt?.state!=='accepted';
    }).map(p=>p.operation_id);
  }
}
