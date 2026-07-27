-- Event rows are visible to signed-in students and the Flutter client stores
-- `getPublicUrl()` results in events.image_url. Supabase does not validate that
-- a bucket is public when generating that URL, so a private event-images
-- bucket produces a valid-looking URL that students cannot download.
--
-- Public read access is intentional for event artwork. Object mutations remain
-- protected by the club-admin INSERT/UPDATE/DELETE policies created in 011.
update storage.buckets
set public = true
where id = 'event-images';
