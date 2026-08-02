-- Store chat photos outside message rows so every chat participant can load
-- the same object from Supabase Storage.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'chat-attachments',
  'chat-attachments',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Chat attachment owner can upload"
  on storage.objects;
create policy "Chat attachment owner can upload"
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Chat attachment owner can read"
  on storage.objects;
create policy "Chat attachment owner can read"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (
      exists (
        select 1
        from public.direct_messages message
        where message.id::text = split_part(storage.filename(name), '.', 1)
          and message.sender_id::text = (storage.foldername(name))[1]
          and (
            message.sender_id = (select auth.uid())
            or message.receiver_id = (select auth.uid())
          )
      )
      or exists (
        select 1
        from public.group_messages message
        join public.group_chat_members member
          on member.group_id = message.group_id
        where message.id::text = split_part(storage.filename(name), '.', 1)
          and message.sender_id::text = (storage.foldername(name))[1]
          and member.user_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.club_channel_messages message
        where message.id::text = split_part(storage.filename(name), '.', 1)
          and message.sender_auth_id::text = (storage.foldername(name))[1]
          and (
            exists (
              select 1
              from public.club_followers follower
              where follower.club_id = message.club_id
                and follower.profile_id = (select auth.uid())
            )
            or exists (
              select 1
              from public.club_auth_accounts account
              where account.club_id = message.club_id
                and account.auth_user_id = (select auth.uid())
            )
          )
      )
      or exists (
        select 1
        from public.club_inbox_messages message
        join public.club_inbox_threads thread
          on thread.id = message.thread_id
        where message.id::text = split_part(storage.filename(name), '.', 1)
          and message.sender_auth_id::text = (storage.foldername(name))[1]
          and (
            thread.profile_id = (select auth.uid())
            or exists (
              select 1
              from public.club_auth_accounts account
              where account.club_id = thread.club_id
                and account.auth_user_id = (select auth.uid())
            )
            or exists (
              select 1
              from public.club_followers follower
              where follower.club_id = thread.club_id
                and follower.profile_id = (select auth.uid())
                and follower.role = 'board_member'
            )
          )
      )
    )
  );

-- Storage upsert/retry requires SELECT access even before the chat row exists.
-- Keep this as a separate least-privilege policy: it only exposes objects
-- under the authenticated sender's own folder.
drop policy if exists "Chat attachment uploader can read own"
  on storage.objects;
create policy "Chat attachment uploader can read own"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Chat attachment owner can update"
  on storage.objects;
create policy "Chat attachment owner can update"
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Chat attachment owner can delete"
  on storage.objects;
create policy "Chat attachment owner can delete"
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
