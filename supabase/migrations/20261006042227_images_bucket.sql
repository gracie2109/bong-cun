-- Public-read image bucket. Files are served by URL to anyone, but there is no
-- anonymous SELECT policy, so the bucket cannot be listed. Writes are limited to
-- signed-in users and only inside their own `<uid>/` folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'images', 'images', true, 5242880,
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "images: upload into own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Storage's remove() reads the row it deletes, so delete needs a select policy too.
create policy "images: owner or admin can read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'images'
    and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_admin()))
  );

create policy "images: owner or admin can delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'images'
    and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_admin()))
  );
