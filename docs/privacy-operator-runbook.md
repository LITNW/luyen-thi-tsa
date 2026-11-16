# LIT — Privacy operator runbook

Status: **Operational checklist; not a public privacy notice or legal opinion**  
Last updated: 2026-11-16  
Related documents: [Privacy audit](privacy-compliance-audit.md), [Implementation design](privacy-implementation-design.md)

This runbook separates actions the repository automation can perform from actions that require the operator's account access, a secret, or a substantive legal/product decision. It does not authorize Production changes.

## 1. Current release position

- PR #32 (privacy audit/design) is Draft and unmerged.
- PR #33 (browser storage controls) is Draft and unmerged.
- The browser-storage code has passing GitHub Actions build/tests and a successful Cloudflare Pages Preview. It has not had a real-browser/real-learner end-to-end test.
- Consent evidence, registration-intent enforcement, parent confirmation, user-rights workflows, retention jobs and SMTP are not implemented/configured.
- Do not enable public registration for under-16 users on the assumption that an email address alone verifies legal-representative status.
- Do not use Production learner accounts for Preview testing until the Preview-to-Staging Supabase mapping has been verified.

## 2. Operator-only action: prepare Gmail SMTP

Use the approved interim sender: `lit.privacy.vn@gmail.com`.

1. Sign in to that Google account directly.
2. Open Google Account → Security and enable 2-Step Verification if it is not already enabled.
3. Open App passwords (Google may hide this option for accounts protected by certain organization/security policies). Create an app password named, for example, `LIT Supabase Staging`.
4. Copy the generated app password once. Do not send it in ChatGPT, email, GitHub issues, source files, screenshots, or commit history.
5. Open the **Staging** Supabase project (`tsa-practice-staging`, ref `cppalwtdkditlhojpeyc`) → Authentication → SMTP settings.
6. Configure:
   - Enable custom SMTP: on
   - Host: `smtp.gmail.com`
   - Port: `587`
   - Username: `lit.privacy.vn@gmail.com`
   - Password: the Google App Password, entered directly in the Supabase dashboard
   - Sender email: `lit.privacy.vn@gmail.com`
   - Sender name: `LIT`
7. Save and send a test email to an operator-controlled test mailbox. Check delivery, spam placement, sender display, and the link destination.
8. Keep Production SMTP unchanged until Staging tests pass and a separate release checklist is approved. If Google does not offer App passwords, stop; do not weaken Google account security or substitute the normal Gmail password.

The Gmail mailbox being configured as a sender does not by itself complete SPF/DKIM/DMARC alignment for a custom domain. No custom domain sender is assumed here.

## 3. Operator-only decisions before public registration

These are decisions, not technical defaults. Record the approved answers in the privacy design before implementation/publication.

- Public operator identity: what exact individual/operator name and contact details should appear in the notice? Do not imply that LIT is a registered company.
- Legal review: confirm applicable legal bases, notice wording, child-data requirements, cross-border processing disclosures and any required impact-assessment/filing obligations with qualified Vietnamese counsel.
- Retention: approve a duration and deletion exception for each data class. The durations currently marked proposed in the design are not approved policy.
- Under-16 process: confirm what age-band/assent and representative attestation language is appropriate. Email-link possession proves mailbox control only; it does not independently establish that the confirmer is a parent/legal representative.
- Provider register: verify current terms, subprocessors, data locations, logging and retention for Supabase (Singapore), Cloudflare Pages/Workers, email delivery, and any remaining third-party assets. Keep learner-data AI processing, analytics and marketing disabled unless separately assessed and approved.

## 4. Safe test sequence after SMTP is configured

1. Confirm the Preview deployment is connected only to Supabase Staging. If this cannot be independently verified, do not submit any real learner data.
2. Use operator-controlled adult test mailboxes and synthetic data only.
3. Verify adult registration, email confirmation, duplicate/replayed registration intent rejection, expired intent rejection, wrong-email rejection, and direct Auth API bypass rejection.
4. Verify under-16 registration remains restricted before representative confirmation; after link use, verify the recorded event states only that mailbox control and the attestation were submitted.
5. Verify replayed, expired, and wrong-child confirmation links fail closed.
6. Verify an unconfirmed or suspended account cannot read exams, attempts, answers, history, or protected RPC data.
7. Verify consent evidence is immutable to `anon` and `authenticated`, policy versions are immutable, and only narrowly authorized server-side code can create evidence.
8. Verify the legacy registration path follows the same server-side gate or is disabled.
9. Run automated tests, Supabase security advisors, and browser E2E tests before requesting Production approval.

## 5. Production release gate

Do not merge/deploy the privacy changes to Production until all are true:

- Staging schema and behavior tests pass against a known migration baseline.
- Production migration history and schema differences are reconciled; the Staging migration chain is not assumed to be identical.
- Auth Hook configuration (if used) and database trigger enforcement are independently verified.
- Registration, parent-confirmation, RLS/RPC and direct-API negative tests pass.
- SMTP is verified on Staging; Production secrets are entered directly into the Production dashboard.
- Public notice, operator identity, retention schedule, provider/transfer disclosures and legal review are complete.
- Backup/restore and rollback plan is tested.
- Operator explicitly approves the specific Production migration, merge and deployment.

## 6. Secret-handling rules

- Never request or accept App Passwords, Supabase secrets, service-role keys, recovery codes or user passwords in chat.
- Never commit secrets to GitHub, even in a private repository.
- Use dashboard secret fields or a trusted secret manager and verify that secrets are not exposed in build logs.
- If a secret is pasted into an unintended location, rotate it rather than attempting to erase the conversation/history.
