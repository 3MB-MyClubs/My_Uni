-- Additive read APIs. Released feed/chat clients keep their existing contracts.
-- All reads run as the caller; RLS remains authoritative.
create or replace function public.directory_fold_v1(p_text text)
returns text language sql immutable parallel safe set search_path = '' as $$
  select lower(translate(coalesce(p_text, ''), 'İI', 'ii'));
$$;
revoke all on function public.directory_fold_v1(text) from public, anon;
grant execute on function public.directory_fold_v1(text) to authenticated;

create or replace function public.get_directory_page_v1(
  p_kind text default 'students', p_query text default '',
  p_filters jsonb default '{}'::jsonb, p_cursor jsonb default null,
  p_limit integer default 25, p_language text default 'en'
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,25),1),50);
  v_query text := public.directory_fold_v1(trim(p_query));
  v_items jsonb; v_more boolean; v_cursor jsonb;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_kind not in ('students','clubs') then raise exception 'Invalid directory kind' using errcode='22023'; end if;
  if p_kind = 'students' then
    with matched as (
      select p.id, p.full_name, p.avatar_url, p.bio, m.name as major_name,
        y.name as year_name, public.directory_fold_v1(p.full_name) as sort_name,
        case when v_query = '' then 0
          when public.directory_fold_v1(p.full_name) = v_query then 0
          when v_query = any(regexp_split_to_array(public.directory_fold_v1(p.full_name), '\s+')) then 1
          when starts_with(public.directory_fold_v1(p.full_name), v_query) then 2
          when exists(select 1 from unnest(regexp_split_to_array(public.directory_fold_v1(p.full_name), '\s+')) w where starts_with(w,v_query)) then 3
          else 4 end as rank
      from public.profiles p
      left join public.majors m on m.id=p.major_id
      left join public.academic_years y on y.id=p.academic_year_id
      where p.role='student' and p.id <> v_uid
        and (v_query='' or strpos(public.directory_fold_v1(p.full_name),v_query)>0)
        -- This existing actor-checked helper can see recipient-side blocks;
        -- user_blocks RLS exposes only the caller's own block rows.
        and not private.chat_v2_dm_blocked(v_uid,p.id)
        and (coalesce(jsonb_array_length(p_filters->'majors'),0)=0 or exists (
          select 1 from jsonb_array_elements_text(p_filters->'majors') f
          where regexp_replace(replace(public.directory_fold_v1(trim(m.name)),'&','and'),'\s+',' ','g') =
            regexp_replace(replace(public.directory_fold_v1(trim(f)),'&','and'),'\s+',' ','g')))
        and (coalesce(jsonb_array_length(p_filters->'years'),0)=0 or y.name in
          (select jsonb_array_elements_text(p_filters->'years')))
    ), candidates as materialized (
      select * from matched where p_cursor is null or
        (rank,sort_name,id) > ((p_cursor->>'rank')::integer,p_cursor->>'name',(p_cursor->>'id')::uuid)
      order by rank,sort_name,id limit v_limit+1
    ), bounded as (select * from candidates order by rank,sort_name,id limit v_limit)
    select coalesce(jsonb_agg(to_jsonb(b)-'sort_name'-'rank' order by rank,sort_name,id),'[]'::jsonb),
      (select count(*)>v_limit from candidates),
      (select jsonb_build_object('rank',rank,'name',sort_name,'id',id) from bounded order by rank desc,sort_name desc,id desc limit 1)
    into v_items,v_more,v_cursor from bounded b;
  else
    with named as (
      select c.id,c.name,c.short_name,c.description,c.logo_url,c.category_id,c.email,c.created_at,
        coalesce(nullif(trim(cat.name),''), case
          when public.directory_fold_v1(c.name) ~ '(mühendis|bilgisayar|aiche|kumech|ies|kuswe|kuacm)' then case when p_language='tr' then 'Mühendislik' else 'Engineering' end
          when public.directory_fold_v1(c.name) ~ '(ekonomi|girişimcilik|işletme|pazarlama|politik)' then case when p_language='tr' then 'İşletme' else 'Business' end
          when public.directory_fold_v1(c.name) ~ '(dağcılık|fenerbahçe|kartal|spor)' then case when p_language='tr' then 'Spor' else 'Sports' end
          when public.directory_fold_v1(c.name) ~ '(sanat|dans|ebru|fotoğraf|folklör|müzik|müzikal|orkestra|resim|sinema|tiyatro|radyo|thm|koro)' then case when p_language='tr' then 'Sanat' else 'Arts' end
          when public.directory_fold_v1(c.name) ~ '(gönüllü|kadın|kuir|kürt|sosyal|düşünce|dayanışma)' then case when p_language='tr' then 'Sosyal' else 'Social' end
          else case when p_language='tr' then 'Akademik' else 'Academic' end end) as category_name,
        public.directory_fold_v1(c.name) as sort_name
      from public.clubs c left join public.club_categories cat on cat.id=c.category_id
      where c.is_active and not exists(select 1 from public.club_blocks b where b.blocker_id=v_uid and b.club_id=c.id)
    ), matched as (
      select n.*,
        (select count(*) from public.club_followers f where f.club_id=n.id) as member_count,
        coalesce((select max(p.created_at) from public.club_posts p where p.club_id=n.id), n.created_at) as last_active
      from named n
      where (v_query='' or strpos(public.directory_fold_v1(concat_ws(' ',n.name,n.short_name,n.description,n.email,n.category_name)),v_query)>0)
        and (coalesce(jsonb_array_length(p_filters->'categories'),0)=0 or n.category_name in
          (select jsonb_array_elements_text(p_filters->'categories')))
    ), ordered as (
      select m.*, case when p_filters->>'sort'='recentlyActive'
        then -extract(epoch from last_active) else -member_count::numeric end as sort_value
      from matched m
    ), candidates as materialized (
      select * from ordered where p_cursor is null or
        (sort_value,sort_name,id) > ((p_cursor->>'value')::numeric,p_cursor->>'name',(p_cursor->>'id')::uuid)
      order by sort_value,sort_name,id limit v_limit+1
    ), bounded as (select * from candidates order by sort_value,sort_name,id limit v_limit)
    select coalesce(jsonb_agg(to_jsonb(b)-'sort_name'-'sort_value' order by sort_value,sort_name,id),'[]'::jsonb),
      (select count(*)>v_limit from candidates),
      (select jsonb_build_object('value',sort_value,'name',sort_name,'id',id) from bounded order by sort_value desc,sort_name desc,id desc limit 1)
    into v_items,v_more,v_cursor from bounded b;
  end if;
  return jsonb_build_object('items',v_items,'next_cursor',case when v_more then v_cursor else null end);
end $$;
revoke all on function public.get_directory_page_v1(text,text,jsonb,jsonb,integer,text) from public, anon;
grant execute on function public.get_directory_page_v1(text,text,jsonb,jsonb,integer,text) to authenticated;

create or replace function public.get_content_page_v1(
  p_kind text default 'events', p_club_id uuid default null,
  p_from timestamptz default null, p_until timestamptz default null,
  p_query text default '', p_category text default '',
  p_cursor jsonb default null, p_limit integer default 25, p_descending boolean default false
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,25),1),50);
  v_query text := public.directory_fold_v1(trim(p_query));
  v_items jsonb; v_more boolean; v_cursor jsonb;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_kind not in ('events','posts') then raise exception 'Invalid content kind' using errcode='22023'; end if;
  if p_kind='events' then
    with candidates as materialized (
      select e.*, jsonb_build_object('id',c.id,'name',c.name,'short_name',c.short_name,
        'description',c.description,'logo_url',c.logo_url,'category_id',c.category_id,'created_at',c.created_at) as club
      from public.events e join public.clubs c on c.id=e.club_id
      where (p_club_id is null or e.club_id=p_club_id)
        and (p_from is null or e.ends_at>p_from) and (p_until is null or e.starts_at<p_until)
        and not exists(select 1 from public.club_blocks b where b.blocker_id=v_uid and b.club_id=c.id)
        and (p_category='' or exists(select 1 from unnest(e.tags) t where public.directory_fold_v1(t)=public.directory_fold_v1(p_category)))
        and (v_query='' or strpos(public.directory_fold_v1(concat_ws(' ',e.title,e.description,e.location,c.name,array_to_string(e.tags,' '))),v_query)>0)
        and (p_cursor is null or (not p_descending and (e.starts_at,e.id)>((p_cursor->>'time')::timestamptz,(p_cursor->>'id')::uuid))
          or (p_descending and (e.starts_at,e.id)<((p_cursor->>'time')::timestamptz,(p_cursor->>'id')::uuid)))
      order by case when p_descending then e.starts_at end desc, case when p_descending then e.id end desc, e.starts_at,e.id limit v_limit+1
    ), bounded as (select * from candidates order by case when p_descending then starts_at end desc, case when p_descending then id end desc, starts_at,id limit v_limit)
    select coalesce(jsonb_agg(to_jsonb(b) || jsonb_build_object('attendee_user_ids',
        (select coalesce(jsonb_agg(r.profile_id),'[]'::jsonb) from public.event_rsvps r where r.event_id=b.id))
      order by case when p_descending then starts_at end desc, case when p_descending then id end desc, starts_at,id),'[]'::jsonb),
      (select count(*)>v_limit from candidates),
      (select jsonb_build_object('time',starts_at,'id',id) from bounded order by case when p_descending then starts_at end, case when p_descending then id end, starts_at desc,id desc limit 1)
    into v_items,v_more,v_cursor from bounded b;
  else
    with candidates as materialized (
      select p.*, jsonb_build_object('id',c.id,'name',c.name,'short_name',c.short_name,
        'description',c.description,'logo_url',c.logo_url,'category_id',c.category_id,'created_at',c.created_at) as club
      from public.club_posts p join public.clubs c on c.id=p.club_id
      where (p_club_id is null or p.club_id=p_club_id)
        and not exists(select 1 from public.club_blocks b where b.blocker_id=v_uid and b.club_id=c.id)
        and not exists(select 1 from public.user_blocks b where b.blocker_id=v_uid and b.blocked_id=p.author_id)
        and (v_query='' or strpos(public.directory_fold_v1(p.content),v_query)>0)
        and (p_cursor is null or (p.created_at,p.id)<((p_cursor->>'time')::timestamptz,(p_cursor->>'id')::uuid))
      order by p.created_at desc,p.id desc limit v_limit+1
    ), bounded as (select * from candidates order by created_at desc,id desc limit v_limit)
    select coalesce(jsonb_agg(to_jsonb(b) || jsonb_build_object(
      'like_count',(select count(*) from public.post_likes l where l.post_id=b.id),
      'view_count',(select count(*) from public.post_views v where v.post_id=b.id),
      'poll',(select jsonb_build_object('id',p.id,'question',p.question,'options',p.options,
        'viewer_vote',(select v.option_index from public.poll_votes v where v.poll_id=p.id and v.profile_id=v_uid),
        'counts',(select jsonb_agg((select count(*) from public.poll_votes v where v.poll_id=p.id and v.option_index=o.i) order by o.i)
          from generate_series(0,jsonb_array_length(p.options)-1) o(i))) from public.polls p where p.post_id=b.id)
    ) order by created_at desc,id desc),'[]'::jsonb),
      (select count(*)>v_limit from candidates),
      (select jsonb_build_object('time',created_at,'id',id) from bounded order by created_at,id limit 1)
    into v_items,v_more,v_cursor from bounded b;
  end if;
  return jsonb_build_object('items',v_items,'next_cursor',case when v_more then v_cursor else null end);
end $$;
revoke all on function public.get_content_page_v1(text,uuid,timestamptz,timestamptz,text,text,jsonb,integer,boolean) from public, anon;
grant execute on function public.get_content_page_v1(text,uuid,timestamptz,timestamptz,text,text,jsonb,integer,boolean) to authenticated;

-- Facets are independent of the current page/query, so a filter never vanishes
-- simply because its matching rows are on a later page.
create or replace function public.get_event_categories_v1(p_from timestamptz, p_until timestamptz)
returns jsonb language sql stable security invoker set search_path='' as $$
  select coalesce(jsonb_agg(tag order by tag),'[]'::jsonb) from (
    select distinct trim(t.tag) as tag from public.events e
    join public.clubs c on c.id=e.club_id cross join lateral unnest(e.tags) t(tag)
    where auth.uid() is not null and e.ends_at>p_from and e.starts_at<p_until
      and trim(t.tag)<>'' and not exists(select 1 from public.club_blocks b where b.blocker_id=auth.uid() and b.club_id=e.club_id)
  ) tags;
$$;
revoke all on function public.get_event_categories_v1(timestamptz,timestamptz) from public,anon;
grant execute on function public.get_event_categories_v1(timestamptz,timestamptz) to authenticated;

create or replace function public.get_admin_overview_v1()
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_result jsonb;
begin
  if not exists(select 1 from public.app_admins where auth_user_id=auth.uid()) then
    raise exception 'Platform administrator required' using errcode='42501';
  end if;
  with ranked as (
    select c.id,c.name,c.short_name,c.description,c.logo_url,c.created_at,
      (select count(*) from public.club_followers f where f.club_id=c.id) as member_count,
      (select count(*) from public.event_rsvps r join public.events e on e.id=r.event_id where e.club_id=c.id) as total_rsvps
    from public.clubs c
  ), leaders as (select * from ranked order by member_count desc,total_rsvps desc,id limit 10)
  select jsonb_build_object(
    'students',(select count(*) from public.profiles where role='student'),
    'clubs',(select count(*) from public.clubs),
    'events',(select count(*) from public.events),
    'posts',(select count(*) from public.club_posts),
    'leaders',(select coalesce(jsonb_agg(to_jsonb(l) order by member_count desc,total_rsvps desc,id),'[]'::jsonb) from leaders l)
  ) into v_result;
  return v_result;
end $$;
revoke all on function public.get_admin_overview_v1() from public,anon;
grant execute on function public.get_admin_overview_v1() to authenticated;

-- Verified with authenticated EXPLAIN (ANALYZE, BUFFERS) on 10k profiles
-- and 20k events; see docs/performance/local-query-baseline.txt.
create index if not exists events_page_order_v1_idx on public.events (starts_at,id);
create index if not exists profiles_directory_order_v1_idx
  on public.profiles (public.directory_fold_v1(full_name),id) where role='student';

create or replace function public.get_directory_categories_v1()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(name order by name),'[]'::jsonb)
  from public.club_categories where is_active and (select auth.uid()) is not null
$$;
revoke all on function public.get_directory_categories_v1() from public,anon;
grant execute on function public.get_directory_categories_v1() to authenticated;

create or replace function public.get_club_content_counts_v1(p_club_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'posts',(select count(*) from public.club_posts p where p.club_id=p_club_id
      and not exists(select 1 from public.user_blocks b where b.blocker_id=(select auth.uid()) and b.blocked_id=p.author_id)),
    'events',(select count(*) from public.events e where e.club_id=p_club_id))
  where (select auth.uid()) is not null
    and exists(select 1 from public.clubs c where c.id=p_club_id)
    and not exists(select 1 from public.club_blocks b where b.blocker_id=(select auth.uid()) and b.club_id=p_club_id)
$$;
revoke all on function public.get_club_content_counts_v1(uuid) from public,anon;
grant execute on function public.get_club_content_counts_v1(uuid) to authenticated;

create or replace function public.get_club_members_page_v1(
  p_club_id uuid, p_query text default '', p_cursor jsonb default null, p_limit integer default 25
) returns jsonb language sql stable security invoker set search_path = '' as $$
  with candidates as materialized (
    select p.id,p.full_name,p.avatar_url,p.bio,p.role,m.name as major_name,y.name as year_name,
      f.role as club_role,f.role_title,
      case when f.role='board_member' then 0 else 1 end as rank,
      public.directory_fold_v1(p.full_name) as sort_name
    from public.club_followers f join public.profiles p on p.id=f.profile_id
    left join public.majors m on m.id=p.major_id
    left join public.academic_years y on y.id=p.academic_year_id
    where f.club_id=p_club_id and (select auth.uid()) is not null
      and not private.chat_v2_dm_blocked((select auth.uid()),p.id)
      and exists(select 1 from public.clubs c where c.id=p_club_id)
      and not exists(select 1 from public.club_blocks b where b.club_id=p_club_id and b.blocker_id=(select auth.uid()))
      and (coalesce(trim(p_query),'')='' or strpos(public.directory_fold_v1(p.full_name),public.directory_fold_v1(trim(p_query)))>0)
      and (p_cursor is null or
        (case when f.role='board_member' then 0 else 1 end,public.directory_fold_v1(p.full_name),p.id) >
        ((p_cursor->>'rank')::integer,p_cursor->>'name',(p_cursor->>'id')::uuid))
    order by rank,sort_name,p.id limit least(greatest(coalesce(p_limit,25),1),50)+1
  ), bounded as (
    select * from candidates order by rank,sort_name,id limit least(greatest(coalesce(p_limit,25),1),50)
  ) select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(b)-'rank'-'sort_name' order by rank,sort_name,id) from bounded b),'[]'::jsonb),
    'next_cursor',case when (select count(*) from candidates)>least(greatest(coalesce(p_limit,25),1),50)
      then (select jsonb_build_object('rank',rank,'name',sort_name,'id',id) from bounded order by rank desc,sort_name desc,id desc limit 1) end)
$$;
revoke all on function public.get_club_members_page_v1(uuid,text,jsonb,integer) from public,anon;
grant execute on function public.get_club_members_page_v1(uuid,text,jsonb,integer) to authenticated;
