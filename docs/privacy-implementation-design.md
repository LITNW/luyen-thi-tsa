# LIT — Privacy Implementation Design

Status: **Draft for operator decisions and technical/legal review**  
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

## 2. Proposed purpose inventory — operator confirmation required

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

**OPEN:** The operator must confirm which purposes LIT intends to support. The proposed minimum scope is account/service, learning history, security, support/privacy requests, and parent confirmation only. Marketing and AI processing of personal data remain off; AI import may process administrator-supplied source material only after its own review.

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
3. Supabase Auth signup consumes a one-time registration token. The Auth user trigger validates and consumes the matching intent; a missing, expired, replayed or mismatched token rejects registration.
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
| Auth identity/profile | Supabase Auth and `profiles` | While account is active; delete/anonymize after closure unless a documented exception applies | **OPEN** |
| Attempts, answers, timing and results | Supabase learning tables; legacy browser cache | Retain only while needed for learning history; provide deletion/anonymization path | **OPEN** |
| Security/admin audit logs | Supabase `audit_logs`, provider telemetry | Minimize fields; restrict access; fixed retention and incident/legal-hold exceptions | **OPEN** |
| Sessions and hosting/Worker logs | Supabase Auth, Cloudflare and possibly Vercel | Provider-specific retention; do not assume the application controls provider logs | **OPEN** |
| Import source files and job metadata | Private Supabase Storage and import tables | Delete source files after a defined processing/review period; retain only approved canonical question content where justified | **OPEN** |
| Consent and parent-confirmation evidence | Proposed private consent tables | Preserve versioned evidence for the legally justified period; restrict access and deletion | **OPEN** |
| Privacy requests | Proposed request register/email mailbox | Retain until fulfilled plus a justified dispute/accountability period | **OPEN** |

No automatic deletion job should be implemented until the operator approves durations and legal review confirms any required minimum periods or exceptions.

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

1. **Decision gate:** confirm purpose scope, optional purposes, retention durations, transactional email method, and public operator identity wording.
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
- **OPEN — Purpose scope and legal bases:** the operator must approve the actual processing purposes; counsel must validate the applicable legal bases and notice/consent wording.
- **OPEN — Retention periods:** durations must be chosen per data class and checked against applicable obligations.
- **OPEN — Transactional email:** no provider/configuration is confirmed for parent-confirmation email.
- **OPEN — Cloudflare log scope and localization:** the separate Worker's relation to the Pages runtime and Customer Metadata Boundary setting are unknown.
- **OPEN — Legal review:** current consolidated Vietnamese instruments and the under-16 design require qualified review before publication/release.
- **BLOCKED — Production:** no Production schema/configuration change or public compliance claim is authorized by this design.
