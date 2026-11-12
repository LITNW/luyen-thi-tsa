# React migration — baseline audit

Audit date: 2026-11-12  
Repository: `LITNW/luyen-thi-tsa`  
Production baseline: `main` at `718503d99cd2215d72ad5e6fd70c4e936d72e683`  
Working branch: `feature/react-migration` (created from that exact commit)

## Production and repository

- Vercel project: `luyen-thi-tsa-s9y7`.
- Latest Production deployment observed: READY, sourced from `main` at the baseline SHA above.
- The `main` deployment status check reported success.
- The app is currently a single `index.html` application (about 137 KB); it has no package manifest, Vite config, React Router, or tracked Vercel SPA config.
- Main's HTML has balanced script tags and no non-whitespace content after the closing `</html>`.
- The existing app contains authentication, dashboard, authoring, matching, timed attempts, recovery/sync, history/results, PDF/DOCX parsing, MathJax rendering, and AI import integration. Keep this implementation available until each replacement module passes tests.
- The AI import code invokes the Supabase Edge Function `tsa-import-process`; the function source exists in Git, but the Supabase project inventory returned no deployed Edge Functions. Verify deployment status before relying on AI import in a new client.

## Branch and pull-request audit

- The default branch is `main`.
- Existing branches include multiple feature/fix branches and `supabase-migration`; several are substantially behind or have diverged from current `main`.
- `feature/ai-exam-import`, `feature/ai-import-center`, and `ui-redesign` are behind current `main` with no unique commits in the compare result.
- Matching, parser, LaTeX, and hotfix branches have unique commits but also substantial divergence. Do not merge them wholesale; selectively port only verified changes that are still absent from current main.
- PR #18 is open and targets the old `supabase-migration` branch. Its head is based on an older, smaller HTML application. Its 128-line deletion must not be merged into current main as a blanket fix. Current main already ends cleanly after its final script and HTML close.
- No existing branch or PR was merged as part of this migration.

## Supabase production baseline

Project: `tsa-practice` (`hwqtsopvpucadgpkigqz`), region `ap-southeast-1`, status `ACTIVE_HEALTHY`.

The database inventory contains 13 public tables with existing data. Counts observed during audit:

| Table | Rows |
|---|---:|
| profiles | 1 |
| exams | 3 |
| exam_solutions | 1 |
| attempts | 13 |
| audit_logs | 3 |
| exam_versions | 8 |
| questions | 119 |
| question_versions | 231 |
| question_answer_keys | 231 |
| exam_version_questions | 318 |
| attempt_answers | 6 |
| attempt_question_times | 46 |
| attempt_question_time_events | 245 |

RLS is enabled on all 13 tables in the inventory. Do not expose answer-key tables or add direct student reads. The React client uses the existing public RPC for published exam metadata and retains server-side grading.

The Supabase migration ledger reports 17 applied versions. The current GitHub main tree contains only four SQL migration files, with timestamps/names that do not correspond one-to-one to the live ledger. Treat this as migration-history drift. Do not run, replay, squash, or regenerate production migrations until the live schema and repository history have been reconciled.

Security advisor findings observed:
- Three RLS-enabled tables have no direct policies: `attempt_question_time_events`, `exam_solutions`, and `question_answer_keys`. This may be intentional where access is mediated by trusted RPCs; verify function paths before changing.
- 31 SECURITY DEFINER functions are executable by authenticated users. Review each function's internal authorization checks and grants; the advisor warning alone is not proof that each is exploitable.
- Two foreign keys on `attempt_question_time_events` lack covering indexes.
- 18 indexes are currently unused in the observed workload. Do not remove them based on a low-volume sample.

## Environment and secrets

- Existing Vercel production environment contains server/database credentials and Supabase service/secret keys. They must never enter a Vite bundle, Git, or browser storage.
- Only the existing public Supabase URL and publishable key were copied into Preview-scoped Vite variables for branch `feature/react-migration`.
- No Production environment variable was changed by this migration setup.
- No Supabase schema, data, RLS policy, RPC, storage bucket, or Edge Function was modified during the baseline audit.

## Migration safety rules

1. Keep `main` and the current Production deployment unchanged until a reviewed PR is merged.
2. Keep the existing app at `/legacy/index.html` during the transition; it is the rollback and functional fallback for modules not yet ported.
3. Do not duplicate the database or move answer keys to the browser.
4. Use existing RPCs and RLS; the browser receives only public exam metadata.
5. Migrate auth/dashboard first. Migrate exam authoring/import and the exam engine only after dedicated parity tests.
6. Preserve attempt snapshots, server-authoritative timing, idempotent submission, and historical results.
7. Treat all future database changes as separate, backward-compatible migrations after migration-ledger reconciliation.
