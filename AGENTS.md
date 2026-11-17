# LIT engineering instructions

## Required development workflow

- Use the installed Superpowers skills for engineering work.
- For new features or behavior changes, use brainstorming before implementation. If the task owner explicitly delegates implementation without further questions, state the material design choices and proceed with safe defaults.
- For bugs, use systematic-debugging before proposing or applying a fix.
- Use Test-Driven Development for behavior changes: add a focused failing test, verify the failure, implement the smallest change, then run the focused and full test suites.
- For multi-step work, write an implementation plan before changing production code.
- Before committing, opening or updating a pull request, or reporting completion, run the relevant verification and inspect the final diff.
- Keep production changes isolated on feature branches and submit pull requests. Do not bypass branch protection or deploy directly to production.

## PostHog product analytics

- Use the shared helper in `src/lib/analytics.js`; do not initialize PostHog elsewhere.
- Add only meaningful, bounded product events. Extend `ALLOWED_ANALYTICS_EVENTS` and its tests when adding an event.
- Event names use snake_case and describe completed outcomes where possible.
- Never send email addresses, names, account IDs, learner IDs, IP addresses, exam IDs, question content, answers, scores, free-text inputs, private upload metadata, authentication tokens, or any other direct or indirect learner identifiers.
- Do not call `identify`, `alias`, or attach Supabase profile/session objects to analytics events.
- Do not enable autocapture, automatic pageview capture, persistent browser identity, or session replay without a separate privacy review and explicit approval.
- Normalize route paths before tracking; never send query strings, path IDs, or user-generated path segments.
- Keep React and legacy application instrumentation aligned. The legacy analytics entry is built separately and injected into the static legacy page by the build script.
- If a feature changes user behavior, include its analytics event and a regression test in the same pull request, unless analytics is intentionally excluded and the reason is documented.

## Privacy and student data

- LIT serves learners, including users under 16. Apply data minimization by default.
- Analytics is anonymous and in-memory by default. No person identification or session replay.
- Do not add tracking for educational performance or assessment answers without a separate approved data-purpose and privacy review.
