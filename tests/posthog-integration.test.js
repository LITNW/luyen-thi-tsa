import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('PostHog initializes only when an explicit project token and activation flag are configured', () => {
  const analytics = read('../src/lib/analytics.js');
  assert.match(analytics, /VITE_POSTHOG_PROJECT_TOKEN/);
  assert.match(analytics, /VITE_POSTHOG_HOST/);
  assert.match(analytics, /VITE_POSTHOG_ENABLED/);
  assert.match(analytics, /posthog\.init/);
  assert.match(analytics, /https:\/\/us\.i\.posthog\.com/);
  assert.match(analytics, /if \(!projectToken \|\| !collectionEnabled\) return false/);
});

test('PostHog collection is privacy-minimized for a learning platform used by minors', () => {
  const analytics = read('../src/lib/analytics.js');
  assert.match(analytics, /autocapture:\s*false/);
  assert.match(analytics, /capture_pageview:\s*false/);
  assert.match(analytics, /disable_session_recording:\s*true/);
  assert.match(analytics, /before_send/);
  assert.match(analytics, /REDACTED_AUTOMATIC_PROPERTIES/);
  assert.match(analytics, /persistence:\s*['"]memory['"]/);
  assert.doesNotMatch(analytics, /identify\s*\(/);
  assert.doesNotMatch(analytics, /ip:\s*false/);
});

test('analytics exposes a bounded event API and rejects arbitrary payload data', () => {
  const analytics = read('../src/lib/analytics.js');
  assert.match(analytics, /export function trackEvent/);
  assert.match(analytics, /ALLOWED_ANALYTICS_EVENTS/);
  assert.match(analytics, /properties/);
  assert.match(analytics, /ALLOWED/);
});

test('React route changes emit normalized page views without query strings', () => {
  const app = read('../src/App.jsx');
  assert.match(app, /useLocation/);
  assert.ok(app.includes('trackPageView(pathname)'));
  assert.match(app, /pathname/);
  assert.doesNotMatch(app, /searchParams.*trackEvent/);
});

test('authentication emits outcome events without sending account identifiers', () => {
  const auth = read('../src/context/AuthContext.jsx');
  assert.match(auth, /auth_login_succeeded/);
  assert.match(auth, /auth_signup_succeeded/);
  assert.match(auth, /auth_logout_succeeded/);
  assert.doesNotMatch(auth, /trackEvent\([^)]*(email|user\.id|display_name)/i);
});

test('future engineering tasks inherit the LIT analytics and Superpowers rules', () => {
  const agents = read('../AGENTS.md');
  assert.match(agents, /Superpowers/);
  assert.match(agents, /PostHog/);
  assert.match(agents, /Test-Driven Development/);
  assert.match(agents, /Do not send/);
});

test('legacy exam analytics is bundled and injected into the static legacy application', () => {
  const legacy = read('../src/legacy-analytics.js');
  const vite = read('../vite.config.js');
  const generator = read('../scripts/generate-legacy-config.js');
  assert.match(legacy, /legacy_exam_start_clicked/);
  assert.match(legacy, /legacy_exam_submit_confirmed/);
  assert.match(vite, /legacyAnalytics/);
  assert.ok(vite.includes('manifest: true'));
  assert.ok(generator.includes('src/legacy-analytics.js'));
  assert.ok(generator.includes('<script type="module"'));
});

test('analytics events include only deployment environment and bounded route metadata', () => {
  const analytics = read('../src/lib/analytics.js');
  assert.match(analytics, /VITE_POSTHOG_ENVIRONMENT/);
  assert.ok(analytics.includes('safeProperties.environment'));
  assert.ok(analytics.includes('normalizeRoute'));
  assert.ok(analytics.includes('ALLOWED_ROUTES'));
  assert.ok(!analytics.includes('window.location.search'));
});
