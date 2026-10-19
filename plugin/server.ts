import type { BbPluginApi } from '@get-bb/plugin-sdk';
import { z } from 'zod';
import { ControlPlane, type Authority } from './control.ts';
import { OrderLedger } from './order.ts';
import { Intake, MAX_PART_BYTES } from './intake.ts';
import { Router, CoreAttemptLedger, type JevTransport } from './routing.ts';
import { request, checkpointRequest, redeem, operatorRequest, operatorResponse, errorResponse, intakeResponse, partHeaders } from './protocol-v2.ts';
const closedAuthority:Authority={current:async()=>null,operator:async()=>null,policy:async()=>null};
async function body(req:Request,limit:number) {
  const reader=req.body?.getReader();if(!reader)return Buffer.alloc(0);
  const chunks:Uint8Array[]=[];let length=0;
  try {while(true){const item=await reader.read();if(item.done)break;length+=item.value.byteLength;if(length>limit){await reader.cancel();throw Error('limit');}chunks.push(item.value);}}finally{reader.releaseLock();}
  return Buffer.concat(chunks);
}
export function createPlugin(authority:Authority,transport?:JevTransport,now:()=>number=Date.now) {
  return (bb:BbPluginApi)=> {
    const control=new ControlPlane(bb.storage,authority,now),order=new OrderLedger(bb.storage),intake=new Intake(bb.storage,order);
    const secrets=bb.settings.define({jevApiKey:{type:'string',label:'Jev API key',secret:true}});
    const router=transport?new Router(bb.storage,control,bb.sdk,transport,async()=>(await secrets.get()).jevApiKey,now):undefined;
    const attempts=new CoreAttemptLedger(bb.storage,control,order);
    // No anonymous/operator provisioning or release HTTP route. RPC is local-auth;
    // injected operator authority STILL must authorize the concrete caller.
    bb.rpc.register({'v2.operator':{input:operatorRequest,output:z.union([operatorResponse,errorResponse])}}, {
      'v2.operator':async(input,context)=>{try{return await control.operator(input,context);}catch{return {v:2 as const,kind:'error' as const,code:'operator-action-denied'};}}
    });
    for(const [method,path] of [['POST','/v2/intake'],['PUT','/v2/part'],['POST','/v2/checkpoint'],['POST','/v2/redeem']]) {
      bb.http.route(method,path,async c=> {
        try {
          const isPart=method==='PUT';if(c.req.header('content-type')!==(isPart?'application/octet-stream':'application/json'))throw Error('invalid');
          if(path!=='/v2/redeem')await control.authorize(c.req.raw.headers);
          const bytes=await body(c.req.raw,isPart?MAX_PART_BYTES:128*1024);
          const text=isPart?'':new TextDecoder('utf-8',{fatal:true}).decode(bytes);
          if(path==='/v2/redeem')return Response.json(await control.redeem(redeem.parse(JSON.parse(text))),{headers:{'cache-control':'no-store'}});
          const g=await control.authorize(c.req.raw.headers);
          let result:unknown;
          if(isPart) {
            const op=c.req.header('x-vt-operation-id'),digest=c.req.header('x-vt-manifest-sha256'),index=c.req.header('x-vt-part-index');
            if(!op || !digest || !index || !/^(0|[1-9][0-9]*)$/.test(index))throw Error('invalid');
            const h=partHeaders.parse({v:2,operationId:op,manifestSha256:digest,partIndex:Number(index)});
            result=intake.part(g,h.operationId,h.manifestSha256,h.partIndex,bytes);
          } else if(path==='/v2/checkpoint') result=order.checkpoint(g.scope,checkpointRequest.parse(JSON.parse(text)),text);
          else result=intake.handle(g,request.parse(JSON.parse(text)));
          if(path!=='/v2/checkpoint')intakeResponse.parse(result);
          return Response.json(result,{headers:{'cache-control':'no-store'}});
        } catch(error) {
          const allowed=new Set(['unauthorized','identity-unverified','identity-mismatch','policy-unavailable','revoked','rate-limited','redemption-conflict','pairing-denied','policy-changed','wrong-epoch','invalid-checkpoint','order-gap','conflict','limit','invalid','missing-parts','unsupported-audio']);
          const code=error instanceof z.ZodError?'invalid':error instanceof Error && allowed.has(error.message)?error.message:'storage-unavailable';
          return Response.json({v:2,kind:'error',code},{status:code==='limit'?413:code==='rate-limited'?429:['storage-unavailable','identity-unverified','policy-unavailable'].includes(code)?503:['unauthorized','identity-mismatch','revoked'].includes(code)?401:409,headers:{'cache-control':'no-store'}});
        }
      },{auth:'none'});
    }
    return {control,order,intake,router,attempts};
  };
}
// Production adapters are deliberately unavailable: identity/operator auth fail closed.
export default function plugin(bb:BbPluginApi) { createPlugin(closedAuthority)(bb); }
