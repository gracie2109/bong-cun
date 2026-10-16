-- Pet profile photo (docs/anh-thu-cung.md, step 1).
--
--  One photo per pet. The file lives in the public bucket pet-photos under <pet id>/<uuid>.webp
--  (the app shrinks it to 800px first). pets.photo_url stays the public URL every screen reads;
--  the new pets.photo_path remembers where the file is so it can be deleted or checked later.
--  Staff who may update (or create) pets can upload and delete; customers only look.
--  The app changes the photo through set_pet_photo, which hands back the old path so the client
--  can delete the old file (SQL cannot delete Storage files).
--  Safe to run more than once.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pet-photos', 'pet-photos', true, 2097152, array['image/webp', 'image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.pets add column if not exists photo_path text;

-- Pets are shared by every branch, so the permission is not tied to a branch.
create or replace function public.can_edit_pet_photos() returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('pets', 'UPDATE')), false)
      or coalesce((select public.has_permission('pets', 'CREATE')), false);
$$;

revoke execute on function public.can_edit_pet_photos() from public, anon;
grant execute on function public.can_edit_pet_photos() to authenticated;

-- ---------------------------------------------------------------- storage
-- No update policy: files are never overwritten (each upload gets a new name).
-- No policy for anon: the bucket is public to read by URL, but nobody can list it.
drop policy if exists "pet-photos: upload" on storage.objects;
create policy "pet-photos: upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pet-photos'
    and public.can_edit_pet_photos()
    and exists (select 1 from public.pets p where p.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "pet-photos: read" on storage.objects;
create policy "pet-photos: read" on storage.objects
  for select to authenticated
  using (bucket_id = 'pet-photos' and public.can_edit_pet_photos());

drop policy if exists "pet-photos: delete" on storage.objects;
create policy "pet-photos: delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'pet-photos' and public.can_edit_pet_photos());

-- ---------------------------------------------------------------- set_pet_photo
-- Sets (or, with a null path, clears) the pet's photo. Returns the path of the file it replaced,
-- or null when there was none (or only a link typed by hand).
create or replace function public.set_pet_photo(p_pet uuid, p_path text, p_url text) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old text;
begin
  if not public.can_edit_pet_photos() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select photo_path into v_old from public.pets where id = p_pet for update;
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if p_path is null then
    if p_url is not null then
      raise exception 'url without a path' using errcode = '22023', hint = 'bad_input';
    end if;
  elsif left(p_path, length(p_pet::text) + 1) <> p_pet::text || '/'
     or p_url is null
     or right(p_url, length('/storage/v1/object/public/pet-photos/' || p_path))
        <> '/storage/v1/object/public/pet-photos/' || p_path then
    raise exception 'the photo does not belong to this pet' using errcode = '22023', hint = 'bad_input';
  end if;
  update public.pets
  set photo_path = p_path, photo_url = p_url, updated_at = now()
  where id = p_pet;
  return v_old;
end;
$$;

revoke execute on function public.set_pet_photo(uuid, text, text) from public, anon;
grant execute on function public.set_pet_photo(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';
