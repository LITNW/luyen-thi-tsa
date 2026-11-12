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
