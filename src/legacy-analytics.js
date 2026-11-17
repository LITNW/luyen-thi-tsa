import { initializeAnalytics, trackEvent, trackPageView } from './lib/analytics.js';

initializeAnalytics();
trackPageView(window.location.pathname);

document.addEventListener('click', (event) => {
  const action = event.target.closest?.('[data-a]')?.dataset?.a;
  if (action === 'start') {
    trackEvent('legacy_exam_start_clicked', { surface: 'legacy' });
  } else if (action === 'yes') {
    trackEvent('legacy_exam_submit_confirmed', { surface: 'legacy' });
  }
}, true);
