import type { BbPluginApi } from '@get-bb/plugin-sdk';
import { Intake, MAX_PART_BYTES, errorBody } from './intake.ts';
import { request, response, partHeaders } from './protocol.ts';

async function boundedBody(req: Request, limit: number): Promise<Uint8Array> {
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const item = await reader.read();
      if (item.done) break;
      length += item.value.byteLength;
      if (length > limit) { await reader.cancel(); throw new Error('body-limit'); }
      chunks.push(item.value);
    }
  } finally { reader.releaseLock(); }
  return Buffer.concat(chunks);
}
export default function plugin(bb: BbPluginApi) {
  const intake = new Intake(bb.storage);
  for (const [method,path] of [['POST','/v1/intake'],['PUT','/v1/part']]) {
    bb.http.route(method,path,async c=> {
      let result;
      try {
        intake.authorize(c.req.raw.headers);
        if (method === 'POST') {
          if (c.req.header('content-type') !== 'application/json') throw new SyntaxError();
          const text = new TextDecoder('utf-8', {fatal:true}).decode(await boundedBody(c.req.raw, 128*1024));
          result = intake.handle(intake.authorize(c.req.raw.headers),request.parse(JSON.parse(text)));
        } else {
          if (c.req.header('content-type') !== 'application/octet-stream') throw new SyntaxError();
          const index = c.req.header('x-vt-part-index');
          if (!index || !/^(0|[1-9][0-9]*)$/.test(index)) throw new SyntaxError();
          const h = partHeaders.parse({v:1,operationId:c.req.header('x-vt-operation-id'),manifestSha256:c.req.header('x-vt-manifest-sha256'),partIndex:Number(index)});
          const bytes = await boundedBody(c.req.raw,MAX_PART_BYTES);
          result = intake.part(intake.authorize(c.req.raw.headers),h.operationId,h.manifestSha256,h.partIndex,bytes);
        }
      } catch (error) {
        result = (error as Error)?.message === 'body-limit' ? {v:1,kind:'error',code:'limit'} as const : errorBody(error);
      }
      const parsed = response.parse(result);
      const status = parsed.kind !== 'error' ? 200 : parsed.code === 'unauthorized' ? 401 : parsed.code === 'storage-unavailable' ? 503 : parsed.code === 'limit' ? 413 : 409;
      return new Response(JSON.stringify(parsed),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
    }, {auth:'none'}); // All admission here is per-watch; remote host admission is UNPROVEN.
  }
}
