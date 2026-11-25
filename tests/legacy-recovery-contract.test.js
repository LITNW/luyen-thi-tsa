import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');

test('a browser reload restores the latest active attempt for the signed-in user', () => {
  assert.match(html, /if\(!me&&await restoreActiveAttempt\(user\.id\)\)return;/);
  assert.match(html, /async function restoreActiveAttempt\(userId\)/);
  assert.match(html, /get_my_attempt_state/);
  assert.match(html, /state\?\.status==='submitted'[\s\S]*?clearAttemptCache/);
});

test('an Admin opening the Legacy workspace does not restore a student exam session', () => {
  assert.match(html, /if\(!me&&await restoreActiveAttempt\(user\.id\)\)return;/);
  assert.match(html, /profile=p;me=p\.role==='admin'&&p\.status==='active';[\s\S]*?if\(!me&&await restoreActiveAttempt\(user\.id\)\)return;/);
});

test('switching accounts detaches the prior editor or exam context but keeps its attempt cache', () => {
  const refreshData = html.match(/async function refreshData\(user\)\{([\s\S]*?)\n    \}/)?.[1] || '';
  const detachContext = html.match(/function detachAccountContext\(previousUserId\)\{([\s\S]*?)\n    \}/)?.[1] || '';
  assert.match(refreshData, /const previousUserId=profile\?\.id/);
  assert.match(refreshData, /previousUserId&&previousUserId!==p\.id\)detachAccountContext\(previousUserId\)/);
  assert.match(detachContext, /lap\(activeAttempt\);persistAttempt\(activeAttempt\)/);
  assert.match(detachContext, /clearInterval\(T\);T=null/);
  assert.match(detachContext, /view=\{n:'home'\}/);
  assert.doesNotMatch(detachContext, /clearAttemptCache/);
});

test('startup offline recovery is limited to a verified active student profile', () => {
  const refreshData = html.match(/async function refreshData\(user\)\{([\s\S]*?)\n    \}/)?.[1] || '';
  assert.doesNotMatch(refreshData, /if\(pe\|\|!p\)\{if\(restoreOfflineAttempt/);
  assert.match(refreshData, /if\(ee\)\{D\.exams=\[\];if\(!me&&restoreOfflineAttempt\(user\.id\)\)return;/);
});

test('true/false statements render as compact independent radio groups', () => {
  assert.match(html, /<table class="tf-matrix"[\s\S]*?<th scope="col">Phát biểu<\/th>[\s\S]*?<th scope="col">ĐÚNG<\/th>[\s\S]*?<th scope="col">SAI<\/th>/);
  assert.match(html, /name="tf-'\+esc\(a\.qids\[a\.cur\]\)\+'-'\+i\+'/);
  assert.match(html, /type="radio"[\s\S]*?aria-label="Ý '\+\('abcd'\[i\]\)\+'\: Đúng"[\s\S]*?data-a="tf"/);
  assert.match(html, /type="radio"[\s\S]*?aria-label="Ý '\+\('abcd'\[i\]\)\+'\: Sai"[\s\S]*?data-a="tf"/);
});

test('a learner can exit an exam without submitting or discarding saved answers', () => {
  assert.match(html, /data-a="exitExam"/);
  assert.match(html, /đáp án[\s\S]*?không nộp bài[\s\S]*?thời gian vẫn tiếp tục/i);
  assert.match(html, /else if\(k==='confirmExit'\)[\s\S]*?view=\{n:'home'\}/);
  assert.doesNotMatch(html, /confirmExit[\s\S]{0,500}finish\(/);
});

test('Admin draft preview is a local, non-attempt context with a direct exit back to the editor', () => {
  assert.match(html, /data-a="previewDraft"/);
  assert.match(html, /async function previewDraft\(/);
  assert.match(html, /preview:true/);
  assert.match(html, /else if\(k==='exitPreview'\)[\s\S]*?view\.previewReturn/);
  assert.match(html, /a\.preview\?[\s\S]*?data-a="exitPreview"/);
  assert.doesNotMatch(html, /function previewDraft\([\s\S]{0,1600}start_exam_attempt/);
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
