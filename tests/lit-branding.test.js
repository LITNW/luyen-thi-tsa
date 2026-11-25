import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('public root route renders a public landing page for signed-out visitors', () => {
  const app = read('../src/App.jsx');
  assert.match(app, /import PublicLandingPage from ['"]\.\/pages\/PublicLandingPage\.jsx['"]/);
  assert.match(app, /return session \? <RouteGuard><DashboardPage \/><\/RouteGuard> : <PublicLandingPage \/>/);
});

test('LIT landing page exposes explicit login and registration routes without bypassing auth', () => {
  const landing = read('../src/pages/PublicLandingPage.jsx');
  assert.match(landing, /to=["']\/login["']/);
  assert.match(landing, /to=["']\/register["']/);
  assert.match(landing, /LIT/);
  assert.match(landing, /Learn|Practice|Grow/);
});

test('shared authenticated shell and public auth screens use repository-managed LIT logo assets', () => {
  const shell = read('../src/components/AppShell.jsx');
  const auth = read('../src/pages/AuthPage.jsx');
  for (const source of [shell, auth]) {
    assert.match(source, /\/brand\/lit-horizontal\.svg/);
  }
});

test('React shell theme is scoped and does not replace legacy exam runtime styling', () => {
  const css = read('../src/lit-theme.css');
  assert.match(css, /\.app-shell/);
  assert.match(css, /\.auth-layout/);
  assert.match(css, /\.lit-landing/);
  assert.doesNotMatch(css, /(^|\n)body\s*\{/);
});
