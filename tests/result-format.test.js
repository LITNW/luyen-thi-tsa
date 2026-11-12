import test from 'node:test';
import assert from 'node:assert/strict';
import { answerText, formatDuration, summarizeResults } from '../src/utils/resultFormat.js';

test('formats single-choice and multi-select answers', () => {
  const content = { o: ['Alpha', 'Beta', 'Gamma'] };
  assert.equal(answerText('mc', 1, content), 'B. Beta');
  assert.equal(answerText('ms', [0, 2], content), 'A. Alpha · C. Gamma');
});

test('formats true/false and numeric answers', () => {
  assert.equal(answerText('tf', [true, false], {}), 'a) Đúng · b) Sai');
  assert.equal(answerText('num', '12.5', {}), '12,5');
});

test('formats matching answers using the slot indexes and answer-key convention', () => {
  const content = { q: 'Ghép [1] với [2]', o: ['Alpha', 'Beta'] };
  assert.equal(answerText('dnd', [1, 0], content), '[1] → B. Beta · [2] → A. Alpha');
  assert.equal(answerText('dnd', { '1': 2, '2': 1 }, content, true), '[1] → B. Beta · [2] → A. Alpha');
});

test('handles blank answers and elapsed time', () => {
  assert.equal(answerText('mc', null, { o: ['Alpha'] }), 'Bỏ trống');
  assert.equal(answerText('dnd', [null, null], { q: '[1] [2]', o: ['Alpha'] }), 'Bỏ trống');
  assert.equal(formatDuration(65), '1:05');
  assert.equal(formatDuration(0), '0:00');
});

test('summarizes correct, partial, wrong and blank results', () => {
  const rows = [
    { result: { answer: 0, is_correct: true, earned_points: 1 } },
    { result: { answer: [1], is_correct: false, earned_points: 0.5 } },
    { result: { answer: 'B', is_correct: false, earned_points: 0 } },
    { result: { answer: null, is_correct: false, earned_points: 0 } },
    { result: { answer: [null, null], is_correct: false, earned_points: 0 } },
  ];
  assert.deepEqual(summarizeResults(rows), { correct: 1, partial: 1, wrong: 1, blank: 2 });
});
