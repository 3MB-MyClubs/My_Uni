-- Group cover uploads use upsert=true. Supabase Storage requires SELECT as
-- well as INSERT and UPDATE for an upsert, so allow only the group creator to
-- inspect the object through the authenticated Storage API. The bucket stays
-- public for normal image delivery to group members.

drop policy if exists "group_photos_select_creator" on storage.objects;
create policy "group_photos_select_creator" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'group-chat-photos'
    and private.is_group_chat_creator(
      ((storage.foldername(name))[1])::uuid
    )
  );
