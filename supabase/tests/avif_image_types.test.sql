-- AVIF uploads: every picture bucket takes image/avif and keeps the types it had before.
begin;
\ir _helpers/setup.psql
select plan(4);

select is(
  (select allowed_mime_types from storage.buckets where id = 'images'),
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/avif'],
  'images bucket keeps PNG, JPEG, WebP, GIF and adds AVIF'
);

select is(
  (select allowed_mime_types from storage.buckets where id = 'pet-photos'),
  array['image/webp', 'image/jpeg', 'image/png', 'image/avif'],
  'pet-photos bucket keeps WebP, JPEG, PNG and adds AVIF'
);

select is(
  (select allowed_mime_types from storage.buckets where id = 'medical'),
  array['image/png', 'image/jpeg', 'image/webp', 'application/pdf', 'image/avif'],
  'medical bucket keeps PNG, JPEG, WebP, PDF and adds AVIF'
);

select is(
  (select array_agg(file_size_limit order by id) from storage.buckets where id in ('images', 'medical', 'pet-photos')),
  array[5242880::bigint, 10485760, 2097152],
  'size limits are unchanged (5 MB, 10 MB, 2 MB)'
);

select * from finish();
rollback;
