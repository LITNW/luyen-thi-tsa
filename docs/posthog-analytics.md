# PostHog preparation for LIT

## Current status

This pull request contains policy and implementation-planning documentation only. It does not ship the PostHog SDK, initialize PostHog, or send analytics events. The sample setting remains `VITE_POSTHOG_ENABLED=false`. Third-party analytics is outside the operator-approved purpose scope, so no runtime integration is included.

The operator-approved purpose scope recorded in privacy PR #32 excludes third-party analytics. PR #33 records that dismissing a notice is not consent and browser preferences are not server-side legal evidence. PostHog is not a learner assessment database, an identity provider, or a source of truth for exam outcomes.

## Conditions for a future, separate integration

A future proposal must be reviewed and approved separately. Before any collection can be enabled, it must address all of the following:

1. The operator explicitly amends the approved purpose scope and defines a necessary product question.
2. A public privacy notice and provider disclosures are in place.
3. The applicable legal basis and consent controls are reviewed.
4. Server-side consent evidence is implemented.
5. Required parental or legal-representative authorization for learners under 16 is addressed.
6. Provider retention and project-level IP-discard settings are reviewed.
7. The implementation, data minimization, and tests are reviewed in a separate change.

The environment sample keeps `VITE_POSTHOG_ENABLED=false`. No PostHog project token or host is required by this branch. Existing deployment environment settings are operational configuration and are not changed by this documentation pull request.

## Deployment note

Keep `VITE_POSTHOG_ENABLED=false` in all environments. This branch has no code that consumes PostHog configuration. Dashboard creation, SDK integration, and any collection are outside its scope and require separate approval.
