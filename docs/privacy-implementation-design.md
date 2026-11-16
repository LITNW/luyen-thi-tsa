# LIT — Privacy Implementation Design

Status: **Draft for technical/legal review; purpose scope approved 2026-11-16**  
Date: 2026-11-16  
Related audit: [Privacy & Personal Data Compliance Audit](privacy-compliance-audit.md)  
Repository: `LITNW/luyen-thi-tsa`

> This is an engineering design proposal, not legal advice, a final Privacy Policy, or a compliance certification. Items marked **OPEN** must not be silently inferred or published.

## 1. Proposed operating principles

1. Collect only data necessary for the confirmed service purposes.
2. Keep service-essential processing distinct from optional purposes such as marketing, analytics, and AI processing.
3. Do not enable marketing, third-party analytics, or AI processing of learner personal data by default. Any later activation requires a separate purpose/legal-basis review and, where required, separate opt-in.
4. Never treat a privacy-policy page view, silence, or a preselected checkbox as consent.
5. Store consent evidence in server-controlled records, not only in client-editable Auth metadata.
6. Do not permit direct Supabase Auth signup to bypass the registration/consent gate.
7. Under-16 accounts remain restricted until the approved parent/legal-representative confirmation flow completes.
8. Build and test on Supabase Staging and Cloudflare Pages Preview only. Production changes and public release require separate approval.

## 2. Approved minimum purpose inventory (operator approval: 2026-11-16)

| Purpose | Data involved | Proposed default |
|---|---|---|
| Create and secure an account | Email, display name, password/authentication metadata, account status | Essential to account service |
| Deliver exam practice | Exam selections, attempt state, answers, time spent, scores and results | Essential to requested learning features |
| Save learning history | Attempt history, progress and result details | Essential only while the user chooses to retain/use history; retention must be defined |
| Security and abuse prevention | Session/IP/user-agent telemetry, authentication and admin audit events | Restricted operational processing; provider/log retention must be disclosed |
| Support and privacy requests | Contact email, request content, identity-verification evidence and response history | Used only to respond to the request |
| Parent/legal-representative confirmation | Child account reference, representative email, attestation, token outcome and timestamps | Required for the approved under-16 activation gate |
| AI-assisted content import | Admin-uploaded source documents and extracted content | Keep disabled until provider terms, transfer, purpose and access are approved |
| Analytics and marketing | Not currently confirmed as configured | Keep disabled unless separately approved |

**APPROVED:** The operator approved this minimum scope on 2026-11-16: account creation/security; exam practice; learner-selected history/progress/results; security and abuse prevention; support/privacy requests; and parent/legal-representative confirmation for under-16 accounts. Marketing, third-party analytics, and AI processing of learners' personal data remain disabled. AI-assisted import of administrator-supplied material is a separate future assessment and is not authorized by this purpose approval. Legal bases and final notice wording still require qualified Vietnamese legal review.

## 3. Proposed consent and registration architecture

### 3.1 Server-controlled consent evidence

Proposed private database records:

- `privacy_policy_versions`: immutable policy version, effective date, exact published text or canonical document reference, content hash, and publication status.
- `privacy_consent_events`: append-only event with user reference, purpose identifier, decision, policy/notice version, exact text hash, server timestamp, capture method, and actor type.
- `registration_intents`: short-lived, single-use registration authorization created server-side, with hashed random token, normalized email binding, selected policy version, purpose decisions, age-band decision, expiry and consumption state.
- `parental_authorizations`: child account reference, representative email, representation attestation, notice/consent version, purpose scope, token hash, sent/confirmed/expired timestamps and outcome.

Client roles must not be able to insert, update, or delete evidence rows directly. User-facing reads should expose only the minimum necessary status. Administrative access must be restricted and audited. Exact schema, constraints, retention and RLS require review before migration.

### 3.2 Registration gate

Proposed flow:

1. Registration page presents the applicable notice, version and separate purpose choices. Optional purposes start unchecked.
2. A server endpoint creates a short-lived registration intent and stores the submitted decisions server-side.
3. A Supabase Auth Before User Created Hook should perform early server-side validation of the registration intent and reject missing/invalid tokens before user creation. The AFTER INSERT auth.users database trigger remains the authoritative transactional gate: it must atomically consume the matching single-use intent, write immutable consent evidence, and reject/roll back creation if the token is missing, expired, replayed, email/policy mismatched, or the purpose scope is not allowed. Client-supplied user_metadata may carry only an opaque intent token; it is never treated as evidence. If the Auth hook is unavailable on the current plan/configuration, the database trigger still must enforce the gate.
4. Adult accounts proceed to the normal email-verification process and become active only after the required account checks.
5. Users who declare they are under 16 enter a restricted `pending_parent` state. They cannot access exams, history or other protected features until the representative confirmation succeeds.
6. The legacy signup path must use the same server-side gate or be disabled. A frontend-only checkbox is insufficient.

The token is a one-time capability proving that a server-created intent exists; the client-supplied metadata itself is not treated as consent evidence.

### 3.3 Parent/legal-representative confirmation

- Collect an age threshold/age band rather than full date of birth unless counsel establishes a need for exact DOB.
- Send a one-time, expiring, single-use confirmation link to the representative email.
- Require an explicit attestation that the confirmer is the parent/legal representative and preserve the exact notice/consent version and event time.
- Email-link possession proves control of the mailbox, not legal status. The interface and records must not label the person legally verified solely because the link was clicked.
- Do not grant the representative unrestricted access to the child's account or learning history merely because they confirmed activation.
- Preserve any additional child assent required for a specific processing purpose.

**OPEN:** No transactional email provider is confirmed for parent-confirmation messages. The privacy contact Gmail address is a contact mailbox, not automatically a configured transactional sender. Select and configure an email delivery method before implementing this flow.

## 4. User-rights and account lifecycle design

Proposed request types:

- Access/copy of personal data.
- Correction of account/profile information.
- Withdrawal of a specific optional consent.
- Account closure and deletion request.
- Parent/legal-representative request concerning a child's account.
- Complaint or privacy/security incident report.

Initial delivery can use the public privacy contact email plus a secure in-account request form. Requests should be recorded with status, received/verified/completed timestamps, identity-verification method, decision and response record. Do not send a full data export or sensitive account information to an unverified email address.

Deletion must be designed by data class. Revoke active sessions before account deletion. Delete or anonymize learner-linked records where appropriate, but preserve only those records that have a documented legal/operational basis and a defined retention period. Consent withdrawal for an optional purpose must not automatically destroy the account. Withdrawal of processing needed to provide the core service may require account restriction or closure, subject to legal review.

## 5. Retention and deletion matrix — durations are OPEN

| Data class | Current location | Proposed lifecycle rule | Duration |
|---|---|---|---|
| Auth identity/profile | Supabase Auth and `profiles` | While account is active; process a valid deletion request within the applicable statutory window, subject to documented exceptions | **20 days proposed for LIT action; third-party action may require 30 days** |
| Attempts, answers, timing and results | Supabase learning tables; legacy browser cache | Retain while the account is active and history feature is used; support user-initiated deletion and account-closure deletion | **No inactivity expiry proposed yet; deletion request 20 days proposed** |
| Security/admin audit logs | Supabase `audit_logs`, provider telemetry | Raw IP/user-agent only where necessary; restrict access; preserve incident/legal-hold exceptions | **90 days for operational security logs; 12 months for admin audit events proposed** |
| Sessions and hosting/Worker logs | Supabase Auth, Cloudflare and possibly Vercel | Revoke sessions on closure; disclose provider-controlled log retention separately | **Session until expiry/revocation; provider retention to be verified** |
| Import source files and job metadata | Private Supabase Storage and import tables | Delete source files after successful processing/review; purge failed/cancelled uploads sooner | **30 days after success; 7 days after failure/cancellation proposed** |
| Consent and parent-confirmation evidence | Proposed private consent tables | Preserve versioned evidence for the legally justified period; restrict access and deletion | **OPEN — qualified legal review required before selecting a period** |
| Privacy requests | Proposed request register/email mailbox | Retain until fulfilled plus a justified dispute/accountability period; minimize message contents | **3 years after closure proposed, subject to legal review** |

No automatic deletion job should be implemented until the operator approves the provisional operational defaults and legal review confirms the retention periods and exceptions.

## 6. Third-party and transfer register to complete

| Provider/path | Confirmed role | Open verification |
|---|---|---|
| Supabase Production and Staging | Auth, database and private Storage; both in Singapore region | Contract/subprocessor terms, exact data flow, retention, cross-border assessment |
| Cloudflare Pages | Confirmed active hosting; Preview maps to Staging and Production maps to Production | Account terms, edge/request log behavior, region/data-localization settings |
| Cloudflare Worker `luyen-thi-tsa` | Separate Worker exists; persisted invocation logs enabled and query-string redaction disabled | Whether it handles learner requests, what it logs, account metadata boundary and applicable retention |
| Vercel | Similar project exists but metadata reports `live: false` | Confirm whether any current domains, aliases, logs or processing remain active |
| cdnjs | Legacy PDF.js external asset source | Request metadata and whether it remains required |
| Anthropic | Conditional code path in `tsa-import-process`; no Edge Function deployed in Production or Staging at audit time | Terms, retention/training, processing location, transfer mechanism and approval before deployment/use |

Cloudflare Workers Logs documentation states a maximum retention of seven days, with published Free/Paid plan retention of three/seven days; the actual account plan was not verified. Cloudflare states that stored Workers Logs follow a configured Customer Metadata Boundary, or may be stored globally if no boundary is configured. Verify the account setting before final transfer disclosures.

## 7. Implementation sequence

1. **Decision gate:** purpose scope is approved. Remaining decisions are retention durations, transactional email method, and public operator identity wording; legal bases and final notices require qualified review.
2. **Technical preflight:** compare relevant Staging/Production schema, triggers, grants and functions; preserve existing migration history; record a forward-only migration design.
3. **Backend foundation:** implement versioned policy records, registration intents, append-only consent events, parent authorization records and server-only functions.
4. **Registration integration:** add React controls; adapt legacy signup or retire it; enforce backend gate against direct Auth API calls.
5. **Public notice:** create a public Privacy Policy route and contact links after legal content is approved.
6. **Rights workflows:** implement request capture, verification, export, correction, withdrawal, closure and deletion.
7. **Retention:** implement scheduled cleanup only after durations and exceptions are approved.
8. **Vendor controls:** verify Cloudflare Worker logging scope/redaction, provider contracts, data regions and conditional AI-import controls.
9. **Verification:** run unit, integration and negative security tests on Staging; compare Production compatibility without applying changes.
10. **Legal/release gate:** obtain qualified legal review, approve the final notice and then seek separate Production release approval.

## 8. Required test cases

- Direct Auth signup without a valid server-created registration intent is rejected.
- Expired, replayed, mismatched-email and wrong-policy-version tokens are rejected.
- Consent evidence cannot be modified by the account owner or a normal authenticated client.
- Optional purposes are unchecked by default and can be declined independently.
- Login for an existing account does not silently create a new consent event.
- Under-16 account remains restricted until a valid representative confirmation; expired/replayed links fail.
- Parent confirmation records attestation but does not grant parent access to the child's private learning data.
- React and legacy signup have identical backend enforcement.
- User export is limited to the authenticated data subject and does not expose other users.
- Withdrawal affects only the selected optional purpose; core service behavior follows the approved legal basis.
- Account deletion revokes sessions and applies the approved data-class deletion/anonymization rules.
- Retention jobs cannot delete consent/legal-hold records outside their approved policy.
- No sensitive personal data or tokens are written to application/Worker logs.

## 9. Current blockers

- **OPEN — Public controller/operator identity wording:** the operator is an individual and LIT has no registered legal entity. Qualified Vietnamese counsel must confirm the accurate public wording and required contact details.
- **APPROVED — Purpose scope:** the minimum scope in Section 2 is approved. **OPEN — Legal bases:** counsel must validate the applicable legal bases and notice/consent wording.
- **OPEN — Retention periods:** durations must be chosen per data class and checked against applicable obligations.
- **OPEN — Transactional email:** no provider/configuration is confirmed for parent-confirmation email.
- **OPEN — Cloudflare log scope and localization:** the separate Worker's relation to the Pages runtime and Customer Metadata Boundary setting are unknown.
- **OPEN — Legal review:** current consolidated Vietnamese instruments and the under-16 design require qualified review before publication/release.
- **BLOCKED — Production:** no Production schema/configuration change or public compliance claim is authorized by this design.

## 10. Operator approval and live technical preflight (2026-11-16)

- The operator approved the minimum purpose scope in Section 2. This approval does not authorize marketing, third-party analytics, or AI processing of learners' personal data. Administrator-supplied AI import remains a separate future review.
- A live read-only comparison confirmed that Production and Staging both have an `AFTER INSERT ON auth.users` trigger named `on_auth_user_created_profile`, but the trigger function bodies differ. Staging has a fallback display-name path and email validation; Production requires a supplied display name. Do not assume migration-history parity or deploy a shared migration without comparing the complete target objects.
- Both environments currently create the profile as `status = 'active'` and have no consent/registration-intent gate in the trigger. The current profile status constraint allows only `active` and `suspended`; the under-16 `pending_parent` state therefore requires an explicit schema and authorization design before implementation.
- Supabase's current documentation confirms the Before User Created Hook is available on Free and Pro plans and can be implemented as a Postgres function, so this does not require an Edge Function or an upgrade. Use it for early rejection, while keeping the Auth-user database trigger as the final atomic enforcement point that consumes the one-time registration intent and records consent in the same transaction as user/profile creation. Grant `supabase_auth_admin` only the exact schema/function/table permissions needed; revoke execution from `anon`, `authenticated` and `public`. The hook must not be the sole control unless atomic single-use behavior is proven. Official guides: https://supabase.com/docs/guides/auth/auth-hooks/before-user-created-hook and https://supabase.com/docs/guides/auth/auth-hooks
- Cloudflare account API reinspection confirms the Pages project has only `luyen-thi-tsa.pages.dev` listed, no configured Web Analytics tag/token, and Production/Preview each expose only the expected Supabase URL and publishable-key variable names. Secret values were not retrieved. The separate Worker `luyen-thi-tsa` is present with invocation logs enabled, persisted, 100% head sampling, and query-string redaction disabled; traces are disabled. Its linkage to Pages/user traffic is still unproven. Do not change logging settings until the Worker route/custom-domain association and actual request flow are mapped.
- Cloudflare account-level metadata returned a standard account type but did not establish a Workers plan, Customer Metadata Boundary, or legal transfer basis. These remain open; do not infer location or retention from the account type.

## 11. Rights-request deadlines and email delivery constraints

- Decree 356/2025/ND-CP Article 5 sets operational deadlines for properly submitted data-subject requests: acknowledge/provide procedure information within 2 working days; withdrawal/restriction/objection within 15 days (20 days where a processor/third party must also stop); access/correction/data provision within 10 days (15 days where a processor/third party is involved); deletion within 20 days (30 days where a processor/third party must act). The decree permits only the specified limited extensions with reasons and notice. These are request-fulfilment deadlines, not blanket data-retention periods. Confirm the current consolidated text with counsel before publication. Reference: https://thuvienphapluat.vn/van-ban/Cong-nghe-thong-tin/Decree-356-2025-ND-CP-elaborating-on-certain-articles-of-Law-on-personal-data-protection-689146.aspx
- Law 91/2025/QH15 Article 14 requires deletion/destruction/de-identification in defined cases including purpose fulfilment and expiry of the applicable storage period, subject to statutory exceptions. It does not provide one universal retention duration for every LIT data class. The schedule must therefore be purpose- and data-class-specific, with legal exceptions documented. Reference: https://vanban.chinhphu.vn/?docid=214590&pageid=27160
- Supabase's default Auth SMTP is not production-suitable: the current documented limit is 2 messages per hour and messages are restricted to pre-authorized project-team addresses unless custom SMTP is configured. A real under-16 parent-confirmation flow cannot rely on default SMTP for public recipients. Reference: https://supabase.com/docs/guides/auth/auth-smtp
- Current provider comparison: Resend Free advertises 3,000 emails/month, 100/day, 3 verified domains and 30-day provider data retention; Brevo Free advertises 300 emails/day and transactional email but adds Brevo branding. Both require sender/domain verification for reliable production use. Neither has been selected or connected. References: https://resend.com/pricing/ and https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- LIT currently has no custom domain in the verified Cloudflare Pages project; only `luyen-thi-tsa.pages.dev` is configured. A dedicated sending domain or subdomain is therefore an unresolved dependency for a branded transactional sender. The existing privacy Gmail address is a confirmed contact mailbox but is not yet approved/configured as the transactional sender.

### 5.1 Proposed operational defaults — approval pending

The durations above are engineering recommendations for a small service, not statutory retention periods. They must be validated against the final legal classification and any applicable recordkeeping obligations before publication or automated deletion.

- Browser-side attempt cache: clear on logout and after successful submission; apply a 30-day maximum TTL as a fallback for abandoned attempts.
- Security telemetry: retain raw IP/user-agent only for 30 days where needed for abuse/security investigations; keep minimized or pseudonymized security events for up to 90 days.
- Administrative audit events: 12 months, restricted to security/accountability events; avoid copying email addresses or other direct identifiers into free-form `details` unless necessary.
- Import source files: 30 days after successful import/review; 7 days after failed/cancelled import. No personal/confidential source material may be sent to an AI provider under the current approval.
- Consent and parent-confirmation evidence: do not configure automatic deletion until qualified counsel confirms the legally defensible retention period and exceptions.
- Privacy request records: 3 years after closure is a provisional operational proposal, not a legal requirement; counsel must confirm or revise it.

Law 91/2025/QH15 Article 14 provides purpose/period-based deletion grounds and statutory exceptions, but no single blanket retention period for every LIT data class. Decree 356/2025/ND-CP Article 5 separately establishes request-processing deadlines: respond with procedure information within 2 working days; withdrawal/restriction/objection within 15 days (20 days where a processor/third party must also stop); access/correction/data provision within 10 days (15 days where a processor/third party is involved); deletion within 20 days (30 days where a processor/third party must act), subject to the decree's limited extension rules. These fulfilment deadlines must not be confused with retention periods.

### 5.2 Email sender decision

Supabase's default Auth SMTP is restricted to team-authorized addresses and currently limited to 2 messages/hour; it is not suitable for public parent-confirmation recipients. Supabase supports custom SMTP. LIT's Supabase organization is on the Free plan, and the Before User Created Hook is documented as available on Free and Pro.

**APPROVED interim sender (2026-11-16):** use `lit.privacy.vn@gmail.com` as the transactional sender through Gmail SMTP. Configuration is not yet applied: the operator must create a dedicated App Password after enabling 2-Step Verification and provide it through a secure configuration path. The App Password must never be placed in GitHub, frontend code, logs or chat. Use `smtp.gmail.com:587` with STARTTLS, store the App Password only in Supabase Auth SMTP configuration, and never put it in GitHub, frontend code, logs or chat. Google documents personal Gmail SMTP limits of up to 500 messages/day. This is suitable only for low-volume transactional messages and has less isolation/reliability than a dedicated transactional provider.

Alternative: Resend Free advertises 3,000 messages/month and 100/day, but LIT would need a verified sending domain; the current Pages setup has no custom domain. Brevo Free advertises 300/day but adds provider branding. Neither provider is selected.


### 5.3 Client-side storage strategy to reduce server load

Use browser storage to cache data and hold temporary work, not as the authoritative record:

- Cache API + service worker: versioned static assets (JS/CSS/fonts/icons) and public, non-personal exam media. This reduces repeated downloads and CDN/origin requests. Do not cache authenticated API responses or private exam payloads with a shared Cache-first policy.
- IndexedDB: temporary exam-session state, unsent answer drafts, question navigation state, and a bounded cache of recently viewed question content. Use per-account namespaces, explicit TTL/LRU cleanup, schema versioning, and clear account-scoped data on logout/account switch. Drafts should sync to the server when connectivity returns; a local draft is not a submitted answer.
- localStorage: only small non-sensitive preferences such as theme, font size, display settings, and last-selected filters. Never store passwords, access/refresh tokens, consent proof, parent confirmation tokens, or authoritative scores here.
- sessionStorage: ephemeral UI state for a single tab/session, such as current filter or temporary navigation state.
- Cookies: only small session/security identifiers when required by the auth architecture. Use Secure, HttpOnly and an appropriate SameSite policy for server-set session cookies; never store question sets, answers, scores, profile data or other bulk content in cookies.
- Server remains authoritative for account identity, consent/parent evidence, submitted attempts, final answers, scores, abuse/security events and administrative audit records. Client storage is untrusted and can be edited or cleared by the user/browser.
- Browser storage is best-effort and may be evicted, cleared by private browsing, or unavailable under quota pressure. Never rely on it as the sole copy of data users expect to retain. Handle quota errors and network loss explicitly.
- Data minimization: don't cache more questions or media than needed; prefer a small rolling cache with TTL, and don't pre-download full exam banks. Avoid caching data belonging to one account for another account on shared devices.
- Cache-control: use immutable hashed asset filenames for public static assets; use `private, no-store` (or carefully scoped authenticated revalidation) for private responses. Ensure service-worker cache rules cannot override server privacy headers.

Expected benefits: fewer repeated static/media downloads, fewer repeated reads for recently viewed content, and fewer server writes for unsent interaction state. This does not reduce the database footprint of authoritative submitted attempts unless the product deliberately stops retaining them, which would affect learning-history functionality and requires a separate purpose/retention decision.

Implementation should start with static assets and non-personal public content caching, then a small IndexedDB draft/cache layer. Do not move submitted answer/result records off the server as a cost-saving measure.


## 12. Client-side storage and Cookie controls implementation status (2026-11-16)

Implemented on feature branch `feat/privacy-cookie-controls`; not merged or deployed:

- Added a versioned, fail-safe preference record in `localStorage`. Essential and security categories are fixed on; preferences and page-state choices are independently selectable; analytics is hard-disabled because no analytics provider is approved or configured.
- Added a React consent/preferences panel mounted across React routes, with reject-optional, save-selection, accept-available-options, and persistent settings launcher.
- Added a matching consent panel to the retained legacy exam client. Both interfaces share the same storage key and consent version.
- Added a service worker that caches only same-origin public static assets under `/assets/` and `/brand/`, with bounded cache size and cache-version cleanup. It does not cache HTML, Supabase/API responses, authenticated requests, exam payloads, answers, or private media.
- Added an IndexedDB helper for bounded temporary, per-account records with TTL, payload-size limit, and account-scoped cleanup. React AuthContext clears this temporary store when the authenticated account changes.
- The retained legacy exam engine now routes active-attempt cache records through a separate IndexedDB database (`lit-attempt-storage`), keyed by account ID and logical record key. Its existing synchronous call sites use an in-memory account-scoped mirror hydrated before authenticated recovery begins; writes are serialized into IndexedDB transactions.
- First-login migration reads only the signed-in account's legacy attempt pointers/cache records, writes them to IndexedDB, reads them back and compares serialized values, and only then removes the corresponding legacy `localStorage` records. Records for other accounts remain untouched. If IndexedDB initialization or migration fails, the old records are retained and the legacy localStorage path is used as a fallback; the UI receives a storage-error notification.
- Offline restoration, dirty-answer revisions, pending question-time events, server reconciliation, retry-on-reconnect, pending submission and authoritative server result retrieval remain in the existing exam engine. IndexedDB is still best-effort local recovery, not the submitted-answer/result authority.
- Supabase JS Auth currently uses its default browser storage for persisted sessions; no HttpOnly server-set session cookie was introduced. The notice explicitly discloses this current behavior.
- The optional page-state and preferences categories are preference records only; no analytics is active. Any future feature consuming these categories must check the saved choice before writing optional data.
- Consent choices are client-side preference records only, not legal consent evidence. The server-side registration intent and immutable consent-evidence architecture in Sections 3.1–3.2 remains unimplemented. No compliance claim is made.
- Unit tests cover consent defaults, immutable required categories, analytics hard-disable, version mismatch/malformed data and storage failures; browser-storage tests cover account scoping and preflight size validation. Build and full browser integration verification remain pending CI/Preview evidence.


## 12A. Legacy attempt cache migration implementation (2026-11-16)

Implemented on `feat/privacy-cookie-controls`; PR #33 remains Draft and no Production deployment has occurred.

- Added `public/legacy/attempt-storage.js`, a dedicated IndexedDB adapter with an account-scoped keyspace, a hydrated synchronous in-memory mirror for compatibility with the legacy exam engine, serialized writes, explicit flush support and observable write errors.
- The adapter migrates each signed-in user's legacy pointer and draft records, verifies the IndexedDB read-back against the source values, and removes only that user's old localStorage records after verification. Legacy records belonging to other accounts are retained.
- If IndexedDB is unavailable or migration cannot be verified, the old records are not deleted; the adapter enters a legacy-storage fallback and emits a visible error event. If a later IndexedDB write fails (including quota errors), the current record is also written to localStorage where possible and subsequent writes use that fallback. This is a compatibility/recovery fallback, not the normal storage path.
- The engine's existing offline restoration and server reconciliation logic remains intact. Dirty answers, question-time queue events, navigation state, deadline/pending-submit state and exam snapshot continue to be stored together in the attempt cache. Submitted results continue to be fetched from the server.
- Added source-contract tests for account-scoped migration, account switching, offline page-reload recovery, quota/fallback visibility, reconnect synchronization and pending submission; syntax checks cover the IndexedDB adapter and service worker. These tests and the production build must pass in CI before this migration is considered verified.
- Updated the legacy service worker to cache the IndexedDB adapter itself. Without this, a cached legacy exam shell could load offline but fail to initialize because its newly added same-origin storage script was not cached.
- IndexedDB records are not a substitute for server-side attempt records and may be cleared or evicted by the browser. The application must not claim that a draft is submitted until Supabase confirms submission.
