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
- It has no policy link or consent checkbox.
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
- Vercel and Cloudflare are part of the known deployment/infrastructure architecture and require contract, region, log-retention and subprocessor review before the policy describes their roles precisely.


## 3A. Additional live-database checks (read-only)

- An `AFTER INSERT` trigger on `auth.users` calls `public.handle_new_auth_user()`. It creates `public.profiles` using the submitted `display_name` and email. It currently does not require or record a privacy-consent decision. This is a critical backend enforcement gap: changing only the React form would leave the legacy client and direct Auth API path unguarded.
- The profile audit trigger records role/status changes and includes the profile email in `audit_logs.details`. This is another personal-data location that must be included in access and retention rules.
- RLS policies were observed for profile self/admin access, attempt owner/admin access, admin-only import records, and admin-only storage access for the `tsa-imports` bucket. These controls reduce unauthorized access but do not establish a retention schedule or fulfill notice/consent duties.
- The `tsa-imports` Storage bucket is private, limited to 25 MiB per file, and has admin-only select/insert/update/delete policies. At audit time it contained zero objects; `import_jobs` and `import_events` also contained zero records. This is a snapshot, not proof that no future uploads will occur.
- `audit_logs` contained three records at audit time. Do not inspect or reproduce their personal details in this report.
- The inspected Supabase project currently has no deployed Edge Functions. The `handle_new_auth_user` trigger is database-side logic, not an Edge Function.

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

- Complete source-wide collection-path review, including account/profile edits, admin imports, storage buckets, RPCs, database triggers, logs, analytics and deployment providers.
- Determine controller/processor roles, actual provider regions, subprocessors, cross-border transfers and applicable impact-assessment obligations.
- Obtain confirmed controller identity and privacy contact, approved purposes, legal bases, retention schedule and intended user age/eligibility.
- Design consent capture and audit trail server-side, then implement tests before behavior changes.
- Implement the public policy, registration controls in both React and legacy surfaces (or retire legacy registration), user rights request path, retention/deletion workflows and vendor disclosures.
- Validate on Staging; production rollout requires a separate explicit release approval.


## 8. Legal baseline checked on 2026-11-16

- Primary law: Law 91/2025/QH15 on Personal Data Protection, effective 2026-01-01. Article 9 requires voluntary, informed, verifiable consent and consent by purpose; silence/non-response is not consent. Article 11 addresses collection consent. Article 14 governs deletion/destruction/de-identification, including exceptions. Article 20 covers cross-border transfers and impact-assessment duties, subject to statutory and decree exceptions.
- Implementing decree: Decree 356/2025/ND-CP, effective 2026-01-01. Decree 13/2023/ND-CP ceased to have effect when Decree 356 took effect; do not use Decree 13 as the current sole implementation basis.
- Decree 392/2026/ND-CP took effect 2026-11-15 and amends certain administrative procedures in the security-and-order field, including procedural provisions related to Decree 356. Legal review must use the consolidated/current text as of the release date.
- Decree 356 Article 41 contains conditional transitional relief for certain small/start-up and micro businesses from specified impact-assessment/personnel obligations. LIT's legal operator type, size, activity, sensitive-data handling and scale have not been established, so no exemption is assumed.

Official references:
- Law 91/2025/QH15: https://vanban.chinhphu.vn/?docid=214590&pageid=27160
- Decree 356/2025/ND-CP: https://vanban.chinhphu.vn/?docid=216387&pageid=27160
- Decree 392/2026/ND-CP: https://congbao.chinhphu.vn/van-ban-dang-cong-bao/nghi-dinh-l1/trang-2.htm

## 7. Current release gate

**BLOCKED — do not declare LIT privacy-compliant or release the compliance changes to Production.**

The confirmed owner/controller identity, privacy contact, retention periods, and approved processing purposes are business/legal facts that cannot be inferred from the repository. They must be confirmed before final policy text and retention enforcement are committed.
