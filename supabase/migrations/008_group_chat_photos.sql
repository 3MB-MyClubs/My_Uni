-- Optional group photos selected from the device camera or photo library.

alter table group_chats
  add column if not exists photo_url text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'group-chat-photos',
  'group-chat-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "group_photos_insert_creator" on storage.objects;
create policy "group_photos_insert_creator" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'group-chat-photos'
    and is_group_chat_creator(
      ((storage.foldername(name))[1])::uuid
    )
  );

drop policy if exists "group_photos_update_creator" on storage.objects;
create policy "group_photos_update_creator" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'group-chat-photos'
    and is_group_chat_creator(
      ((storage.foldername(name))[1])::uuid
    )
  )
  with check (
    bucket_id = 'group-chat-photos'
    and is_group_chat_creator(
      ((storage.foldername(name))[1])::uuid
    )
  );

drop policy if exists "group_photos_delete_creator" on storage.objects;
create policy "group_photos_delete_creator" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'group-chat-photos'
    and is_group_chat_creator(
      ((storage.foldername(name))[1])::uuid
    )
  );
