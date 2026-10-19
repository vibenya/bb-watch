import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { PluginBbSdk, PluginStorage } from '@get-bb/plugin-sdk';
import { ControlPlane } from './control.ts';
import { openStore } from './store.ts';
import { requireCondition as need, OrderLedger } from './order.ts';
import { manifest, jevAnswer, computerDecision } from './protocol-v2.ts';
import type { Scope } from './protocol.ts';
import { sha256 } from './intake.ts';

const exactAnswer=z.strictObject({conflict:z.boolean(),confidence:z.number().min(0).max(1)});
export type Candidate={threadId:string;projectId:string;providerId:string;updatedAtMs:number;title:string;
  execution:NonNullable<Awaited<ReturnType<PluginBbSdk['threads']['defaultExecutionOptions']>>>;
  messages:{seq:number;createdAtMs:number;role:string;text:string}[]};
export interface JevTransport {
  choose(data:{transcript:string;candidates:Candidate[];catalog:{providerId:string;model:string}[]},secret:string):Promise<unknown>;
  assessExact(data:{transcript:string;target:Candidate},secret:string):Promise<unknown>;
}
export type Decision=z.infer<typeof computerDecision>;
// Provisional fixture policy; no claim of production confidence/latency calibration.
const LIMITS={candidates:4,messages:2,messageChars:1024,transcriptChars:6000,maxAgeMs:300000,futureSkewMs:5000,confidence:0.9};
export class Router {
  private db:ReturnType<typeof openStore>;
  private running=new Map<string,Promise<Decision>>();
  constructor(storage:PluginStorage,privateControl:ControlPlane,sdk:PluginBbSdk,transport:JevTransport,secret:()=>Promise<string|undefined>,now:()=>number=Date.now) {
    this.db=openStore(storage);this.control=privateControl;this.sdk=sdk;this.transport=transport;this.secret=secret;this.now=now;
  }
  private control:ControlPlane;private sdk:PluginBbSdk;private transport:JevTransport;private secret:()=>Promise<string|undefined>;private now:()=>number;
  async decide(scope:Scope,operationId:string,transcript:string):Promise<Decision> {
    const key=JSON.stringify([scope,operationId]);
    const old=this.running.get(key);if(old)return old;
    const task=this.run(scope,operationId,transcript);this.running.set(key,task);
    try{return await task;}finally{this.running.delete(key);}
  }
  private async run(scope:Scope,operationId:string,transcript:string):Promise<Decision> {
    const authorized=await this.control.checkedScope(scope);
    const existing=this.db.prepare('SELECT decision_json FROM route_decisions WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId) as {decision_json:string}|undefined;
    if(existing) {
      const d=computerDecision.parse(JSON.parse(existing.decision_json));
      if(d.kind==='existing' && (d.policyRevision!==authorized.grants.revision || !authorized.grants.threads.some(t=>t.threadId===d.threadId && t.projectId===d.projectId)))return {...d,kind:'hold',reason:'authorization-changed'};
      return d;
    }
    const row=this.db.prepare('SELECT manifest_json,result_json FROM intake WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId) as {manifest_json:string;result_json:string|null}|undefined;
    need(row?.result_json && JSON.parse(row.result_json).kind==='receipt','audio-not-received');
    const frozen=manifest.parse(JSON.parse(row.manifest_json));
    let result:Decision={v:2,scope,operationId,kind:'hold',reason:'context-unavailable',confidence:null,evidenceRevision:sha256('no-context'),contextEvidence:[],policyRevision:authorized.grants.revision,observedAtMs:this.now()};
    try {
      need(transcript.length>0 && transcript.length<=LIMITS.transcriptChars,'transcript-limit');
      const frozenIntent=frozen.intent;
      const allowed=frozenIntent.kind==='thread'?authorized.grants.threads.filter(t=>t.threadId===frozenIntent.threadId):authorized.grants.threads.slice(0,LIMITS.candidates);
      need(allowed.length>0,'target-unavailable');
      const candidates:Candidate[]=[];
      for(const grant of allowed) {
        const thread=await this.sdk.threads.get({threadId:grant.threadId});
        need(thread.id===grant.threadId && thread.projectId===grant.projectId && !thread.deletedAt && !thread.archivedAt,'invalid-candidate');
        need((thread.title??'').length<=128,'context-limit');
        need(thread.updatedAt<=this.now()+LIMITS.futureSkewMs && this.now()-thread.updatedAt<=LIMITS.maxAgeMs,'stale-context');
        const execution=await this.sdk.threads.defaultExecutionOptions({threadId:thread.id});need(execution,'execution-unavailable');
        const events=await this.sdk.threads.events.list({threadId:thread.id,order:'desc',limit:String(LIMITS.messages),types:['system/manager/user_message','item/completed']});
        need(events.length<=LIMITS.messages,'context-limit');
        const messages:Candidate['messages']=[];
        for(const event of events) {
          need(event.threadId===thread.id && event.createdAt<=this.now()+LIMITS.futureSkewMs && this.now()-event.createdAt<=LIMITS.maxAgeMs,'stale-context');
          const original=await this.sdk.threads.message({threadId:thread.id,seq:event.seq,before:0,after:0});
          need(original.message.threadId===thread.id && original.message.kind==='conversation','invalid-message');
          need(original.message.createdAt<=this.now()+LIMITS.futureSkewMs && this.now()-original.message.createdAt<=LIMITS.maxAgeMs,'stale-context');
          need(original.message.text.length<=LIMITS.messageChars,'context-limit');
          messages.push({seq:original.message.sourceSeqEnd,createdAtMs:original.message.createdAt,role:original.message.role,text:original.message.text});
        }
        candidates.push({threadId:thread.id,projectId:thread.projectId,providerId:thread.providerId,updatedAtMs:thread.updatedAt,title:thread.title??'',execution,messages});
      }
      const catalogs=new Map<string,Awaited<ReturnType<PluginBbSdk['system']['executionOptions']>>>();
      const catalog:{providerId:string;model:string}[]=[];
      for(const candidate of candidates) {
        if(!catalogs.has(candidate.providerId))catalogs.set(candidate.providerId,await this.sdk.system.executionOptions({providerId:candidate.providerId}));
        const c=catalogs.get(candidate.providerId)!;need(!c.modelLoadError,'catalog-unavailable');
        need(c.providers.some(p=>p.id===candidate.providerId && p.available),'provider-unavailable');
        need(c.models.some(m=>m.model===candidate.execution.model && (!m.routeProviderId || m.routeProviderId===candidate.providerId)),'invalid-model');
        if(!catalog.some(m=>m.providerId===candidate.providerId && m.model===candidate.execution.model))catalog.push({providerId:candidate.providerId,model:candidate.execution.model});
      }
      result.contextEvidence=candidates.map(c=>({threadId:c.threadId,updatedAtMs:c.updatedAtMs,messages:c.messages.map(m=>({seq:m.seq,createdAtMs:m.createdAtMs,textSha256:sha256(m.text)}))}));
      result.evidenceRevision=sha256(JSON.stringify({manifest:sha256(row.manifest_json),transcriptSha256:sha256(transcript),policy:authorized.grants.revision,candidates,catalog}));
      const key=await this.secret();need(key,'jev-not-configured');
      let chosen:Candidate|undefined;
      if(frozen.intent.kind==='thread') {
        const assessed=exactAnswer.parse(await this.transport.assessExact({transcript,target:candidates[0]},key));
        result.confidence=assessed.confidence;need(!assessed.conflict,'spoken-conflict');need(assessed.confidence>=LIMITS.confidence,'low-confidence');chosen=candidates[0];
      } else {
        const answer=jevAnswer.parse(await this.transport.choose({transcript,candidates,catalog},key));
        need(answer.kind!=='hold','ambiguous');
        result.confidence=answer.confidence;need(!answer.spokenConflict,'spoken-conflict');need(answer.confidence>=LIMITS.confidence,'low-confidence');
        need(authorized.grants.projects.includes(answer.projectId),'invalid-project');
        need(catalog.some(m=>m.providerId===answer.execution.providerId && m.model===answer.execution.model),'invalid-model');
        need(answer.kind!=='new','new-creation-policy-pending');
        chosen=candidates.find(c=>c.threadId===answer.threadId && c.projectId===answer.projectId);
        need(chosen && chosen.providerId===answer.execution.providerId && chosen.execution.model===answer.execution.model,'invalid-target-or-execution');
      }
      need(chosen && catalog.some(m=>m.providerId===chosen.providerId && m.model===chosen.execution.model),'invalid-model');
      const latest=await this.control.checkedScope(scope);need(JSON.stringify(latest.grants)===JSON.stringify(authorized.grants),'policy-changed');
      result={...result,kind:'existing',reason:undefined,threadId:chosen.threadId,projectId:chosen.projectId,execution:{...chosen.execution,providerId:chosen.providerId}};
    } catch(error) {
      const known=new Set(['transcript-limit','target-unavailable','invalid-candidate','stale-context','execution-unavailable','context-limit','invalid-message','catalog-unavailable','provider-unavailable','jev-not-configured','spoken-conflict','low-confidence','ambiguous','invalid-project','invalid-model','new-creation-policy-pending','invalid-target-or-execution','policy-changed']);
      result={...result,kind:'hold',reason:error instanceof Error && known.has(error.message)?error.message:'adapter-failed'};
    }
    this.db.prepare('INSERT OR IGNORE INTO route_decisions VALUES (?,?,?)').run(scope.connectionId,operationId,JSON.stringify(computerDecision.parse(result)));
    return computerDecision.parse(JSON.parse((this.db.prepare('SELECT decision_json FROM route_decisions WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId) as {decision_json:string}).decision_json));
  }
}
export class CoreAttemptLedger {
  private db:ReturnType<typeof openStore>;private control:ControlPlane;private order:OrderLedger;
  constructor(storage:PluginStorage,control:ControlPlane,order:OrderLedger) {
    this.db=openStore(storage);this.control=control;this.order=order;
    this.db.prepare("UPDATE core_attempts SET state='unknown' WHERE state='attempting'").run();
  }
  async reserve(scope:Scope,operationId:string) {
    const current=await this.control.checkedScope(scope);
    return this.db.transaction(()=> {
      const old=this.db.prepare('SELECT * FROM core_attempts WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId);
      if(old)return {kind:'reconcile-only',fact:old};
      need(!this.db.prepare('SELECT 1 FROM order_releases WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId),'released-no-replay');
      const row=this.db.prepare('SELECT decision_json FROM route_decisions WHERE connection_id=? AND operation_id=?').get(scope.connectionId,operationId) as {decision_json:string}|undefined;
      const decision=row?computerDecision.parse(JSON.parse(row.decision_json)):null;
      need(decision?.kind==='existing','route-held');
      need(decision.policyRevision===current.grants.revision && current.grants.threads.some(t=>t.threadId===decision.threadId && t.projectId===decision.projectId),'authorization-changed');
      need(this.order.barriers(scope,operationId).length===0,'order-blocked');
      const attemptId=randomUUID();this.db.prepare("INSERT INTO core_attempts VALUES (?,?,?,'attempting',NULL)").run(scope.connectionId,operationId,attemptId);
      return {kind:'attempt-recorded-no-core-call',attemptId};
    }).immediate();
  }
}
