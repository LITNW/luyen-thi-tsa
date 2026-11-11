-- TSA AI-assisted exam import: additive staging layer only.
-- Does not alter the live question bank or published exam versions.
-- Apply only after reviewing this migration and confirming a current backup.

create table public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete restrict,
  target_exam_id uuid null references public.exams(id) on delete set null,
  target_exam_version_id uuid null references public.exam_versions(id) on delete set null,
  original_filename text not null,
  mime_type text not null,
  file_size_bytes bigint not null check (file_size_bytes > 0),
  storage_bucket text not null default 'tsa-imports',
  storage_path text not null,
  sha256 text null check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  source_format text not null,
  status text not null default 'uploaded'
    check (status in ('uploaded','queued','processing','needs_review','approved','published','failed','cancelled')),
  processing_stage text null,
  page_count integer null check (page_count is null or page_count >= 0),
  progress_percent smallint not null default 0 check (progress_percent between 0 and 100),
  provider text null,
  model text null,
  error_code text null,
  error_message text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz null,
  completed_at timestamptz null,
  approved_at timestamptz null,
  approved_by uuid null references public.profiles(id) on delete set null,
  constraint import_jobs_storage_path_unique unique (storage_bucket, storage_path),
  constraint import_jobs_target_version_exam_check check (target_exam_version_id is null or target_exam_id is not null)
);
create index import_jobs_created_by_created_at_idx on public.import_jobs (created_by, created_at desc);
create index import_jobs_status_created_at_idx on public.import_jobs (status, created_at desc);

create table public.import_questions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.import_jobs(id) on delete cascade,
  ordinal integer not null check (ordinal > 0),
  status text not null default 'needs_review'
    check (status in ('extracted','needs_review','approved','rejected','imported')),
  question_type text null check (question_type is null or question_type in ('mc','ms','tf','num','dnd')),
  content jsonb not null default '{}'::jsonb,
  answer_key jsonb null,
  explanation text null,
  points numeric(8,2) not null default 1 check (points > 0),
  source_page_start integer null check (source_page_start is null or source_page_start > 0),
  source_page_end integer null check (source_page_end is null or source_page_end > 0),
  source_location jsonb not null default '{}'::jsonb,
  confidence jsonb not null default '{}'::jsonb,
  validation_flags jsonb not null default '[]'::jsonb,
  source_metadata jsonb not null default '{}'::jsonb,
  imported_question_id uuid null references public.questions(id) on delete set null,
  imported_question_version_id uuid null references public.question_versions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint import_questions_job_ordinal_unique unique (job_id, ordinal),
  constraint import_questions_page_range_check check (source_page_start is null or source_page_end is null or source_page_end >= source_page_start),
  constraint import_questions_import_pair_check check (imported_question_version_id is null or imported_question_id is not null)
);
create index import_questions_job_status_ordinal_idx on public.import_questions (job_id, status, ordinal);

create table public.import_events (
  id bigint generated always as identity primary key,
  job_id uuid not null references public.import_jobs(id) on delete cascade,
  actor_id uuid null references public.profiles(id) on delete set null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index import_events_job_created_at_idx on public.import_events (job_id, created_at);

alter table public.import_jobs enable row level security;
alter table public.import_questions enable row level security;
alter table public.import_events enable row level security;

create policy import_jobs_admin_all on public.import_jobs for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy import_questions_admin_all on public.import_questions for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy import_events_admin_all on public.import_events for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tsa-imports', 'tsa-imports', false, 26214400, null)
on conflict (id) do nothing;

create policy tsa_imports_admin_select on storage.objects for select to authenticated
  using (bucket_id = 'tsa-imports' and (select public.is_admin()));
create policy tsa_imports_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'tsa-imports' and (select public.is_admin()));
create policy tsa_imports_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'tsa-imports' and (select public.is_admin()))
  with check (bucket_id = 'tsa-imports' and (select public.is_admin()));
create policy tsa_imports_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'tsa-imports' and (select public.is_admin()));