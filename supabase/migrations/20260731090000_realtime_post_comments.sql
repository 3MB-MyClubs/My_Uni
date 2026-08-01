-- Live comment threads.
--
-- post_comments already had select/insert/delete policies (001, tightened in
-- 012), but it was never added to the realtime publication, so a comment sheet
-- that was open could only ever show what it fetched when it opened. Adding
-- the table lets subscribers receive inserts and deletes as they happen.
--
-- Realtime respects RLS, and post_comments_select is `to authenticated using
-- (true)`, so signed-in members receive changes on threads they can already
-- read and anonymous clients receive nothing.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'post_comments'
  ) then
    alter publication supabase_realtime add table public.post_comments;
  end if;
end $$;

-- Deletes broadcast only the primary key unless the row is replicated in
-- full, and subscribers need post_id to know which thread lost a comment.
alter table public.post_comments replica identity full;
