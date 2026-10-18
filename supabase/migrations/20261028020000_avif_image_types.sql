-- Accept AVIF pictures (image/avif) in the three upload buckets: images (products, avatars),
-- pet-photos and medical. The app's own list is packages/core/src/media/imageTypes.ts.
--
--  Additive only: every type a bucket already takes stays, size limits are untouched.
--  Safe to run more than once (a bucket that already has image/avif is skipped).

update storage.buckets
set allowed_mime_types = allowed_mime_types || array['image/avif']
where id in ('images', 'pet-photos', 'medical')
  and allowed_mime_types is not null
  and not ('image/avif' = any (allowed_mime_types));
