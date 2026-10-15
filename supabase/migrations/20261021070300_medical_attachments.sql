-- Medical records, step 7 (4/4): files attached to a visit (docs/ho-so-benh-an.md, section 4).
-- Safe to run more than once.
--
-- Before: a lab result, an X-ray or a consent form has nowhere to go.
-- After: staff with the medical permission attach images and PDFs (10 MB at most) to a visit, in a
-- private bucket, and read them through short-lived signed links. The path is
-- <pet id>/<visit id>/<uuid>.<ext>. Attachments can be added after the visit is signed (results
-- arrive later); removing one needs the same permission.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medical', 'medical', false, 10485760,
  array['image/png', 'image/jpeg', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "medical: read" on storage.objects;
create policy "medical: read" on storage.objects for select to authenticated
  using (bucket_id = 'medical' and (select public.can_medical('VIEW')));

drop policy if exists "medical: upload" on storage.objects;
create policy "medical: upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'medical' and (select public.can_medical('UPDATE')));

drop policy if exists "medical: delete" on storage.objects;
create policy "medical: delete" on storage.objects for delete to authenticated
  using (bucket_id = 'medical' and (select public.can_medical('UPDATE')));

create table if not exists public.medical_attachments (
  id              uuid primary key default gen_random_uuid(),
  visit_id        uuid not null references public.medical_visits(id) on delete cascade,
  pet_id          uuid not null references public.pets(id) on delete restrict,
  kind            text not null check (kind in ('lab', 'imaging', 'photo', 'consent', 'other')),
  title           text not null check (length(btrim(title)) > 0),
  file_path       text not null unique,
  mime_type       text not null,
  size_bytes      bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text,
  created_at      timestamptz not null default now()
);
create index if not exists medical_attachments_visit_idx on public.medical_attachments (visit_id, created_at);
create index if not exists medical_attachments_pet_idx on public.medical_attachments (pet_id, created_at desc);

alter table public.medical_attachments enable row level security;

drop policy if exists "medical read" on public.medical_attachments;
create policy "medical read" on public.medical_attachments for select to authenticated
  using ((select public.can_medical('VIEW')));

revoke insert, update, delete on public.medical_attachments from anon, authenticated;
revoke all on public.medical_attachments from anon;

-- The files of a visit, oldest first.
create or replace function public.list_medical_attachments(p_visit uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'visit_id', a.visit_id, 'kind', a.kind, 'title', a.title, 'file_path', a.file_path,
      'mime_type', a.mime_type, 'size_bytes', a.size_bytes, 'created_by_name', a.created_by_name,
      'created_at', a.created_at
    ) order by a.created_at, a.id)
    from public.medical_attachments a where a.visit_id = p_visit
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.list_medical_attachments(uuid) from public, anon;
grant execute on function public.list_medical_attachments(uuid) to authenticated;

-- Registers a file the client already uploaded to the bucket.
-- p: { kind, title, file_path, mime_type, size_bytes }. Returns the attachment id.
create or replace function public.add_medical_attachment(p_visit uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_visit public.medical_visits;
  v_path  text := btrim(coalesce(p ->> 'file_path', ''));
  v_id    uuid;
begin
  select * into v_visit from public.medical_visits where id = p_visit;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status in ('cancelled', 'no_show', 'scheduled') then
    raise exception 'the visit cannot take files' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_path not like v_visit.pet_id::text || '/' || v_visit.id::text || '/%' then
    raise exception 'bad file path' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.medical_attachments (
    visit_id, pet_id, kind, title, file_path, mime_type, size_bytes, created_by, created_by_name
  ) values (
    v_visit.id, v_visit.pet_id, coalesce(nullif(p ->> 'kind', ''), 'other'),
    btrim(coalesce(p ->> 'title', '')), v_path, coalesce(p ->> 'mime_type', ''),
    coalesce(nullif(p ->> 'size_bytes', '')::bigint, 0), v_uid, public.staff_display_name(v_uid)
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.add_medical_attachment(uuid, jsonb) from public, anon;
grant execute on function public.add_medical_attachment(uuid, jsonb) to authenticated;

-- Removes the row and returns the path so the client can delete the file.
create or replace function public.remove_medical_attachment(p_id uuid) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.medical_attachments;
  v_branch uuid;
begin
  select * into v_row from public.medical_attachments where id = p_id for update;
  if not found then
    raise exception 'file not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select branch_id into v_branch from public.medical_visits where id = v_row.visit_id;
  if not public.can_medical('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.medical_attachments where id = p_id;
  return v_row.file_path;
end;
$$;

revoke execute on function public.remove_medical_attachment(uuid) from public, anon;
grant execute on function public.remove_medical_attachment(uuid) to authenticated;

notify pgrst, 'reload schema';
