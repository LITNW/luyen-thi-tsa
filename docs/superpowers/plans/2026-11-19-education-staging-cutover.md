# Superseded: Education Staging cutover plan (2026-11-19)

<badge>SUPERSEDED — DO NOT EXECUTE</badge>

This plan was written for the earlier `education_subject_groups` / temporary-write-freeze implementation. PR #41's owner later replaced that design with Admin-managed course categories. The old migration and its six seeded category values are not approved for deployment.

Use these current documents instead:

- [Current course-category design](../specs/2026-11-19-education-course-classification-design.md)
- [Current Staging cutover runbook](../../education-course-classification-staging-cutover.md)
- [Current architecture and migration audit](../../architecture/education-course-classification-cutover.md)

The old plan's group-table names, fixed taxonomy, and temporary University write-freeze steps are historical only. Do not recreate those policies or apply the superseded migration.

Current release boundaries: Staging only after migration-history reconciliation and verified backup; PR #41 remains Draft/open; no Production schema/data changes, merge, or Production deployment.
