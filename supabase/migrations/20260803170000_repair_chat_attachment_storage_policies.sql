-- Restore the private chat attachment policies if the bucket was created
-- manually or its policies were removed outside the migration history.

drop policy if exists "Chat attachment owner can upload" on storage.objects;
drop policy if exists "Chat attachment owner can read" on storage.objects;
drop policy if exists "Chat attachment uploader can read own" on storage.objects;
drop policy if exists "Chat attachment owner can update" on storage.objects;
drop policy if exists "Chat attachment owner can delete" on storage.objects;

create policy "Chat attachment owner can upload"
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

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

-- Upsert is used by the client, so the sender needs read access before the
-- message row exists and again when an existing object is replaced.
create policy "Chat attachment uploader can read own"
on storage.objects
for select to authenticated
using (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

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

create policy "Chat attachment owner can delete"
on storage.objects
for delete to authenticated
using (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
