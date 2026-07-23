-- Students can spend an academic year in English preparation before Year 1.
-- Keep the UUID in sync with lib/services/academic_year_options.dart so older
-- clients can render the option while this migration is being rolled out.

do $$
begin
  if not exists (
    select 1
    from public.academic_years
    where lower(trim(name)) in ('prep', 'preparatory', 'preparatory year')
  ) then
    update public.academic_years
    set sort_order = sort_order + 1;

    insert into public.academic_years (id, name, sort_order, is_active)
    values (
      '00000000-0000-4000-8000-000000000001',
      'Prep',
      0,
      true
    );
  else
    update public.academic_years
    set is_active = true
    where lower(trim(name)) in ('prep', 'preparatory', 'preparatory year');
  end if;
end $$;
