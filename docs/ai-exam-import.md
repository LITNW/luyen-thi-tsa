# TSA AI-assisted exam import

## Zero-additional-infrastructure-cost development path

- Develop on GitHub branch `feature/ai-import-center` (the initial foundation PR #5 has already been merged).
- Use the Vercel Preview Deployment for this branch; do not deploy to Production.
- Do not create a Supabase Development Branch (it can incur separate compute charges).
- The additive SQL migration was transaction-tested against the current Supabase project using `BEGIN ... ROLLBACK`; a follow-up catalog check confirmed no staging tables, bucket, or policies were left behind. Its filename was corrected to sort after the current production migration history.
- Keep the migration in GitHub for review. Apply it to the existing Supabase project only after a current backup and final validation.
- Reuse the existing Supabase project and Edge Functions rather than adding another hosted service.

This avoids the additional Supabase branch compute charge. Claude API usage may still be billed; show file/page limits and processing scope before model invocation.

## Design constraints

- `import_jobs` tracks each source file and processing run.
- `import_questions` is temporary staging only, not a second permanent Question Bank.
- `import_events` records processing and review events.
- Approved drafts must map into the existing `questions`, `question_versions`, `question_answer_keys`, and `exam_version_questions` model.
- Published exam versions remain immutable; edits create a new version.
- Source files and drafts remain private and Admin-only.
- AI must never invent answer keys. Missing or ambiguous keys remain null and require review.
- AI never publishes; Admin approval is mandatory.

## Workflow

1. Admin uploads a source file to private Storage.
2. Create an `import_jobs` row and upload event.
3. The server-side worker sends PDFs/images to Claude for visual extraction and passes TXT/Markdown/CSV as text; never expose Claude API credentials in browser code.
4. Validate against existing types `mc`, `ms`, `tf`, `num`, `dnd`.
5. Store drafts, source page ranges, confidence and validation flags.
6. Review question cards with a time-limited private source-file link and editable JSON for the question, options, answer key and explanation.
7. Admin approves selected questions and maps them into the existing question/version model.
8. Save as exam draft using existing Admin RPCs. Publishing remains a separate explicit action.

## Format strategy

“All formats” means a documented adapter matrix, not arbitrary binary-file support. Prioritize PDF (text and scanned), PNG/JPEG/WEBP/TIFF, DOCX, TXT/Markdown, CSV/XLSX, PPTX, Moodle XML, GIFT and QTI. Compatibility must be tested per question type. Unsupported elements must be flagged rather than silently discarded. Large files require bounded page batches and checkpoints.

## Security

- RLS is enabled and all import tables have Admin-only policies.
- The Storage bucket is private with Admin-only object policies.
- Any Edge Function must validate the caller JWT and active Admin role before using server credentials.
- Store model secrets in Supabase Function Secrets, never in `index.html`, public Vercel variables, or committed files.
- Current safeguards: 25 MB file-size limit, MIME signature checks, job-ownership checks, timeout and retry-safe draft upserts. Page batching and rate limiting are still outstanding.
- Record failures and allow safe retries without duplicating canonical questions.

## Status

- [x] Current production schema inspected read-only.
- [x] Existing Admin role and `is_admin()` helper verified.
- [x] Additive migration tested with transaction rollback.
- [x] Rollback verified: no staging tables, bucket or staging policies remain.
- [x] Feature branch created.
- [x] Admin Import Center UI added: upload without invoking AI, list jobs, explicit cost confirmation before Claude processing, edit JSON drafts, approve/reject and transfer approved questions into the existing exam editor.
- [ ] Apply migration after backup and final validation.
- [x] Add initial Admin-gated Edge Function source for PDF, common image formats, TXT, Markdown and CSV extraction.
- [ ] Complete preprocessing adapters for DOCX, XLSX, PPTX, TIFF, Moodle XML, GIFT and QTI.
- [x] Harden Admin authorization, job ownership, private-bucket path checks, MIME signature checks, atomic job claiming, timeout and idempotent question upserts.
- [ ] Add bounded PDF page batching, Edge Function runtime/type checks and representative file tests; deploy after migration and secrets are configured.
- [x] Add a time-limited signed link to the private source file and editable JSON review controls.
- [ ] Improve review with field-level controls and embedded page navigation.
- [x] Transfer approved drafts into the existing exam editor (saving/publishing still uses the existing Admin RPC flow).
- [ ] Test representative documents end-to-end.
