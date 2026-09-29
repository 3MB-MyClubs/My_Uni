-- A human-readable reference shared by the ticket holder and event staff.
-- Admission continues to use the existing 256-bit QR bearer credential.
create function private.generate_event_ticket_display_code()
returns text language plpgsql volatile set search_path = '' as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_code text;
begin
  for v_attempt in 1..20 loop
    v_bytes := extensions.gen_random_bytes(6);
    v_code := '';
    for v_position in 0..5 loop
      v_code := v_code || substr(v_alphabet, get_byte(v_bytes, v_position) % 32 + 1, 1);
    end loop;
    if v_code ~ '[A-Z]' and v_code ~ '[0-9]' then
      return v_code;
    end if;
  end loop;
  raise exception 'Could not generate ticket code';
end;
$$;
revoke all on function private.generate_event_ticket_display_code() from public, anon, authenticated;

alter table public.event_tickets add column display_code text;
alter table public.event_tickets alter column display_code
  set default private.generate_event_ticket_display_code();
alter table public.event_tickets add constraint event_tickets_display_code_format
  check (display_code ~ '^[A-Z0-9]{6}$' and display_code ~ '[A-Z]' and display_code ~ '[0-9]');
create unique index event_tickets_event_display_code_key
  on public.event_tickets(event_id, display_code);

-- Assign codes to tickets issued before this migration, including audit rows.
do $$
declare
  v_ticket record;
begin
  for v_ticket in select id from public.event_tickets loop
    for v_attempt in 1..20 loop
      begin
        update public.event_tickets
          set display_code = private.generate_event_ticket_display_code()
          where id = v_ticket.id;
        exit;
      exception when unique_violation then
        if v_attempt = 20 then raise; end if;
      end;
    end loop;
  end loop;
end;
$$;
alter table public.event_tickets alter column display_code set not null;

-- Preserve the current issuance and reissue rules. Only a code collision is
-- retried; all other constraint failures still abort the operation.
create or replace function private.issue_event_ticket(p_event_id uuid, p_profile_id uuid, p_reissue boolean)
returns public.event_tickets language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
  v_constraint text;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  perform 1 from public.events where id = p_event_id and is_ticketed for share;
  if not found then
    raise exception 'Ticketing is not enabled for this event' using errcode = '22023';
  end if;
  perform 1 from public.event_rsvps
    where event_id = p_event_id and profile_id = p_profile_id for update;
  if not found then
    raise exception 'An RSVP is required' using errcode = '22023';
  end if;
  select * into v_ticket from public.event_tickets
    where event_id = p_event_id and profile_id = p_profile_id and revoked_at is null
    for update;
  if v_ticket.id is not null and not coalesce(p_reissue, false) then
    return v_ticket;
  end if;

  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where id = v_ticket.id;
  delete from public.event_checkins
    where event_id = p_event_id and profile_id = p_profile_id;
  for v_attempt in 1..20 loop
    begin
      insert into public.event_tickets(event_id, profile_id, issued_by)
        values (p_event_id, p_profile_id, auth.uid()) returning * into v_ticket;
      return v_ticket;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint <> 'event_tickets_event_display_code_key' or v_attempt = 20 then
        raise;
      end if;
    end;
  end loop;
  raise exception 'Could not allocate ticket code';
end;
$$;
