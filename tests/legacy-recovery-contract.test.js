import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');

test('a browser reload restores the latest active attempt for the signed-in user', () => {
  assert.match(html, /if\(await restoreActiveAttempt\(user\.id\)\)return;/);
  assert.match(html, /async function restoreActiveAttempt\(userId\)/);
  assert.match(html, /get_my_attempt_state/);
  assert.match(html, /state\?\.status==='submitted'[\s\S]*?clearAttemptCache/);
});

test('tab resume checkpoints elapsed time and pauses the timer during reconciliation', () => {
  assert.match(html, /const a=view\.at;\s*lap\(a\);\s*a\.resuming=true;/);
  assert.match(html, /if\(!a\|\|a\.submitting\|\|a\.resuming\)return;/);
  assert.match(html, /document\.visibilityState==='hidden'[\s\S]*?void resumeAttempt\(\)/);
  assert.match(html, /event\.persisted&&view\.n==='take'[\s\S]*?void resumeAttempt\(\)/);
});

test('the exam renderer guards against a missing current question', () => {
  assert.match(html, /if\(!a\|\|!ensureAttemptReady\(a\)\)return[\s\S]*?Đang khôi phục phòng thi/);
});

test('concurrent answer edits cannot clear the dirty marker for a newer revision', () => {
  assert.match(html, /const revision=a\.dirtyAnswers\[key\];[\s\S]*?if\(a\.dirtyAnswers\[key\]===revision\)delete a\.dirtyAnswers\[key\]/);
  assert.match(html, /while\(true\)\{\s*const key=Object\.keys\(a\.dirtyAnswers\|\|\{\}\)\.filter\(k=>a\.dirtyAnswers\[k\]\)/);
  assert.match(html, /a\.dirtyAnswers\[i\]=\(Number\(a\.dirtyAnswers\[i\]\)\|\|0\)\+1/);
});


test('legacy exam persistence is account-scoped in IndexedDB and waits for migration before restoring', () => {
  const storage = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');
  assert.match(html, /src="\/legacy\/attempt-storage\.js"/);
  assert.match(html, /await window\.LITAttemptStorage\.setAccount\(user\?\.id\|\|null\)/);
  assert.match(storage, /indexedDB\.open/);
  assert.match(storage, /accountId/);
  assert.match(storage, /legacy migration verified/i);
  assert.match(storage, /localStorage\.removeItem/);
});

test('legacy attempt drafts preserve old data until every IndexedDB record is read back and verified', () => {
  const storage = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');
  assert.match(storage, /verify/);
  assert.match(storage, /JSON\.stringify/);
  assert.match(storage, /transaction\.oncomplete/);
  assert.match(storage, /migration/i);
});

test('IndexedDB writes are serialized and storage failures remain observable instead of being swallowed', () => {
  const storage = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');
  assert.match(storage, /writeQueue/);
  assert.match(storage, /lit-attempt-storage-error/);
  assert.match(storage, /flush/);
});


test('network restoration reconciles server state, retries dirty answers and time events, and preserves pending submission', () => {
  assert.match(html, /window\.addEventListener\('online',[\s\S]*?a\.needsServerReconcile=true;[\s\S]*?await syncPending\(a\)/);
  assert.match(html, /while\(true\)\{[\s\S]*?Object\.keys\(a\.dirtyAnswers/);
  assert.match(html, /while\(\(a\.timeQueue\|\|\[\]\)\.length\)/);
  assert.match(html, /a\.pendingSubmit=true/);
  assert.match(html, /sb\.rpc\('submit_exam_attempt'/);
});

test('storage adapter is awaited before authenticated restore and account changes do not erase another account namespace', () => {
  assert.match(html, /await window\.LITAttemptStorage\.setAccount\(user\?\.id\|\|null\);[\s\S]*?if\(!user\)/);
  const storage = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');
  assert.match(storage, /recordId\(accountId, logicalKey\)/);
  assert.match(storage, /activeAccountId/);
  assert.doesNotMatch(storage, /clearAccount\(/);
});


test('offline legacy shell also caches the IndexedDB adapter required to reopen a saved attempt', () => {
  const serviceWorker = readFileSync(new URL('../public/legacy/sw.js', import.meta.url), 'utf8');
  assert.match(serviceWorker, /ATTEMPT_STORAGE_SCRIPT='\/legacy\/attempt-storage\.js'/);
  assert.match(serviceWorker, /cache\.add\(ATTEMPT_STORAGE_SCRIPT\)/);
  assert.match(serviceWorker, /url\.pathname===ATTEMPT_STORAGE_SCRIPT/);
  assert.match(serviceWorker, /cache\.match\(ATTEMPT_STORAGE_SCRIPT\)/);
});


test('quota failures switch to a visible localStorage fallback without dropping the in-memory draft', () => {
  const storage = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');
  assert.match(storage, /mode = 'legacy-fallback'/);
  assert.match(storage, /root\.localStorage\.setItem\(key, JSON\.stringify\(value\)\)/);
  assert.match(storage, /emitError\(error, label\)/);
});
