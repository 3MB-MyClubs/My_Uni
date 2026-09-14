begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '95000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'category-owner@ku.edu.tr',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '95000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'category-other@ku.edu.tr',
    ''
  );

insert into public.clubs (id, name, description)
values (
  '96000000-0000-0000-0000-000000000001',
  'Category Discovery Club',
  'Multi-category discovery fixture'
);

insert into public.club_auth_accounts (auth_user_id, club_id)
values (
  '95000000-0000-0000-0000-000000000001',
  '96000000-0000-0000-0000-000000000001'
);

select ok(
  has_column_privilege('authenticated', 'public.clubs', 'categories', 'UPDATE'),
  'authenticated clients can request a club category update'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '95000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$update public.clubs
    set categories = array['Arts', 'Technology']
    where id = '96000000-0000-0000-0000-000000000001'$$,
  'the owning club account can update discovery categories'
);

select is(
  (
    select categories
    from public.clubs
    where id = '96000000-0000-0000-0000-000000000001'
  ),
  array['Arts', 'Technology'],
  'all selected categories are stored'
);

select is(
  jsonb_array_length(
    public.get_directory_page_v1(
      p_kind => 'clubs',
      p_filters => '{"categories":["Technology"]}'
    )->'items'
  ),
  1,
  'filtering by any assigned category returns the club'
);

select is(
  public.get_directory_page_v1(
    p_kind => 'clubs',
    p_query => 'Technology'
  )->'items'->0->'categories',
  '["Arts", "Technology"]'::jsonb,
  'directory results return every assigned category'
);

select is(
  jsonb_array_length(
    public.get_directory_page_v1(
      p_kind => 'clubs',
      p_query => 'Arts'
    )->'items'
  ),
  1,
  'category text participates in club search'
);

select ok(
  public.get_directory_categories_v1() ? 'Technology',
  'assigned custom categories appear in the filter list'
);

select set_config(
  'request.jwt.claim.sub',
  '95000000-0000-0000-0000-000000000002',
  true
);
select lives_ok(
  $$update public.clubs
    set categories = array['Hijacked']
    where id = '96000000-0000-0000-0000-000000000001'$$,
  'a non-owner update is safely filtered by RLS'
);

reset role;
select is(
  (
    select categories
    from public.clubs
    where id = '96000000-0000-0000-0000-000000000001'
  ),
  array['Arts', 'Technology'],
  'the non-owner cannot change another club categories'
);

select * from finish();
rollback;
