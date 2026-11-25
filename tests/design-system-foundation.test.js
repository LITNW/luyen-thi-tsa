import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const tokens = readFileSync(new URL('../public/lit-design-tokens.css', import.meta.url), 'utf8');
const reactEntry = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const legacyEntry = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
const reactStyles = readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8');

function token(name) {
  const match = tokens.match(new RegExp(`${name}:\\s*(#[0-9a-fA-F]{6})`));
  assert.ok(match, `missing color token ${name}`);
  return match[1];
}

function luminance(hex) {
  const rgb = hex.slice(1).match(/.{2}/g).map((pair) => parseInt(pair, 16) / 255);
  const linear = rgb.map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4);
  return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}

function contrastRatio(foreground, background) {
  const first = luminance(foreground);
  const second = luminance(background);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

test('shared design tokens are loaded by React and made available to Legacy', () => {
  assert.match(reactEntry, /href="\/lit-design-tokens\.css"/);
  assert.match(legacyEntry, /href="\/lit-design-tokens\.css"/);
  assert.match(tokens, /--lit-token-color-canvas:\s*#080d18/i);
});

test('semantic text and status colors meet 4.5:1 on every defined dark surface', () => {
  const surfaces = ['--lit-token-color-canvas', '--lit-token-color-surface', '--lit-token-color-raised'];
  const foregrounds = ['--lit-token-color-text', '--lit-token-color-text-secondary', '--lit-token-color-accent'];
  for (const foreground of foregrounds) {
    for (const background of surfaces) {
      assert.ok(contrastRatio(token(foreground), token(background)) >= 4.5, `${foreground} on ${background} must meet 4.5:1`);
    }
  }
  for (const foreground of ['--lit-token-color-success', '--lit-token-color-warning', '--lit-token-color-danger']) {
    assert.ok(contrastRatio(token(foreground), token('--lit-token-color-surface')) >= 4.5, `${foreground} on surface must meet 4.5:1`);
  }
});

test('essential control borders meet 3:1 against every dark surface', () => {
  const border = token('--lit-token-color-border-strong');
  for (const background of ['--lit-token-color-canvas', '--lit-token-color-surface', '--lit-token-color-raised']) {
    assert.ok(contrastRatio(border, token(background)) >= 3, `strong border on ${background} must meet 3:1`);
  }
});

test('focus indicator meets non-text contrast against every dark surface', () => {
  const focus = token('--lit-token-color-focus');
  for (const background of ['--lit-token-color-canvas', '--lit-token-color-surface', '--lit-token-color-raised']) {
    assert.ok(contrastRatio(focus, token(background)) >= 3, `focus indicator on ${background} must meet 3:1`);
  }
});

test('accent button text is dark ink; white normal-size text on accent is rejected', () => {
  const accent = token('--lit-token-color-accent');
  const ink = token('--lit-token-color-accent-ink');
  assert.ok(contrastRatio(ink, accent) >= 4.5);
  assert.ok(contrastRatio('#ffffff', accent) < 4.5);
  assert.ok(tokens.includes('.lit-action--primary'));
  assert.ok(tokens.includes('color: var(--lit-token-color-accent-ink)'));
});

test('focus, selected, disabled, error and loading foundation states are defined', () => {
  assert.ok(tokens.includes(':focus-visible'));
  assert.ok(tokens.includes('.lit-selectable[aria-pressed="true"]'));
  assert.ok(tokens.includes('.lit-action:disabled'));
  assert.ok(tokens.includes('.lit-field[aria-invalid="true"]'));
  assert.ok(tokens.includes('.lit-loading'));
  assert.ok(tokens.includes('.lit-action:hover:not(:disabled)'));
  assert.ok(legacyEntry.includes('.exam-question-card .o:focus-visible,.exam-shell button:focus-visible{outline:var(--lit-token-focus-width) solid var(--lit-token-color-focus)'));
  assert.ok(reactStyles.includes('button:disabled { cursor: not-allowed; border-style: dashed; }'));
});

test('typography specimens include Vietnamese body and mathematical content', () => {
  for (const specimen of [
    '.lit-type-home-title',
    '.lit-type-dashboard-metric',
    '.lit-type-exam-title',
    '.lit-type-admin-table',
    '.lit-type-body-vi',
    '.lit-type-math',
  ]) {
    assert.ok(tokens.includes(specimen), `missing typography specimen ${specimen}`);
  }
  assert.ok(tokens.includes('--lit-token-font-math'));
  assert.ok(tokens.includes('overflow-wrap: anywhere'));
});
