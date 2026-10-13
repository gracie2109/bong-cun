-- Shared image gallery of a product group (docs/module-san-pham.md, step 2).
--
--  A group has up to 8 images in order; the first is the cover and is also written to
--  product_groups.image_url, so every screen that reads that column keeps working. A variant
--  picks one of the group's images (products.image_url). Writes go through save_product_group.
--
--  Files live in the images bucket under catalog/<id>/. Anyone who may create or update products
--  can add, read and delete them, so one person's upload can be replaced by another. Older files
--  under <uid>/products/ stay where they are and keep working by URL.
--  Safe to run more than once.

create table if not exists public.product_images (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.product_groups(id) on delete cascade,
  url          text not null check (length(btrim(url)) > 0),
  -- null for an image that lives elsewhere (a link typed or imported from Excel)
  storage_path text,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create unique index if not exists product_images_group_url_key on public.product_images (group_id, url);
create index if not exists product_images_group_idx on public.product_images (group_id, sort_order);

alter table public.product_images enable row level security;
drop policy if exists "public read" on public.product_images;
create policy "public read" on public.product_images for select to anon, authenticated using (true);
revoke insert, update, delete on public.product_images from anon, authenticated;

-- Existing pictures become the gallery: the group's image first, then the variants' own images
-- (up to 8 in all). Only groups that have no gallery yet are filled, so a second run changes nothing.
do $$
declare
  r record;
begin
  for r in
    select g.id, g.image_url
    from public.product_groups g
    where not exists (select 1 from public.product_images i where i.group_id = g.id)
  loop
    insert into public.product_images (group_id, url, storage_path, sort_order)
    select r.id, v.url,
           substring(v.url from '/storage/v1/object/public/images/([^?]+)'),
           (row_number() over (order by v.rank, v.ord, v.url))::int
    from (
      select r.image_url as url, 0 as rank, 0 as ord
      where nullif(btrim(r.image_url), '') is not null
      union
      select p.image_url, 1, min(p.sort_order)
      from public.products p
      where p.group_id = r.id and nullif(btrim(p.image_url), '') is not null
      group by p.image_url
    ) v
    order by v.rank, v.ord, v.url
    limit 8
    on conflict (group_id, url) do nothing;
  end loop;
end;
$$;

-- ---------------------------------------------------------------- storage
drop policy if exists "images: catalog upload" on storage.objects;
create policy "images: catalog upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = 'catalog'
    and (public.can_products('UPDATE') or public.can_products('CREATE'))
  );

drop policy if exists "images: catalog read" on storage.objects;
create policy "images: catalog read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = 'catalog'
    and (public.can_products('UPDATE') or public.can_products('CREATE'))
  );

drop policy if exists "images: catalog delete" on storage.objects;
create policy "images: catalog delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = 'catalog'
    and (public.can_products('UPDATE') or public.can_products('CREATE'))
  );

notify pgrst, 'reload schema';
