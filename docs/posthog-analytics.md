# PostHog analytics for LIT

## Purpose

PostHog instrumentation and dashboards are prepared, but third-party analytics is not currently an approved LIT purpose and event collection remains disabled. The operator-approved purpose scope recorded in privacy PR #32 excludes third-party analytics. This integration must not be activated until that scope is explicitly amended and the privacy/consent controls described below are implemented and reviewed. PostHog is not a learner assessment database, an identity provider, or a source of truth for exam outcomes.

## Runtime configuration

Set these Vite environment variables in Vercel and local development:

- `VITE_POSTHOG_ENABLED`: set to `true` only after the required privacy approval and IP-discard setting are confirmed; default is `false`.
- `VITE_POSTHOG_PROJECT_TOKEN`: PostHog project token for the LIT project.
- `VITE_POSTHOG_HOST`: `https://us.i.posthog.com` (optional; this is the application fallback).

The project token is a public ingestion key and must be read from the environment, never hard-coded in application source. Keep the PostHog organization/project credentials separate from Supabase secrets.

## Privacy defaults

The shared SDK configuration deliberately:
- disables autocapture and automatic pageview/pageleave capture;
- disables session recording;
- uses in-memory persistence rather than cookies or local storage;
- removes automatically attached full URLs, pathnames, referrers, host, user-agent, and IP properties with a `before_send` redaction hook;
- does not rely on the deprecated SDK `ip` option; collection remains disabled until the PostHog project-level IP-discard setting is approved and enabled;
- avoids `identify` and person-profile creation;
- sends only allowlisted event names and bounded route labels;
- never sends query strings, dynamic route IDs, learner identities, exam content, answers, scores, or free text.

These technical defaults reduce collected data; they do not replace the project's privacy notice, legal basis, or any required consent process. Project-level IP discarding is now enabled (`anonymize_ips=true`), but that does not authorize collection. Keep `VITE_POSTHOG_ENABLED=false` in all environments until (1) the operator explicitly amends the approved purpose scope to include third-party analytics, (2) a public privacy notice and provider disclosures are in place, (3) applicable legal basis and consent controls are reviewed, (4) server-side consent evidence is implemented, and (5) required parental/legal-representative authorization for under-16 learners is addressed. PR #32 records third-party analytics as disabled; PR #33 records that closing the notice is not consent and client preferences are not server-side legal evidence.

## Current event contract

| Event | Meaning | Allowed properties |
| --- | --- | --- |
| `page_view` | A React or legacy route was opened | normalized `route` only |
| `auth_login_succeeded` | Supabase password sign-in returned successfully | none |
| `auth_signup_succeeded` | Supabase sign-up request returned successfully | none |
| `auth_logout_succeeded` | Supabase sign-out returned successfully | none |
| `dashboard_viewed` | Authenticated dashboard rendered | none |
| `legacy_exam_start_clicked` | Learner clicked the legacy exam start action | fixed `surface=legacy` |
| `legacy_exam_submit_confirmed` | Learner confirmed legacy exam submission | fixed `surface=legacy` |

The legacy exam events represent user actions, not confirmed server-side exam outcomes. They must not be interpreted as completed attempts or submissions.

## Adding events in future tasks

1. Decide whether the event is necessary to answer a defined product question.
2. Prefer an aggregate action event over user-level event histories.
3. Add the event to `ALLOWED_ANALYTICS_EVENTS` and add only fixed, non-identifying properties.
4. Add a regression test to `tests/posthog-integration.test.js`.
5. Instrument the React and legacy path when the feature exists in both.
6. Verify that no PII, learner IDs, assessment data, free text, query strings, or dynamic IDs are sent.
7. Run `npm test` and `npm run build`.

## Dashboards and operations

Use the PostHog project connected to this repository. Build insights from the event contract above and filter preview/development traffic separately from production when environment metadata is added. Do not create user-level cohorts or enable replay for minors by default.
