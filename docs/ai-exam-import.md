# TSA AI-assisted exam import

## Zero-additional-infrastructure-cost development path

- Develop on GitHub branch `feature/ai-exam-import`.
- Use the Vercel Preview Deployment for this branch; do not deploy to Production.
- Do not create a Supabase Development Branch (it can incur separate compute charges).
- The additive SQL migration was transaction-tested against the current Supabase project using `BEGIN ... ROLLBACK`; a follow-up catalog check confirmed no staging tables, bucket, or policies were left behind.
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
3. Extract text/OCR on a server-side worker; never expose Claude API credentials in browser code.
4. Validate against existing types `mc`, `ms`, `tf`, `num`, `dnd`.
5. Store drafts, source page ranges, confidence and validation flags.
6. Review in a three-pane workspace: question list, source preview, editable question/answer.
7. Admin approves selected questions and maps them into the existing question/version model.
8. Save as exam draft using existing Admin RPCs. Publishing remains a separate explicit action.

## Format strategy

“All formats” means a documented adapter matrix, not arbitrary binary-file support. Prioritize PDF (text and scanned), PNG/JPEG/WEBP/TIFF, DOCX, TXT/Markdown, CSV/XLSX, PPTX, Moodle XML, GIFT and QTI. Compatibility must be tested per question type. Unsupported elements must be flagged rather than silently discarded. Large files require bounded page batches and checkpoints.

## Security

- RLS is enabled and all import tables have Admin-only policies.
- The Storage bucket is private with Admin-only object policies.
- Any Edge Function must validate the caller JWT and active Admin role before using server credentials.
- Store model secrets in Supabase Function Secrets, never in `index.html`, public Vercel variables, or committed files.
- Enforce file-size/page limits, MIME sniffing, timeouts, rate limits and idempotency.
- Record failures and allow safe retries without duplicating canonical questions.

## Status

- [x] Current production schema inspected read-only.
- [x] Existing Admin role and `is_admin()` helper verified.
- [x] Additive migration tested with transaction rollback.
- [x] Rollback verified: no staging tables, bucket or staging policies remain.
- [x] Feature branch created.
- [ ] Apply migration after backup and final validation.
- [x] Add initial Admin-gated Edge Function source for PDF, common image formats, TXT, Markdown and CSV extraction.
- [ ] Complete preprocessing adapters for DOCX, XLSX, PPTX, TIFF, Moodle XML, GIFT and QTI.
- [ ] Harden page batching, retry/idempotency and error-state handling; deploy the Edge Function after migration and secrets are configured.
- [ ] Build upload UI, Import Center and source-linked review editor.
- [ ] Connect approved drafts to the existing exam-version RPC flow.
- [ ] Test representative documents end-to-end.
