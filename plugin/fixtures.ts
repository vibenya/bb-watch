import { sha256 } from './intake.ts';
import type { Manifest, Scope } from './protocol.ts';
export const fixtureScope: Scope = {instanceId:'fixture-bb',accountId:'fixture-account',connectionId:'fixture-connection',deviceId:'fixture-watch'};
export const fixtureToken = 'fixture_only_not_a_credential_00000001';
export const fixtureHeaders = { 'x-vt-key-id':'fixture-key', 'x-vt-device-id':fixtureScope.deviceId, authorization:`Bearer ${fixtureToken}` };
export const audio = [Buffer.from([1,2,3,4]),Buffer.from([5,6])];
export function makeManifest(operationId = 'operation-1', sequence = 1, intent: Manifest['intent'] = {kind:'bb'}, predecessors: Manifest['order']['predecessors'] = []): Manifest {
  return {v:1,scope:fixtureScope,operationId,intent,order:{sequence,predecessors},audio:{
    parts:audio.map((b,index)=>({index,segmentId:`segment-${index}`,encoded:{encoding:'fixture-u8',bytes:b.length,sha256:sha256(b)},
      source:{sampleFormat:'fixture-u8',endian:'little',interleaved:true,sampleRateHz:index===0?16000:48000,channels:1,frames:b.length,bytes:b.length,sha256:sha256(b)}})),
    incompleteness:[{afterPartIndex:0,reason:'interruption'}]}};
}
export function declaration(m: Manifest, kind: 'declare'|'abandon' = 'declare') {
  const manifestUtf8 = JSON.stringify(m);
  return {v:1 as const,kind,manifestUtf8,manifestSha256:sha256(manifestUtf8)};
}
