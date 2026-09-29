-- The organizer can enter the visible ticket code when a camera cannot scan.
-- Resolve it only inside the selected event, then use the same admission path
-- as the QR credential for locking, revocation, and duplicate checks.
create function private.scan_event_ticket_code(p_event_id uuid, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_code text := upper(btrim(p_code));
  v_token text;
  v_result jsonb;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  if v_code is null or v_code !~ '^[A-Z0-9]{6}$'
      or v_code !~ '[A-Z]' or v_code !~ '[0-9]' then
    return jsonb_build_object('status', 'invalid');
  end if;

  select token into v_token from public.event_tickets
    where event_id = p_event_id and display_code = v_code;
  if not found then return jsonb_build_object('status', 'invalid'); end if;

  v_result := private.scan_event_ticket(p_event_id, v_token);
  if v_result->>'status' = 'checked_in' then
    update public.event_checkins set method = 'manual'
      where event_id = p_event_id
        and profile_id = (v_result->>'profile_id')::uuid;
  end if;
  return v_result;
end;
$$;

create function public.scan_event_ticket_code(p_event_id uuid, p_code text)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.scan_event_ticket_code(p_event_id, p_code);
$$;

revoke all on function private.scan_event_ticket_code(uuid, text),
  public.scan_event_ticket_code(uuid, text) from public, anon, authenticated;
grant execute on function private.scan_event_ticket_code(uuid, text),
  public.scan_event_ticket_code(uuid, text) to authenticated;
