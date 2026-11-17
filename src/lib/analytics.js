import posthog from 'posthog-js';

const projectToken = import.meta.env.VITE_POSTHOG_PROJECT_TOKEN;
const apiHost = import.meta.env.VITE_POSTHOG_HOST || 'https://us.i.posthog.com';
const runtimeEnvironment = import.meta.env.VITE_POSTHOG_ENVIRONMENT;
const collectionEnabled = import.meta.env.VITE_POSTHOG_ENABLED === 'true';

export const ALLOWED_ANALYTICS_EVENTS = new Set([
  'page_view',
  'auth_login_succeeded',
  'auth_signup_succeeded',
  'auth_logout_succeeded',
  'dashboard_viewed',
  'legacy_exam_start_clicked',
  'legacy_exam_submit_confirmed',
]);

const ALLOWED_ROUTES = new Set([
  'home', 'login', 'register', 'account', 'history', 'admin',
  'admin_exams', 'admin_education', 'admin_categories', 'admin_users',
  'admin_attempts', 'education_level', 'education_context',
  'education_subject', 'exam', 'results', 'legacy', 'other',
]);

let initialized = false;

export function initializeAnalytics() {
  if (initialized) return true;
  if (!projectToken || !collectionEnabled) return false;

  posthog.init(projectToken, {
    api_host: apiHost,
    defaults: '2026-08-30',
    autocapture: false,
    capture_pageview: false,
    capture_pageleave: false,
    disable_session_recording: true,
    disable_external_dependency_loading: true,
    persistence: 'memory',
    person_profiles: 'identified_only',
  });

  initialized = true;
  return true;
}

export function trackEvent(eventName, properties = {}) {
  if (!initialized || !ALLOWED_ANALYTICS_EVENTS.has(eventName)) return false;

  const safeProperties = {};
  if (['production', 'preview', 'development'].includes(runtimeEnvironment)) {
    safeProperties.environment = runtimeEnvironment;
  }
  if (eventName === 'page_view' && ALLOWED_ROUTES.has(properties.route)) {
    safeProperties.route = properties.route;
  }
  if (
    (eventName === 'legacy_exam_start_clicked' || eventName === 'legacy_exam_submit_confirmed')
    && properties.surface === 'legacy'
  ) {
    safeProperties.surface = 'legacy';
  }

  posthog.capture(eventName, safeProperties);
  return true;
}

export function trackPageView(pathname) {
  return trackEvent('page_view', { route: normalizeRoute(pathname) });
}

export function normalizeRoute(pathname = '/') {
  if (pathname === '/') return 'home';
  if (pathname === '/login') return 'login';
  if (pathname === '/register') return 'register';
  if (pathname === '/account') return 'account';
  if (pathname === '/history') return 'history';
  if (pathname === '/admin') return 'admin';
  if (pathname === '/admin/exams') return 'admin_exams';
  if (pathname === '/admin/education') return 'admin_education';
  if (pathname === '/admin/categories') return 'admin_categories';
  if (pathname === '/admin/users') return 'admin_users';
  if (pathname === '/admin/attempts') return 'admin_attempts';
  if (/^\/education\/[^/]+\/context\/[^/]+$/.test(pathname)) return 'education_context';
  if (/^\/education\/[^/]+\/subject\/[^/]+$/.test(pathname)) return 'education_subject';
  if (/^\/education\/[^/]+$/.test(pathname)) return 'education_level';
  if (/^\/exam\/[^/]+$/.test(pathname)) return 'exam';
  if (/^\/results\/[^/]+$/.test(pathname)) return 'results';
  if (pathname.startsWith('/legacy')) return 'legacy';
  return 'other';
}
