-- Club Settings has always allowed multiple discovery categories, while the
-- original schema only carried one legacy category_id. Store the selected
-- labels on the owned club row so custom and multiple categories round-trip.
alter table public.clubs
  add column if not exists categories text[] not null default '{}'::text[];

update public.clubs as club
set categories = array[trim(category.name)]
from public.club_categories as category
where club.category_id = category.id
  and cardinality(club.categories) = 0
  and trim(category.name) <> '';

grant update (categories) on table public.clubs to authenticated;

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
        case
          when cardinality(c.categories) > 0 then c.categories
          when nullif(trim(cat.name),'') is not null then array[trim(cat.name)]
          when public.directory_fold_v1(c.name) ~ '(mühendis|bilgisayar|aiche|kumech|ies|kuswe|kuacm)'
            then array[case when p_language='tr' then 'Mühendislik' else 'Engineering' end]
          when public.directory_fold_v1(c.name) ~ '(ekonomi|girişimcilik|işletme|pazarlama|politik)'
            then array[case when p_language='tr' then 'İşletme' else 'Business' end]
          when public.directory_fold_v1(c.name) ~ '(dağcılık|fenerbahçe|kartal|spor)'
            then array[case when p_language='tr' then 'Spor' else 'Sports' end]
          when public.directory_fold_v1(c.name) ~ '(sanat|dans|ebru|fotoğraf|folklör|müzik|müzikal|orkestra|resim|sinema|tiyatro|radyo|thm|koro)'
            then array[case when p_language='tr' then 'Sanat' else 'Arts' end]
          when public.directory_fold_v1(c.name) ~ '(gönüllü|kadın|kuir|kürt|sosyal|düşünce|dayanışma)'
            then array[case when p_language='tr' then 'Sosyal' else 'Social' end]
          else array[case when p_language='tr' then 'Akademik' else 'Academic' end]
        end as categories,
        public.directory_fold_v1(c.name) as sort_name
      from public.clubs c left join public.club_categories cat on cat.id=c.category_id
      where c.is_active and not exists(select 1 from public.club_blocks b where b.blocker_id=v_uid and b.club_id=c.id)
    ), matched as (
      select n.*,
        (select count(*) from public.club_followers f where f.club_id=n.id) as member_count,
        coalesce((select max(p.created_at) from public.club_posts p where p.club_id=n.id), n.created_at) as last_active
      from named n
      where (v_query='' or strpos(public.directory_fold_v1(concat_ws(' ',n.name,n.short_name,n.description,n.email,array_to_string(n.categories,' '))),v_query)>0)
        and (coalesce(jsonb_array_length(p_filters->'categories'),0)=0 or exists (
          select 1 from unnest(n.categories) assigned(name)
          join jsonb_array_elements_text(p_filters->'categories') selected(name)
            on public.directory_fold_v1(trim(assigned.name))=public.directory_fold_v1(trim(selected.name))))
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

create or replace function public.get_directory_categories_v1()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(name order by name),'[]'::jsonb)
  from (
    select distinct trim(assigned.name) as name
    from public.clubs club
    cross join lateral unnest(club.categories) assigned(name)
    where club.is_active
      and trim(assigned.name) <> ''
      and (select auth.uid()) is not null
    union
    select category.name
    from public.club_categories category
    where category.is_active
      and (select auth.uid()) is not null
  ) categories
$$;
