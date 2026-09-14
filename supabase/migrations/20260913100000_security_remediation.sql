-- Security remediation: make follower roles and content audiences server
-- authoritative, and add abuse controls to legacy messaging writes.

-- A follower may only create the ordinary member role.  Club accounts retain
-- the ability to promote members, but ordinary authenticated users cannot
-- self-assign board privileges or move rows between clubs/accounts.
drop policy if exists "Users can follow clubs" on public.club_followers;
create policy "Users can follow clubs"
  on public.club_followers for insert to authenticated
  with check ((select auth.uid()) = profile_id and role = 'member');

revoke update on public.club_followers from authenticated;
grant update (role, role_title) on public.club_followers to authenticated;

-- Audience is canonical data. Existing rows remain public by default.
alter table public.club_posts
  add column if not exists audience text not null default 'everyone'
  constraint club_posts_audience_check check (audience in ('everyone','followers','board'));
alter table public.events
  add column if not exists audience text not null default 'everyone'
  constraint events_audience_check check (audience in ('everyone','followers','board'));

create or replace function private.can_view_club_content(
  target_club_id uuid,
  target_audience text
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select case
    when target_audience = 'everyone' then true
    when exists (select 1 from public.app_admins a where a.auth_user_id = (select auth.uid())) then true
    when exists (
      select 1 from public.club_auth_accounts a
      where a.auth_user_id = (select auth.uid()) and a.club_id = target_club_id
    ) then true
    when target_audience = 'followers' then exists (
      select 1 from public.club_followers f
      where f.club_id = target_club_id and f.profile_id = (select auth.uid())
    )
    when target_audience = 'board' then exists (
      select 1 from public.club_followers f
      where f.club_id = target_club_id and f.profile_id = (select auth.uid())
        and f.role = 'board_member'
    )
    else false
  end;
$$;

revoke all on function private.can_view_club_content(uuid,text) from public;
grant execute on function private.can_view_club_content(uuid,text) to anon, authenticated;

drop policy if exists "Anyone can read club posts" on public.club_posts;
create policy "Audience can read club posts" on public.club_posts
  for select to anon, authenticated
  using ((select private.can_view_club_content(club_id, audience)));
drop policy if exists "Anyone can read public events" on public.events;
create policy "Audience can read public events" on public.events
  for select to anon, authenticated
  using (is_public and (select private.can_view_club_content(club_id, audience)));

-- The v3 transactional writers carry the audience into the same transaction
-- as the content row. The v2 functions remain available to older clients and
-- deliberately default to everyone, so they cannot create hidden rows without
-- the new parameter.
create or replace function public.create_club_post_transactional_v3(
  p_post_id uuid, p_club_id uuid, p_content text,
  p_audience text default 'everyone', p_image_path text default null,
  p_image_url text default null, p_is_announcement boolean default false,
  p_mentioned_user_ids uuid[] default '{}', p_poll_question text default null,
  p_poll_options jsonb default null
) returns public.club_posts language plpgsql security invoker set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_post public.club_posts%rowtype;
  v_author uuid; v_club_name text;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_audience not in ('everyone','followers','board') then raise exception 'Invalid audience' using errcode='22023'; end if;
  if not (select private.can_manage_club_content(p_club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  if p_content is null or char_length(btrim(p_content)) not between 1 and 5000 then raise exception 'Invalid post content' using errcode='22023'; end if;
  if p_image_path is not null and p_image_path <> 'club_posts/'||p_club_id||'/'||p_post_id||'/cover.jpg' then raise exception 'Invalid image path' using errcode='22023'; end if;
  if (p_poll_question is null) <> (p_poll_options is null) then raise exception 'Invalid poll' using errcode='22023'; end if;
  perform private.enforce_authenticated_rate_limit('post_create:actor', null);
  perform private.enforce_authenticated_rate_limit('post_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline','v2',true);
  select id into v_author from public.profiles where id=v_actor;
  insert into public.club_posts(id,club_id,content,author_id,image_path,image_url,is_announcement,audience)
    values(p_post_id,p_club_id,btrim(p_content),v_author,p_image_path,p_image_url,coalesce(p_is_announcement,false),p_audience)
    returning * into v_post;
  if p_poll_question is not null then
    insert into public.polls(post_id,question,options) values(v_post.id,btrim(p_poll_question),p_poll_options);
  end if;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_post:'||v_post.id,'club_post',v_actor,'post',v_post.id,
    case p_audience when 'board' then 'club_board' when 'followers' then 'club_followers' else 'club_followers' end,
    p_club_id,jsonb_build_object('exclude_recipient_ids',to_jsonb(coalesce(p_mentioned_user_ids,'{}'::uuid[]))),v_club_name||' posted something new',
    v_club_name||' shared “'||left(p_content,360)||'”. Tap to view the post.',jsonb_build_object('clubName',v_club_name,'content',left(p_content,360)),null);
  return v_post;
end $$;

create or replace function public.create_club_event_transactional_v3(
  p_event_id uuid, p_club_id uuid, p_title text, p_description text, p_location text,
  p_event_date date, p_starts_at timestamptz, p_ends_at timestamptz,
  p_audience text default 'everyone', p_image_path text default null, p_image_url text default null,
  p_tags text[] default '{}', p_registration_url text default null,
  p_schedule jsonb default null, p_speakers jsonb default '[]'
) returns public.events language plpgsql security invoker set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_event public.events%rowtype; v_club_name text;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_audience not in ('everyone','followers','board') then raise exception 'Invalid audience' using errcode='22023'; end if;
  if not (select private.can_manage_club_content(p_club_id)) then raise exception 'Not authorized' using errcode='42501'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300 or p_ends_at <= p_starts_at then raise exception 'Invalid event details' using errcode='22023'; end if;
  if p_image_path is not null and p_image_path <> 'events/'||p_club_id||'/'||p_event_id||'/cover.jpg' then raise exception 'Invalid image path' using errcode='22023'; end if;
  perform private.enforce_authenticated_rate_limit('event_create:actor', null);
  perform private.enforce_authenticated_rate_limit('event_create:resource', p_club_id::text);
  perform set_config('app.notification_pipeline','v2',true);
  insert into public.events(id,club_id,title,description,location,event_date,starts_at,ends_at,is_public,created_by_user_id,image_path,image_url,tags,registration_url,schedule,speakers,audience)
    values(p_event_id,p_club_id,btrim(p_title),p_description,p_location,p_event_date,p_starts_at,p_ends_at,true,v_actor,p_image_path,p_image_url,coalesce(p_tags,'{}'),p_registration_url,p_schedule,coalesce(p_speakers,'[]'),p_audience)
    returning * into v_event;
  select coalesce(nullif(name,''),'A club') into v_club_name from public.clubs where id=p_club_id;
  perform private.enqueue_notification_outbox_v2('club_event:'||v_event.id,'club_event',v_actor,'event',v_event.id,
    case p_audience when 'board' then 'club_board' when 'followers' then 'club_followers' else 'club_followers' end,
    p_club_id,'{}','New event from '||v_club_name,v_club_name||' announced “'||left(p_title,300)||'”. Tap for details and RSVP.',jsonb_build_object('clubName',v_club_name,'eventTitle',left(p_title,300)),null);
  return v_event;
end $$;

create or replace function public.set_club_post_audience_v2(p_post_id uuid, p_audience text)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare v_club uuid;
begin
  if p_audience not in ('everyone','followers','board') then raise exception 'Invalid audience' using errcode='22023'; end if;
  select club_id into v_club from public.club_posts where id=p_post_id;
  if v_club is null or not (select private.can_manage_club_content(v_club)) then raise exception 'Not authorized' using errcode='42501'; end if;
  update public.club_posts set audience=p_audience, updated_at=now() where id=p_post_id;
  return found;
end $$;

create or replace function public.set_club_event_audience_v2(p_event_id uuid, p_audience text)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare v_club uuid;
begin
  if p_audience not in ('everyone','followers','board') then raise exception 'Invalid audience' using errcode='22023'; end if;
  select club_id into v_club from public.events where id=p_event_id;
  if v_club is null or not (select private.can_manage_club_content(v_club)) then raise exception 'Not authorized' using errcode='42501'; end if;
  update public.events set audience=p_audience, updated_at=now() where id=p_event_id;
  return found;
end $$;

revoke all on function public.create_club_post_transactional_v3(uuid,uuid,text,text,text,text,boolean,uuid[],text,jsonb) from public,anon,authenticated;
revoke all on function public.create_club_event_transactional_v3(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text,text[],text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.set_club_post_audience_v2(uuid,text) from public,anon,authenticated;
revoke all on function public.set_club_event_audience_v2(uuid,text) from public,anon,authenticated;
grant execute on function public.create_club_post_transactional_v3(uuid,uuid,text,text,text,text,boolean,uuid[],text,jsonb) to authenticated;
grant execute on function public.create_club_event_transactional_v3(uuid,uuid,text,text,text,date,timestamptz,timestamptz,text,text,text,text[],text,jsonb,jsonb) to authenticated;
grant execute on function public.set_club_post_audience_v2(uuid,text) to authenticated;
grant execute on function public.set_club_event_audience_v2(uuid,text) to authenticated;

-- Legacy direct chat inserts retain compatibility but now consume the same
-- atomic actor/resource buckets as send_message_v2.
create or replace function private.enforce_legacy_message_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('app.notification_pipeline', true) is distinct from 'v2' then
    perform private.enforce_authenticated_rate_limit('message_send:actor', null);
    if tg_table_name = 'direct_messages' then
      perform private.enforce_authenticated_rate_limit('message_send:resource',
        least(new.sender_id::text,new.receiver_id::text)||':'||greatest(new.sender_id::text,new.receiver_id::text));
    elsif tg_table_name = 'group_messages' then
      perform private.enforce_authenticated_rate_limit('message_send:resource', new.group_id::text);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists legacy_direct_message_rate_limit on public.direct_messages;
create trigger legacy_direct_message_rate_limit before insert on public.direct_messages for each row execute function private.enforce_legacy_message_rate_limit();
drop trigger if exists legacy_group_message_rate_limit on public.group_messages;
create trigger legacy_group_message_rate_limit before insert on public.group_messages for each row execute function private.enforce_legacy_message_rate_limit();
