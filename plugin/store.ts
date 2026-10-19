import type { PluginStorage } from '@get-bb/plugin-sdk';
// First five migration statements are the unchanged v1 fixture migrations.
const migrations = [
  `CREATE TABLE credentials (key_id TEXT PRIMARY KEY, token_hash TEXT NOT NULL,
       scope_json TEXT NOT NULL, allowed_threads_json TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)`,
  `CREATE TABLE ledger (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, sequence INTEGER NOT NULL,
       intent_json TEXT NOT NULL, PRIMARY KEY(connection_id,operation_id), UNIQUE(connection_id,sequence))`,
  `CREATE TABLE intake (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, manifest_hash TEXT NOT NULL,
       manifest_json TEXT NOT NULL, result_json TEXT, PRIMARY KEY(connection_id,operation_id))`,
  `CREATE TABLE parts (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, part_index INTEGER NOT NULL,
       bytes BLOB NOT NULL, PRIMARY KEY(connection_id,operation_id,part_index))`,
  `CREATE TABLE jobs (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, job_id TEXT NOT NULL UNIQUE,
       dispatch_state TEXT NOT NULL DEFAULT 'not-attempted', PRIMARY KEY(connection_id,operation_id))`,
  `CREATE TABLE connections (connection_id TEXT PRIMARY KEY, scope_json TEXT NOT NULL, epoch TEXT NOT NULL, active INTEGER NOT NULL, grants_json TEXT NOT NULL)`,
  `CREATE TABLE order_facts (connection_id TEXT NOT NULL, epoch TEXT NOT NULL, sequence INTEGER NOT NULL, operation_id TEXT NOT NULL, intent_json TEXT NOT NULL, PRIMARY KEY(connection_id,epoch,sequence), UNIQUE(connection_id,operation_id))`,
  `CREATE TABLE checkpoints (checkpoint_id TEXT PRIMARY KEY, connection_id TEXT NOT NULL, epoch TEXT NOT NULL, through_sequence INTEGER NOT NULL, facts_hash TEXT NOT NULL, UNIQUE(connection_id,epoch,through_sequence))`,
  `CREATE TABLE checkpoint_requests (connection_id TEXT NOT NULL, request_id TEXT NOT NULL, request_hash TEXT NOT NULL, response_json TEXT NOT NULL, PRIMARY KEY(connection_id,request_id))`,
  `CREATE TABLE pair_codes (code_hash TEXT PRIMARY KEY, request_id TEXT NOT NULL UNIQUE, request_hash TEXT NOT NULL, identity_json TEXT NOT NULL, connection_id TEXT, grants_json TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0)`,
  `CREATE TABLE redemptions (request_id TEXT PRIMARY KEY, request_hash TEXT NOT NULL, result_json TEXT NOT NULL)`,
  `CREATE TABLE rate_buckets (bucket TEXT PRIMARY KEY, attempts INTEGER NOT NULL)`,
  `CREATE TABLE order_releases (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, release_json TEXT NOT NULL, PRIMARY KEY(connection_id,operation_id))`,
  `CREATE TABLE route_decisions (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, decision_json TEXT NOT NULL, PRIMARY KEY(connection_id,operation_id))`,
  `CREATE TABLE core_attempts (connection_id TEXT NOT NULL, operation_id TEXT NOT NULL, attempt_id TEXT NOT NULL, state TEXT NOT NULL, core_reference TEXT, PRIMARY KEY(connection_id,operation_id))`,
];
export function openStore(storage: PluginStorage) {
  const db = storage.database();
  db.pragma('journal_mode = WAL'); db.pragma('synchronous = FULL');
  storage.migrate(db,migrations);
  return db;
}
export type Store = ReturnType<typeof openStore>;
