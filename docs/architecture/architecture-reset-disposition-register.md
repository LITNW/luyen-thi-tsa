# KEEP / MODIFY / REPLACE / REMOVE Register

Audit baseline: 2026-11-13. This is a controlled disposition register, not permission to drop Production objects.

| Object / capability | Decision | Reason / target action | Removal gate |
|---|---|---|---|
| profiles, auth and role checks | KEEP | Core identity and authorization | Never in this project |
| exams stable identity | KEEP | Preserve all existing exam IDs and references | Never as part of hierarchy reset |
| exam_versions | KEEP | Version/publish/archive history | Never as part of hierarchy reset |
| questions, question_versions, answer keys | KEEP | Core assessment content and grading | Never as part of hierarchy reset |
| exam_version_questions | KEEP | Stable question mapping within versions | Never as part of hierarchy reset |
| attempts, attempt_answers | KEEP | Student history and grading records | Never as part of hierarchy reset |
| attempt_question_times, attempt_question_time_events | KEEP | Timing and event history | Never as part of hierarchy reset |
| exam_solutions | KEEP | Solution content | Reassess only with separate product decision |
| subjects | MODIFY | Canonical subject catalogue; link through education_subjects | Not a removal candidate |
| taxonomy_nodes | KEEP | Optional question-level taxonomy, not navigation hierarchy | Only after explicit product decision and usage audit |
| question_version_taxonomy | KEEP | Optional classification of questions | Only after explicit product decision and usage audit |
| stimuli, stimulus_versions | KEEP | Shared passage/table/chart/dataset/image content | Not removed merely because currently empty |
| exam_categories | MODIFY | Optional purpose/type metadata, never education hierarchy | Only if product later rejects optional metadata |
| exams.category_id | MODIFY / KEEP | Nullable optional metadata link; not mandatory and not navigation key | Only after a separate metadata deprecation decision |
| category management screen | MODIFY | Rename/reframe as optional exam-purpose metadata; remove from primary Student journey | After replacement Admin UI is live |
| category-aware editor RPC | REPLACE | New authoring contract writes education_subject_id and optional metadata separately | After new editor and RPC parity |
| category list / category assignment RPCs | MODIFY | Keep only where needed for optional metadata; no Student navigation dependency | After reference scan and compatibility window |
| DashboardPage flat exam grid | REPLACE | Education-level landing page and data-driven hierarchy | After new navigation E2E passes |
| list_published_exams flat list for home | REPLACE for home | New scoped RPCs return level/context/subject navigation; legacy RPC may remain for compatibility | After all consumers migrated |
| legacy exam room | KEEP | Existing validated exam experience and history compatibility | Only after full parity and explicit retirement PR |
| legacy editor / AI import | MODIFY, then REPLACE | Keep during transition; port validated behaviors to new authoring UI | After all question types/import/publish tests pass |
| import_jobs/import_questions/import_events | KEEP | Import workflow and audit trail | Separate review only |
| migration recovery manifest | MODIFY | Align status with verified Production migration ledger | No runtime impact |
| unused M1 data tables | KEEP provisionally | Zero rows do not prove lack of future utility; no need to drop them for UI redesign | Separate evidence-based decision |
| old RPCs / triggers | REVIEW individually | Some may be compatibility wrappers or shared dependencies | Only after dependency scan, tests and rollback window |

## Non-negotiable deletion constraints

- Never delete or regenerate existing exam, version, question, answer-key, attempt, answer or timing identifiers.
- Never cascade-delete historical attempt records to remove a category or education node.
- Never make a Production column NOT NULL until every affected row is valid and the constraint has been proven on Staging.
- Prefer archive/deactivate semantics for education nodes referenced by exams.
- A database object can be retired from UI use before it is physically dropped.
- Physical removal requires a separate migration and separate review.
