#!/usr/bin/env node
// One-time backfill: give every fund_transactions row without a
// `referenceNumber` a sequential TXN-xxxxx number, oldest first.
//
//   node scripts/backfill_fund_transaction_refs.mjs --project xloop-tours-dev            # dry run
//   node scripts/backfill_fund_transaction_refs.mjs --project xloop-tours-dev --apply    # write
//
// Auth: uses `gcloud auth print-access-token` (Firestore REST API).
// Safe to re-run: only unnumbered rows are touched, and the number range is
// claimed on counters/fund_transaction_reference first (with an updateTime
// precondition), so it can never collide with numbers the app hands out.

import { execSync } from 'node:child_process';

const args = process.argv.slice(2);
const project = args[args.indexOf('--project') + 1];
const apply = args.includes('--apply');
if (!args.includes('--project') || !project || project.startsWith('--')) {
  console.error('Usage: --project <firebase-project-id> [--apply]');
  process.exit(1);
}

const token = execSync('gcloud auth print-access-token').toString().trim();
const root = `projects/${project}/databases/(default)/documents`;
const api = `https://firestore.googleapis.com/v1/${root}`;
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const COUNTER = 'counters/fund_transaction_reference';
const START = 10000; // first number issued is TXN-10001, same base as the app

async function call(url, init = {}) {
  const res = await fetch(url, { headers, ...init });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(body)}`);
  return body;
}

const str = (f) => f?.stringValue ?? f?.timestampValue ?? null;
const ms = (f) => {
  const s = str(f);
  const t = s ? Date.parse(s) : NaN;
  return Number.isNaN(t) ? Number.MAX_SAFE_INTEGER : t;
};

// 1. Load every ledger row (only the fields we need).
const rows = [];
let pageToken;
do {
  const q = new URLSearchParams({ pageSize: '300' });
  for (const f of ['createdAt', 'date', 'description', 'referenceNumber']) {
    q.append('mask.fieldPaths', f);
  }
  if (pageToken) q.set('pageToken', pageToken);
  const page = await call(`${api}/fund_transactions?${q}`);
  for (const d of page.documents ?? []) {
    const f = d.fields ?? {};
    rows.push({
      name: d.name,
      id: d.name.split('/').pop(),
      createdAt: ms(f.createdAt ?? f.date),
      description: str(f.description) ?? '',
      referenceNumber: str(f.referenceNumber),
    });
  }
  pageToken = page.nextPageToken;
} while (pageToken);

const todo = rows
  .filter((r) => !r.referenceNumber)
  .sort(
    (a, b) =>
      a.createdAt - b.createdAt ||
      // transfer pairs share a timestamp: the "out" leg comes first
      Number(b.description.startsWith('Transfer out')) -
        Number(a.description.startsWith('Transfer out')) ||
      a.id.localeCompare(b.id),
  );

// 2. Current counter.
let counterValue = START;
let counterUpdateTime = null;
try {
  const c = await call(`${api}/${COUNTER}`);
  counterValue = Number(c.fields?.value?.integerValue ?? START);
  counterUpdateTime = c.updateTime;
} catch (e) {
  if (!String(e.message).startsWith('404')) throw e;
}

console.log(`Project:            ${project}`);
console.log(`Ledger rows:        ${rows.length}`);
console.log(`Already numbered:   ${rows.length - todo.length}`);
console.log(`To number:          ${todo.length}`);
console.log(`Counter now:        ${counterUpdateTime ? counterValue : '(missing)'}`);
if (todo.length === 0) process.exit(0);

const assigned = todo.map((r, i) => ({ ...r, ref: `TXN-${counterValue + i + 1}` }));
const preview = assigned.length > 10 ? [...assigned.slice(0, 5), null, ...assigned.slice(-5)] : assigned;
for (const r of preview) {
  if (!r) { console.log('  ...'); continue; }
  console.log(`  ${r.ref}  ${new Date(r.createdAt).toISOString()}  ${r.id}  ${r.description.slice(0, 50)}`);
}
console.log(`Counter after:      ${counterValue + todo.length}`);

if (!apply) {
  console.log('\nDry run only. Re-run with --apply to write.');
  process.exit(0);
}

// 3. Claim the range on the counter (fails if the app issued a number meanwhile).
await call(`${api}:commit`, {
  method: 'POST',
  body: JSON.stringify({
    writes: [
      {
        update: { name: `${root}/${COUNTER}`, fields: { value: { integerValue: String(counterValue + todo.length) } } },
        updateMask: { fieldPaths: ['value'] },
        currentDocument: counterUpdateTime ? { updateTime: counterUpdateTime } : { exists: false },
      },
    ],
  }),
});

// 4. Stamp the rows, 400 writes per commit.
for (let i = 0; i < assigned.length; i += 400) {
  const chunk = assigned.slice(i, i + 400);
  await call(`${api}:commit`, {
    method: 'POST',
    body: JSON.stringify({
      writes: chunk.map((r) => ({
        update: { name: r.name, fields: { referenceNumber: { stringValue: r.ref } } },
        updateMask: { fieldPaths: ['referenceNumber'] },
        currentDocument: { exists: true },
      })),
    }),
  });
  console.log(`Wrote ${Math.min(i + 400, assigned.length)}/${assigned.length}`);
}
console.log('Done.');
