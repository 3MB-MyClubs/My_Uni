-- Allow senders to read their own chat attachment objects.
--
-- The initial upload uses upsert=true, which requires SELECT in addition to
-- INSERT and UPDATE. This also makes retries safe when an upload succeeded but
-- the following message insert was interrupted. Recipient access remains
-- governed by the participant checks in the original policy.

drop policy if exists "Chat attachment uploader can read own"
  on storage.objects;

create policy "Chat attachment uploader can read own"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
