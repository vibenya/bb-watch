import { z } from 'zod';
import { writeFileSync } from 'node:fs';
import { manifest, request, partHeaders, response, pairing, threadSnapshot, dispatchFact } from './protocol.ts';
const definitions = { manifest, request, partHeaders, response, pairing, threadSnapshot, dispatchFact };
const schema = { $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'urn:bb:voice-terminal:1:phase0-proposal', title: 'Voice terminal v1 — Phase 0 proposal, not frozen',
  $defs: Object.fromEntries(Object.entries(definitions).map(([k,v]) => [k,z.toJSONSchema(v)])) };
writeFileSync(new URL('../contracts/voice-terminal-v1.schema.json', import.meta.url), JSON.stringify(schema, null, 2) + '\n');
