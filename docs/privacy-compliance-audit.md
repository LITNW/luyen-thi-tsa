# LIT — Privacy & Personal Data Compliance Audit

Audit date: 2026-11-16  
Repository: `LITNW/luyen-thi-tsa`  
Audit branch: `compliance/privacy-data-audit`  
Baseline: `main` at `ec0eecd6e544fc374e77bec1684811ac8a1562a4`  
Supabase project inspected read-only: `hwqtsopvpucadgpkigqz`

> This is a technical inventory, not a legal opinion or a declaration of compliance. No Production code, database schema, records, secrets, or deployment settings were changed during this audit.

## 1. Confirmed collection paths and findings

### React registration
File: `src/pages/AuthPage.jsx`

- Registration collects display name, email, and password.
- Calls Supabase Auth `signUp` with `display_name` in user metadata.
- No Privacy Policy link or consent checkbox is rendered.
- Registration is not gated on a recorded consent decision.
- Login also collects email and password; login must be distinguished from new consent.

### Retained legacy registration
File: `public/legacy/index.html`

- The legacy registration form also collects display name, email, and password.
- Its `signup()` handler calls Supabase Auth `signUp` directly.
- It has no policy link or checkbox.
- The legacy app remains reachable at `/legacy/index.html`; this path must be covered or disabled before a release can pass the compliance gate.

### Public landing page
File: `src/pages/PublicLandingPage.jsx`

- Public footer currently contains brand identity only.
- No Privacy Policy or data-rights contact link is present.

### Phone number
- No `type="tel"`, phone field, or phone collection flow was found in the inspected React registration and retained legacy registration.
- Supabase Auth's underlying `auth.users` schema supports a nullable `phone` field. This is platform capability, not evidence that LIT currently collects phone numbers. Keep phone collection disabled unless a separately reviewed feature requires it.

## 2. Data inventory confirmed from live schema (read-only)

The Production public schema contains these relevant categories:

| Category | Tables / fields observed | Privacy implications |
|---|---|---|
| Account identity | `auth.users` (email, password hash/auth metadata, timestamps); `public.profiles` (email, display_name, user_code, role, status, timestamps) | Account and contact identifiers; authentication data is managed by Supabase Auth |
| Learning activity | `attempts`, `attempt_answers`, `attempt_question_times`, `attempt_question_time_events` | User-linked activity, answers, results, timestamps and time spent |
| Administration/security | `audit_logs` (actor, action, target, details, timestamp) | User-linked administrative/security events |
| Admin content import | `import_jobs`, `import_events`, `import_questions` | Uploaded source-file metadata, storage paths, processing metadata and imported question content; inspect actual storage lifecycle and payloads before finalizing notice |
| Authentication telemetry | `auth.sessions` includes IP, user-agent, session and timestamp fields | Technical/session data may be processed by the platform provider |

The database inventory also includes question banks, exam content, taxonomies and education catalogues. Those are not automatically personal data, but records linked to an individual creator or learner may be.

## 3. Third-party and infrastructure observations

- Supabase is the authentication and database provider in the client code.
- The client uses the public Supabase URL and publishable key; no service-role key was observed in the inspected client files.
- The legacy client loads PDF.js assets from cdnjs. This is an external resource request and should be documented in the vendor/data-flow inventory; determine whether request metadata is shared with the CDN.
- Supabase Production currently reports no deployed Edge Functions in the project inventory. Do not describe an AI processing provider as an active recipient until deployment and data flow are verified.
- Cloudflare Pages is confirmed as the active hosting platform for the current repository deployment; Vercel project metadata also exists but does not establish an active Production role. Provider contracts, processing locations, access logs, retention and subprocessors still require review before the policy describes their roles precisely.

## 3A. Additional live-database checks (read-only)

- An `AFTER INSERT` trigger on `auth.users` calls `public.handle_new_auth_user()`. It creates `public.profiles` using the submitted `display_name` and email. It currently does not require or record a privacy-consent decision. This is a critical backend enforcement gap: changing only the React form would leave the legacy client and direct Auth API path unguarded.
- The profile audit trigger records role/status changes and includes the profile email in `audit_logs.details`. This is another personal-data location that must be included in access and retention rules.
- RLS policies were observed for profile self/admin access, attempt owner/admin access, admin-only import records, and admin-only storage access for the `tsa-imports` bucket. These controls reduce unauthorized access but do not establish a retention schedule or fulfill notice/consent duties.
- The `tsa-imports` Storage bucket is private, limited to 25 MiB per file, and has admin-only select/insert/update/delete policies. At audit time it contained zero objects; `import_jobs` and `import_events` also contained zero records. This is a snapshot, not proof that no future uploads will occur.
- `audit_logs` contained three records at audit time. Do not inspect or reproduce their personal details in this report.
- The inspected Supabase project currently has no deployed Edge Functions. The `handle_new_auth_user` trigger is database-side logic, not an Edge Function.

## 3B. Hosting, retention and user-rights checks

- Supabase Production project metadata reports region `ap-southeast-1` (Singapore). Because the user base and data subjects may be in Viet Nam, this is a **potential cross-border personal-data transfer** requiring a legal assessment under the current law and applicable exceptions. The region alone does not establish the full transfer path or settle the filing/exemption question.
- The Vercel project metadata inspected does not establish a Vietnam-only processing region. Its current deployment/project settings and subprocessors must be confirmed before publishing precise location statements.
- The repository's `vercel.json` contains only an SPA rewrite; no Vercel Cron schedule was found there. Supabase Production has no `pg_cron` extension/job table, and no Edge Functions are deployed. No automated retention/deletion job was identified in the inspected infrastructure.
- The `tsa-imports` bucket is currently empty, and no import job or event records were present at the time of the snapshot. The existence of the bucket and admin upload code still means future uploads need retention controls.
- The account page currently displays profile details and supports sign-out only. No self-service data export, consent withdrawal, account deletion, or privacy request path was found in the inspected client routes.
- No telephone input was found in the React registration or retained legacy registration; phone is not a currently confirmed collection field.



## 3C. Additional application and AI data-flow findings (source review, 2026-11-16)

- The retained legacy application writes offline/resume state to browser `localStorage` under `tsa-attempt-*`, `tsa-active-attempt-*` and `tsa-active-attempt-index`. The cached attempt includes answer/progress state and an exam snapshot, and pointers include attempt/user identifiers. This data is stored on the learner's device outside the server retention lifecycle; shared-device exposure, logout cleanup, browser clearing and local retention must be addressed in the notice and product controls. Do not describe this as server-side storage.
- The legacy admin import workflow stores source files in the private `tsa-imports` bucket and records original filenames, MIME type, size, source format, storage path and preprocessing warnings in `import_jobs` / `import_events`. Original filenames may themselves contain personal information.
- The repository contains source for the Supabase Edge Function `tsa-import-process`. The live project inventory at the earlier read-only audit snapshot showed no deployed Edge Functions; therefore, do not claim the Anthropic transfer is currently active solely because source code exists. However, when this function is deployed and invoked, it downloads the uploaded source document (or preprocessed text) and sends its contents to `https://api.anthropic.com/v1/messages` using the configured Claude model. It writes extracted question content and source metadata back to Supabase. This is a material third-party disclosure path that must be assessed and disclosed before enabling the feature for personal or confidential source material.
- The Edge Function source authenticates the caller, checks for an active admin profile, verifies that the import job belongs to that user, and uses a service-role client for server-side processing. These are relevant security controls, but they do not establish Anthropic's retention/training terms, processing region, transfer mechanism, or a lawful basis for sending personal data. Those provider terms and the deployed function/secrets state must be verified before launch.
- Reviewed React and legacy source paths did not reveal a configured analytics SDK (for example, Google Analytics, PostHog or Sentry) or an explicit phone/date-of-birth collection field. This is a bounded source review, not proof that no provider-side telemetry or hosting logs exist.
- The React account page and legacy profile view expose account details and logout but do not provide account deletion, export or consent-withdrawal controls. The legacy signup function remains a direct Supabase Auth `signUp` call without a consent gate, as does the React signup path through `AuthContext`.



## 3D. Additional security and hosting checks (read-only, 2026-11-16)

- Supabase Security Advisor reported 40 `SECURITY DEFINER` functions in the exposed `public` schema callable by the `authenticated` role. ACL inspection found no `PUBLIC` execute grant for this set. A static catalog scan found all 40 reference `auth.uid()`; the `admin_*` functions reference `public.is_admin()` (with `bootstrap_first_admin()` as the separately reviewed exception), and learner-attempt functions reference ownership fields. Representative bodies were inspected and use owner/admin checks; the reviewed functions generally set an empty `search_path`. This substantially narrows the advisor warning but is not proof that every branch/call graph is correct; complete function-by-function review and targeted negative tests remain required before release.
- `bootstrap_first_admin()` remains executable by `authenticated` users. Its body checks for a confirmed hard-coded bootstrap email and refuses to proceed once an admin exists. Treat this as a special bootstrap endpoint and verify the intended account/retirement state; do not infer that all authenticated callers can grant themselves admin.
- The three tables flagged by the advisor for RLS without policies are `attempt_question_time_events`, `exam_solutions`, and `question_answer_keys`. A direct read-only grants check found only `postgres` and `service_role` table grants for these tables, with no `anon` or `authenticated` table grants at the audit snapshot. This indicates no direct Data API table access for ordinary client roles at that snapshot; retain the restricted design and verify any future RPC/service-role access separately.
- Supabase Security Advisor also reports leaked-password protection disabled. This is an authentication hardening item to assess and enable through a separately tested configuration change; it was not changed during this audit.
- The Vercel project metadata confirms SSO protection is enabled for deployments except custom domains, while password protection and trusted-IP restrictions are disabled. The project reports `live: false` and the latest deployment target was null at inspection time. These metadata do not establish the complete public access model or all log-retention settings; verify the effective Production/custom-domain configuration before publication.
- Vercel environment-variable metadata was inspected without decrypting values. The visible names include Supabase connection/public-client variables and database connection variables. No variable values were read or copied into this report. This metadata alone does not establish provider-side processing locations or log retention.
- The connected Cloudflare identity is available, but the current audit has not yet established which Cloudflare products/resources are actively serving LIT traffic, their configuration, data categories, or retention. Do not describe Cloudflare as a confirmed processor for a particular data flow until that mapping is completed.



## 3E. Cloudflare Pages and Worker deployment verification (read-only, 2026-11-16)

- Cloudflare account inspection confirms an active Pages project named `luyen-thi-tsa`, connected to GitHub repository `LITNW/luyen-thi-tsa`, with `main` as the production branch and preview deployments enabled for all branches.
- The Pages project exposes `luyen-thi-tsa.pages.dev`; the project API returned no custom domains. The latest canonical Production deployment was successful and points to the `main` branch. The Pages build configuration has no Cloudflare Web Analytics tag/token configured at the time of inspection.
- The Pages Preview environment is configured with the Supabase Staging project `cppalwtdkditlhojpeyc`; the Pages Production environment is configured with Supabase Production `hwqtsopvpucadgpkigqz`. The public client uses the publishable key in both environments. This is the verified environment split; never point a Preview build at Production for privacy feature testing.
- The Preview build triggered by this documentation-only audit commit was skipped by the Pages path configuration. This does not indicate a failed application build; the changed file is documentation.
- A separate Cloudflare Worker script named `luyen-thi-tsa` is also present in the account. Its observability is enabled with 100% head sampling, persisted invocation logs enabled, and query-string redaction disabled. The script has no Worker Domain or route attached in the inspected Worker API, and its relationship to the Pages-managed production/preview Workers has not yet been established. Do not assume this is the primary Pages runtime; map the script and inspect its request/log payloads before deciding whether query-string redaction or reduced logging is required.

- Cloudflare's current Workers Logs documentation states a maximum retention of seven days; its published plan table lists three days on Workers Free and seven days on Workers Paid (subject to the 2026-12-01 pricing transition). The connected account's effective plan was not verified, so the actual retention period remains unconfirmed. Official reference: https://developers.cloudflare.com/workers/observability/logs/workers-logs/
- Cloudflare documents that stored Workers Logs follow a configured Customer Metadata Boundary; without one, logs may be stored in Cloudflare core data centers globally. The account's boundary setting was not verified. Treat Worker observability as a potential international processing/transfer path until account configuration and the script's actual request flow are established.

- The Vercel project with the similar application name still exists, but its project metadata reports `live: false`; Cloudflare Pages is the confirmed current deployment platform from the account configuration. Vercel remains a possible ancillary/legacy deployment surface until its domains, aliases and active deployment use are fully reconciled.
- No Cloudflare Zone was returned for the connected account, and the Pages project API returned only its `pages.dev` hostname. Reconfirm domain ownership/routing if LIT later attaches a custom domain or uses another Cloudflare account.



## 3F. Supabase Staging environment and migration drift (read-only, 2026-11-16)

- Supabase Staging is confirmed as project `tsa-practice-staging`, ref `cppalwtdkditlhojpeyc`, region `ap-southeast-1`. Cloudflare Pages Preview points to this project; Production points to `hwqtsopvpucadgpkigqz`.

- A Production aggregate-count snapshot on 2026-11-16 returned 2 profiles, 18 attempts, 16 attempt-answer rows, 3 audit-log rows and zero import jobs/events/questions. Counts are approximate operational snapshots, not a user-scale guarantee or retention policy; no personal row contents were selected.
- Neither Production nor Staging currently reports a deployed Edge Function. The AI-import Edge Function source is not an active deployed data-transfer path in either project at this snapshot.
- Production and Staging migration histories are not identical. Production includes `temporarily_revoke_authenticated_exam_version_delete`; Staging instead has a reconstructed pre-005 baseline, a staging-specific profile fallback, additional question-media/stimulus migrations and a different archive-exam migration. Staging migration versions were reconstructed/re-stamped and do not provide a one-to-one chronological mirror of Production.
- This is a known schema/migration-history divergence, not a reason to modify either database blindly. Before creating or applying a privacy migration, compare the relevant live objects, grants, triggers, constraints and function definitions on both projects; design a forward-only migration that is valid against both intended release baselines. Do not reset, repair, or restamp either migration history as part of this privacy task.
- The current Staging project is healthy and can be used for isolated feature development, but its extra schema changes mean a green Staging test alone does not prove Production compatibility. Maintain explicit Production parity checks in the release evidence.

## 4. Confirmed compliance gaps

1. No public Privacy Policy route/page was found in the inspected route map.
2. React and legacy registration have no explicit, unticked consent control.
3. No consent evidence record or policy-version capture was found in the inspected registration paths.
4. No published purpose-specific retention schedule was found in the inspected repository documentation.
5. No public privacy contact or data-subject request workflow was found in the inspected public landing and account routes.
6. No demonstrated deletion/export/withdrawal workflow was found in the inspected client paths. These workflows require a broader backend/RPC/storage audit before conclusions are final.

## 5. Safety constraints before implementation

- Do not deploy a generic policy containing invented controller identity, address, privacy contact, purposes, retention periods, legal bases, or international transfer statements.
- Do not store consent evidence only in Supabase `user_metadata`: it is user-editable. A verifiable record needs a server-controlled design and immutable/versioned policy references.
- Do not alter Production schema or migration history as part of this audit. The existing migration audit records schema/migration-history drift; reconcile it before adding a new Production migration.
- Do not treat acceptance of the Privacy Policy as optional marketing consent. Separate necessary account/service processing from optional marketing and any other optional purposes.
- Do not block login merely because a user has not given a new optional consent. New registration and optional purposes need distinct handling.
- Do not delete historical exam/assessment records indiscriminately. Define retention and erasure rules by record class, legal obligations, account state, and data-minimization requirements.

## 6. Work remaining

- Continue source-wide and live-provider verification, especially the remaining `SECURITY DEFINER` function bodies/call graph, all RPC/function data paths, local browser caches, deployment logs, provider telemetry, Cloudflare Pages/Worker logs and product usage, storage lifecycle, Staging/Production schema parity and any future AI processing deployment.
- Determine controller/processor roles, actual provider regions, subprocessors, cross-border transfers and applicable impact-assessment obligations.
- Confirm approved purposes, legal bases, retention schedule and detailed user eligibility. The dedicated privacy contact email is now confirmed as `lit.privacy.vn@gmail.com`.
- Design consent capture and audit trail server-side, then implement tests before behavior changes.
- Implement the public policy, registration controls in both React and legacy surfaces (or retire legacy registration), user rights request path, retention/deletion workflows and vendor disclosures.
- Review all Security Advisor findings and authentication hardening, preserving the restricted no-policy table grants where intentional; validate all changes on Staging. Production rollout requires a separate explicit release approval.

## 7. Confirmed operator and product decisions (2026-11-16)

- The operator describes LIT as a small group project, currently free to use and temporarily non-profit, with no company or other registered organization.
- The user confirms they personally operate LIT and will be the responsible contact for privacy requests. This does not establish that LIT is a separate legal person. The final notice must accurately identify the individual operator/controller as advised by qualified Vietnamese counsel; do not invent a legal name or residential address.
- The operator has created and confirmed the dedicated LIT privacy contact email: `lit.privacy.vn@gmail.com`. This is the intended public contact for privacy requests. Before publication, verify that the mailbox is accessible to the operator, has appropriate account security/recovery controls, and is monitored for data-subject requests.
- LIT permits users under 16 to register and use the service.
- The operator approved a product control requiring parent/legal-representative email confirmation before activating an account for a user under 16.
- The confirmation workflow must retain a server-controlled, verifiable record of the confirming address, confirmation event/time, exact notice and consent text/version, purposes, child account reference and outcome. Email link possession proves control of that mailbox, not by itself the person's legal status as the child's representative. The flow must include an explicit representation/attestation and a proportionate verification/risk process; do not label the representative as legally verified solely because an email link was clicked.
- Minimize age-gating data. Prefer a minimal age threshold/age-band decision rather than retaining a full date of birth unless legal review establishes that exact DOB is necessary.
- Do not conflate the representative's role in exercising a child's data-subject rights with consent for every processing purpose. Implement purpose-specific consent and preserve any additional child assent required by law for the relevant processing. In particular, Article 24(2) of Law 91/2025/QH15 requires both the child's and legal representative's consent for processing intended to publish or disclose private-life/personal-secret information of a child aged 7 or older.
- The legal text must be checked against the official current consolidated instruments before launch. This technical design is not a legal opinion.

## 8. Legal baseline checked on 2026-11-16

- Primary law: Law 91/2025/QH15 on Personal Data Protection, effective 2026-01-01. Article 9 requires voluntary, informed, verifiable consent and consent by purpose; silence/non-response is not consent. Article 11 addresses collection consent. Article 14 governs deletion/destruction/de-identification, including exceptions. Article 20 covers cross-border transfers and impact-assessment duties, subject to statutory and decree exceptions. Article 24 governs children's data and representation.
- Implementing decree: Decree 356/2025/ND-CP, effective 2026-01-01. Article 6 recognizes written, recorded-call, SMS, email, and suitably verifiable electronic/platform methods of expressing consent; the controller/controller-processor must retain evidence and bears the burden of proving consent. Decree 13/2023/ND-CP ceased to have effect when Decree 356 took effect; do not use Decree 13 as the current sole implementation basis.
- Decree 392/2026/ND-CP took effect 2026-11-15 and amends certain administrative procedures in the security-and-order field, including procedural provisions related to Decree 356. Legal review must use the consolidated/current text as of the release date.
- Decree 356 Article 41 contains conditional transitional relief for certain small/start-up and micro businesses from specified impact-assessment/personnel obligations. LIT's operator type, size, activity, sensitive-data handling and scale have not been established, so no exemption is assumed.

Official references:
- Law 91/2025/QH15: https://vanban.chinhphu.vn/?docid=214590&pageid=27160
- Decree 356/2025/ND-CP: https://vanban.chinhphu.vn/?docid=216387&pageid=27160
- Decree 392/2026/ND-CP: https://congbao.chinhphu.vn/van-ban-dang-cong-bao/nghi-dinh-l1/trang-2.htm

## 9. Current release gate

**BLOCKED — do not declare LIT privacy-compliant or release the compliance changes to Production.**

The actual public privacy contact email, final operator identity wording, retention periods, approved processing purposes and legal bases remain to be confirmed. The under-16 parent-confirmation requirement is approved as a product control, but its legal sufficiency and representative-verification design require review. Do not infer legal exemptions from LIT's informal, non-profit status.
