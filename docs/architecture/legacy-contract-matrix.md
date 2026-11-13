# Legacy RPC compatibility matrix for structured exams

Status: Design constraint; no RPC has been changed by this document.

## 1. Why this matrix is required

The current admin API is not just a read/write wrapper. Several RPCs reconcile or directly mutate the flat `exam_version_questions` collection. If section/group tables are added without guarding those RPCs, an old save or reorder operation can silently detach group membership or delete question mappings that a new layout references.

The database therefore needs an explicit layout discriminator before structured exams are introduced.

## 2. Layout discriminator

Add an additive field to `exam_versions` in a later migration:

- `content_model_version smallint NOT NULL DEFAULT 1`
- allowed values: `1` (legacy flat layout), `2` (structured sections/groups)

Rules:
- Existing rows receive version 1; this does not reinterpret their content.
- Only draft exam versions may change this field.
- A v2 structured save sets the field to 2 in the same transaction that creates/updates sections and items.
- Published exam versions remain immutable under the existing `protect_exam_version` trigger.
- An exam version cannot move from 2 back to 1 once any structured rows exist.
- A v2 exam must not be edited through a legacy flat RPC.

This discriminator is part of the persisted exam-version contract, not a frontend-only flag.

## 3. RPC compatibility matrix

| Existing RPC | Current behavior | Risk after structured layout exists | Required compatibility rule |
|---|---|---|---|
| `get_published_exam` | Returns a flat `questions` array | Cannot express shared stimulus/group structure | Keep its v1 response unchanged; reject v2 or route v2 clients to `get_published_exam_v2` |
| `admin_get_exam_version` | Returns flat question list including answer keys | Admin editor cannot reconstruct sections/groups | Keep for v1; add `admin_get_exam_structure_v2` |
| `admin_save_exam_content` | Reconciles `p_questions`, inserts/replaces/deletes flat mappings | Can delete mappings referenced by structured items | Explicitly reject `content_model_version = 2` before any write |
| `admin_add_question_to_exam` | Appends a mapping and flat position | Creates an unplaced mapping in v2 | Restrict to v1; v2 writes through structure RPC |
| `admin_remove_question_from_exam` | Deletes a mapping | Can leave an empty or invalid group item | Restrict to v1; v2 removal updates item membership transactionally |
| `admin_replace_question_in_exam` | Replaces question version on a mapping | Can violate group-version membership | Restrict to v1; v2 replacement validates group membership |
| `admin_reorder_exam_questions` | Reorders flat mapping positions | Does not reorder section/group hierarchy | Restrict to v1; v2 reorders section items and group children |
| `admin_update_question_points` | Changes points on a mapping | Potentially safe for mapping, but must preserve draft and group context | May remain usable only if it verifies v2 mapping membership and draft status; otherwise expose v2 equivalent |
| `admin_create_exam_version` | Clones exam version and flat question mappings | New version would omit section/group structure | For v1 only; add v2 clone path that remaps every copied `exam_version_question.id` into new section-item child rows |
| `admin_delete_exam_version` | If no attempts, deletes `exam_version_questions` before `exam_versions`; otherwise archives | New section-item child rows can RESTRICT deletion of mappings | Delete draft-owned section/item/child rows before deleting mappings; keep reusable group/stimulus versions; preserve attempt-aware archive behavior |
| `admin_publish_exam_version` | Validates answer keys and publishes a flat mapping set | Does not validate section/item/group completeness | Branch by `content_model_version`; v2 publication also validates complete structure and group membership |
| `list_published_exams` | Returns published exam cards and question count; no content-model version | Client may route v2 exam to legacy runtime | Add `content_model_version` to the card payload or a compatible v2 listing RPC |
| `start_exam_attempt` | Creates attempt using `exam_version_questions` and total points | No inherent issue if every v2 question still has a mapping | Keep mapping-based behavior; route to v2 runtime before loading the attempt |
| `save_attempt_answer` | Saves answer by mapping ID and attempt | No inherent issue | Preserve signature and owner/deadline checks |
| `record_attempt_question_time_v2` | Records timing by mapping ID | No inherent issue | Preserve mapping IDs and idempotency |
| `submit_exam_attempt` | Scores each mapping by question type | Structure does not change scoring identity | Keep mapping iteration; later refactor type grading separately |
| `get_my_attempt_state` / history RPCs | State returns exact `exam_version_id`, answers, timing, and post-submit results; it does not return layout version | Resume flow may reopen a v2 attempt in the legacy renderer | Include `content_model_version` from the attempt's exact `exam_version_id`; preserve existing answer/timing fields and history payload shape where possible |

## 4. Required v2 RPC set

Introduce new RPCs rather than overloading a flat JSON contract:

- `get_published_exam_v2(p_exam_version_id uuid)`
- `admin_get_exam_structure_v2(p_exam_version_id uuid)`
- `admin_save_exam_structure_v2(...)`
- `admin_create_exam_version_v2(p_exam_id uuid)`

The exact parameter lists must be finalized after the frontend payload contract and transactional write algorithm are reviewed.

### `admin_save_exam_structure_v2` transaction requirements

1. Authenticate and verify admin.
2. Lock the target `exam_versions` row.
3. Require draft status and set `content_model_version = 2`.
4. Validate section ordering and optional section duration rules.
5. Validate each top-level item type and group-version reference.
6. Validate every question-group member against the corresponding `exam_version_questions.question_version_id`.
7. Reuse existing mapping IDs when the same question version remains in the same exam version.
8. Create mappings for new questions and remove only mappings intentionally removed from the draft.
9. Ensure every mapping appears exactly once in `exam_section_item_questions`.
10. Validate answer keys for every question.
11. Validate total item count and score limits.
12. Commit all structure and mapping changes atomically.

A failed save must roll back the entire operation.

## 5. Publication validation

For `content_model_version = 2`, publication must additionally assert:

- At least one section exists.
- Every section has a valid positive order and belongs to the same exam version.
- Every section item has a valid type and positive order.
- Every standalone item has exactly one mapped question.
- Every group item has at least one mapped question.
- The group item's ordered mapped question versions exactly equal the ordered membership in the referenced group version.
- Every `exam_version_questions` mapping appears exactly once in the section tree.
- No section item references a question mapping from another exam version.
- All answer keys pass the current type validator.
- Every referenced stimulus/group/question version is immutable and available.

Only after these assertions pass may the version transition to published.

## 6. Version cloning and deletion

### Clone
A v2 clone creates:
- a new `exam_versions` row with `content_model_version = 2`
- new `exam_version_questions` rows (new mapping IDs are required because the exam version changes)
- copied sections and top-level items
- copied `exam_section_item_questions` rows remapped to the new mapping IDs

It reuses immutable question, group, and stimulus versions. It does not copy answer keys or mutate question content. The current `admin_create_exam_version` copies only flat question mappings, so it must remain v1-only; a v2 clone must remap the entire layout.

### Delete/archive
- The current delete RPC removes `exam_version_questions` before `exam_versions`. For v2, it must first remove the draft-owned section/item/child rows (or use a verified cascade order), then mappings. Draft-only child structure can cascade with the draft exam version if no attempt references it.
- Group and stimulus versions are reusable assets and must not cascade-delete with an exam.
- Published versions with attempts are archived under existing safeguards, not hard-deleted.
- Deletion tests must include a draft v2 exam, a published v2 exam with no attempts, and a published v2 exam with attempts.

## 7. Runtime routing

The dashboard/attempt-resume flow must route by persisted `content_model_version`:
- v1 → current legacy flat exam runtime
- v2 → structured exam runtime

An in-progress attempt must always reopen the renderer compatible with the attempt's exact exam version. Do not infer runtime from current application defaults or from the latest version of the parent exam.

## 8. Test gates

- Each legacy flat RPC rejects v2 mutation before writing any row.
- Each v2 RPC rejects v1 or published versions where appropriate.
- A failed v2 save leaves all rows unchanged.
- v2 clone preserves section order, item order, group membership, question versions, and points while creating new mapping IDs.
- v2 publish rejects incomplete/duplicate/unplaced mappings and invalid group membership.
- Existing v1 exam read/save/publish/attempt behavior remains byte-for-byte compatible at the JSON contract boundary where practical.
- Existing attempt-answer and timing foreign keys remain valid after clone and structured saves.
