import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

 test('PostHog preparation does not ship an analytics runtime or SDK', () => {
  const packageJson = JSON.parse(read('../package.json'));
  assert.equal(packageJson.dependencies['posthog-js'], undefined);
  assert.equal(existsSync(new URL('../src/lib/analytics.js', import.meta.url)), false);
  assert.equal(existsSync(new URL('../src/legacy-analytics.js', import.meta.url)), false);
  assert.doesNotMatch(read('../src/main.jsx'), /initializeAnalytics|posthog-js/);
  assert.doesNotMatch(read('../src/App.jsx'), /trackPageView|trackEvent/);
  assert.doesNotMatch(read('../src/context/AuthContext.jsx'), /trackEvent|analytics\.js/);
  assert.doesNotMatch(read('../src/pages/DashboardPage.jsx'), /trackEvent|analytics\.js/);
  assert.doesNotMatch(read('../vite.config.js'), /legacyAnalytics|legacy-analytics/);
  assert.doesNotMatch(read('../scripts/generate-legacy-config.js'), /legacy-analytics|posthog/i);
  assert.doesNotMatch(read('../public/legacy/index.html'), /posthog|legacy_exam_(start|submit)/i);
});

test('the sample environment keeps PostHog disabled without provider configuration', () => {
  const example = read('../.env.example');
  assert.match(example, /^VITE_POSTHOG_ENABLED=false$/m);
  assert.doesNotMatch(example, /VITE_POSTHOG_(PROJECT_TOKEN|HOST|ENVIRONMENT)/);
});

test('PostHog preparation clearly states that runtime collection is absent and unauthorized', () => {
  const agents = read('../AGENTS.md');
  const docs = read('../docs/posthog-analytics.md');
  assert.match(agents, /no PostHog runtime integration.*shipped/i);
  assert.match(agents, /purpose scope excludes third-party analytics/i);
  assert.match(docs, /does not ship the PostHog SDK.*or send analytics events/i);
  assert.match(docs, /server-side consent evidence/i);
  assert.match(docs, /VITE_POSTHOG_ENABLED=false/);
});


