# LIT browser storage and database audit

**Audit date:** 2026-11-23

**Scope:** PR #33 review, repository storage behavior, and read-only Supabase Staging/Production inspection.

**Safety:** No Supabase schema, data, Auth, Storage, secrets, or deployment settings were changed. Production was read-only.

## Summary

PR #33 is still an open Draft, based on `main`, with head `1245adecde53e149e0398ee2a9cf1029892345b2`. It already contains the account-scoped IndexedDB adapter for legacy active exam drafts. This work reuses that adapter; it does not create another exam cache or alter draft migration/recovery.

The additional change in this branch limits the React app's same-origin public static asset cache to at most 80 entries and a measured `Content-Length` sum of 8 MiB, with each asset capped at 512 KiB. It only admits JavaScript, CSS, fonts, and SVG under `/assets/` and `/brand/`. Media, unknown-size responses, `no-store`, authenticated, and range requests are not cached. The service worker cache version is bumped so its existing activation cleanup removes the earlier unbounded cache.

This bounds the app-managed static cache. It does **not** prove that this device previously used more than 8 MiB or that this change reduced the user's actual browser storage. Actual before/after browser storage, memory, CPU, and network measurements could not be read through the available browser interface. No local-load reduction is claimed.

## PR #33 and client storage findings

- PR #33, “feat(privacy): add browser storage controls and cookie preferences,” remains Draft and open. Its base is `main` at `dfb3edd432cd498b52411373cad45760da62eded`; PR #40's merged media-editor and archive safeguards are present in that base.
- `public/legacy/attempt-storage.js` scopes drafts to the signed-in account, verifies IndexedDB writes before removing only that account's legacy localStorage records, serializes writes, and preserves an observable localStorage fallback on IndexedDB errors or quota failures.
- Active draft recovery keeps unsent answers, question timing, navigation, exam snapshot, and pending-submit state on-device until the server confirms completion. Submitted answers and results remain server-authoritative. This data must not be deleted by a general TTL cleanup.
- The main React exam list fetches summary data; the legacy exam runtime fetches one exam payload when an attempt starts. Exam and API responses are not placed in Cache Storage. Exam media is rendered with lazy loading. Private media remains in Supabase Storage and is not service-worker cached.
- `public/sw.js` was the active root-scope service worker. Before this change it cached eligible same-origin static URLs on demand, with an 80-entry count limit but no byte limit or response type check. It did not precache the question bank. `public/legacy/sw.js` caches the legacy shell, its IndexedDB adapter, and the pinned Supabase JS client; it does not cache exam API responses or media.
- Supabase JS Auth persists its session using the SDK's browser storage. Consent preferences are a small versioned localStorage value. Optional preference/page-state data and analytics are not currently written.
- `src/lib/browser-storage.js` defines a separate TTL-bounded IndexedDB helper, but its temporary-record put/get APIs have no current product callers. It should not be treated as active exam storage or used to clean exam drafts.

## Browser storage budget and change

| Area | Current policy after this branch | Preservation rule |
|---|---|---|
| Public static Cache Storage | On-demand only; 80 entries max; 8 MiB sum of response `Content-Length` headers max; 512 KiB max per response | Only JS, CSS, font, SVG under `/assets/` or `/brand/`; the cap is a cache-policy estimate, not a measurement of physical quota usage |
| Exam media | No Cache Storage; images are lazy-loaded in the page | Do not retain private media offline by default |
| Exam drafts | Existing account-scoped IndexedDB adapter from PR #33 | Keep until confirmed submitted/otherwise resolved by server; preserve pending offline work and quota fallback |
| localStorage | Small privacy preference plus Supabase Auth SDK session; attempt data only as fallback/migration source | Do not indiscriminately clear; remove migrated records only after read-back verification |
| Temporary helper DB | TTL is supported by helper but no active product writes were found | No runtime cleanup added because it would add startup work for an unused store |

The browser's quota estimate covers the whole origin and may include other browser-managed data. Cache metadata overhead and compressed responses mean the service worker's byte accounting is not an exact physical disk measurement. A real browser quota check remains required after deployment.

## Read-only database and Storage audit

Both projects reported PostgreSQL 17.11 and approximately 15 MB database size. All inspected `public` tables had RLS enabled.

| Finding | Staging `cppalwtdkditlhojpeyc` | Production `hwqtsopvpucadgpkigqz` |
|---|---:|---:|
| Public tables | 27 | 25 |
| Applied migration ledger entries | 39 | 31 |
| Attempts | 6 | 18 |
| Question versions | 42 | 271 |
| Exam-version questions | 43 | 358 |
| Attempt question-time events | 19 | 341 |
| Storage objects | 0 | 0 |
| Private Storage buckets | `tsa-imports` (25 MiB), `lit-question-media` (10 MiB) | `tsa-imports` (25 MiB) |

The project ledgers are not aligned. Staging includes a reconstructed baseline and Staging-specific/restamped entries, question-media/stimulus additions, and the no-physical-delete archive migration. Production has a separate temporary exam-version delete-revocation migration. The repository has 36 migration files; Staging and Production history must not be assumed to be interchangeable. This branch adds no migration.

Supabase advisor findings remain open and were not changed:

- Performance: 11 unindexed foreign keys in each project; prior advisor snapshot also showed unused-index warnings (19 Staging, 31 Production). The small table counts and short/limited workload history do not justify dropping indexes or adding a broad index set without query evidence.
- Security: RLS is enabled with no policies on 4 Staging tables and 3 Production tables. This is deny-by-default; several tables hold answer keys or server-managed events and may intentionally be RPC-only. Review each table/API access path before adding policies.
- Security: 40 `SECURITY DEFINER` functions are callable by the `authenticated` role in the advisor snapshot; verify each function's internal authorization and grants against the existing ACL design.
- Auth: leaked-password protection is disabled in both project advisory results.
- Staging has a private `lit-question-media` bucket that Production does not have; both projects currently have zero objects. Keep environment-specific configuration separate.
- Existing query telemetry was insufficient to identify real student query bottlenecks. PostgreSQL remains the source of truth; current size/usage does not support a second database or Redis/ClickHouse.

## Verification and limits

- Added three Node built-in tests for the worker's allowed content types, per-asset size cap, 8 MiB byte-budget eviction, 80-entry eviction, and exclusion of media/private/unknown-size/authenticated/range responses.
- Full suite: 54/54 passed on Node 26.13.0. Vite production build passed: 102 modules; emitted app bundles were each below the 512 KiB per-asset cache limit.
- Cloudflare Pages created a Preview deployment for commit `486aef7d5ea1511d31de0e59e9b44c5a823316a2`, but its status remained `queued` with only “Starting build…” in the deployment log during this run. The Staging Preview was therefore not available for final deployed-browser verification.
- A prior preview page loaded, but browser-side storage estimates and repeat-load transfer/CPU/RAM timings were not available from the approved browser interface. Its in-app browser profile also was not the user's own browser profile. Collect those values against the same Staging account, route, and browser profile before saying local load decreased.
- No real learner account, exam submission, or user attempt data was used for browser checks.

## Staging rollout and rollback

Cloudflare Pages Preview is documented as mapped to the Supabase Staging project; `main` is Production. A preview deployment of this feature branch changes the Staging-connected preview only. No Supabase migration or Staging database mutation is needed for this code change.

Rollback is to redeploy/revert the previous Staging Preview revision. The old service worker activation path cleans caches by version; reverting the worker script restores the previous cache behavior. Because there is no database change, no schema rollback or data repair is required. Do not merge this branch or deploy to Production without separate approval.

## Measurement needed for acceptance

Capture a baseline and a post-deployment reading in the same browser profile and Staging route:

1. `navigator.storage.estimate()` usage/quota and `localStorage` key count/UTF-8 bytes.
2. Cache Storage names, entry count, and summed `Content-Length` headers.
3. Resource transfer bytes and request count for the same cold and warm page load.
4. A repeatable browser performance trace and memory sample for the same route; include an exam flow only with a disposable Staging test account and approved test data.

Compare cold load to cold load and warm load to warm load. Report measurement conditions and actual readings. Do not infer reduced CPU, RAM, or network use from a storage cap alone.
