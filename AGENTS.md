# LIT engineering instructions

## Required development workflow

- Use the installed Superpowers skills for engineering work.
- For new features or behavior changes, use brainstorming before implementation. If the task owner explicitly delegates implementation without further questions, state the material design choices and proceed with safe defaults.
- For bugs, use systematic-debugging before proposing or applying a fix.
- Use Test-Driven Development for behavior changes: add a focused failing test, verify the failure, implement the smallest change, then run the focused and full test suites.
- For multi-step work, write an implementation plan before changing production code.
- Before committing, opening or updating a pull request, or reporting completion, run the relevant verification and inspect the final diff.
- Keep production changes isolated on feature branches and submit pull requests. Do not bypass branch protection or deploy directly to production.

## PostHog preparation

- This branch contains preparation and policy documentation only. No PostHog runtime integration or SDK is shipped.
- The operator-approved purpose scope excludes third-party analytics. Keep `VITE_POSTHOG_ENABLED=false`; enabling analytics requires a separate explicit approval and implementation review.
- LIT serves learners, including users under 16. Do not add analytics until the public privacy notice, applicable legal basis and consent controls, server-side consent evidence, provider disclosures and retention, and required parental/legal-representative authorization are implemented and reviewed.
- Do not add tracking for educational performance or assessment answers without a separate approved data-purpose and privacy review.
