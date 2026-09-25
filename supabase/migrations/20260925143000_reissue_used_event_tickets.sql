-- Explicit staff reissue starts a new admission cycle. Old credentials stay
-- recorded and unusable, while the canonical current check-in is cleared.
create or replace function private.issue_event_ticket(p_event_id uuid, p_profile_id uuid, p_reissue boolean)
returns public.event_tickets language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  perform 1 from public.events where id = p_event_id and is_ticketed for share;
  if not found then
    raise exception 'Ticketing is not enabled for this event' using errcode = '22023';
  end if;

  -- Keep the event -> RSVP -> ticket lock order used by scanning and cancellation.
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
  -- A fresh ticket grants another admission, including after a previous scan.
  -- The consumed ticket retains its used_at/used_by audit trail.
  delete from public.event_checkins
    where event_id = p_event_id and profile_id = p_profile_id;
  insert into public.event_tickets(event_id, profile_id, issued_by)
    values (p_event_id, p_profile_id, auth.uid()) returning * into v_ticket;
  return v_ticket;
end;
$$;
