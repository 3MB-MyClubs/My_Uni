-- Free, organizer-issued admission tickets. QR payload: clubup-ticket:v1:<token>.
-- Credentials are deliberately separate from event sharing links and profile IDs.
create table public.event_tickets (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique default encode(extensions.gen_random_bytes(32), 'hex')
    check (token ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz not null default clock_timestamp(),
  issued_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete set null
);
create unique index event_tickets_current_key on public.event_tickets(event_id, profile_id)
  where revoked_at is null;
create index event_tickets_holder_idx on public.event_tickets(profile_id, event_id, issued_at desc);
create index event_tickets_issued_by_idx on public.event_tickets(issued_by);
create index event_tickets_revoked_by_idx on public.event_tickets(revoked_by);
create index event_tickets_used_by_idx on public.event_tickets(used_by);
alter table public.event_tickets enable row level security;
revoke all on public.event_tickets from public, anon, authenticated;
grant select on public.event_tickets to authenticated;
create policy event_tickets_holder_or_staff on public.event_tickets
  for select to authenticated using (
    profile_id = (select auth.uid()) or (select private.can_manage_event(event_id))
  );

-- Privileged implementations live outside the exposed API schema. Only these
-- routines can mutate credentials; every entry point checks live membership.
create function private.issue_event_ticket(p_event_id uuid, p_profile_id uuid, p_reissue boolean)
returns public.event_tickets language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  -- RSVP is the serialization point for concurrent issue/reissue/cancellation.
  perform 1 from public.event_rsvps
    where event_id = p_event_id and profile_id = p_profile_id for update;
  if not found then
    raise exception 'An RSVP is required' using errcode = '22023';
  end if;
  select * into v_ticket from public.event_tickets
    where event_id = p_event_id and profile_id = p_profile_id and revoked_at is null
    for update;
  if v_ticket.id is not null and not coalesce(p_reissue, false) then
    return v_ticket; -- Retried issuance is idempotent.
  end if;
  if exists (select 1 from public.event_checkins where event_id = p_event_id and profile_id = p_profile_id)
    or exists (select 1 from public.event_tickets where event_id = p_event_id and profile_id = p_profile_id and used_at is not null) then
    raise exception 'Attendee has already checked in' using errcode = '22023';
  end if;
  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where id = v_ticket.id;
  insert into public.event_tickets(event_id, profile_id, issued_by)
    values (p_event_id, p_profile_id, auth.uid()) returning * into v_ticket;
  return v_ticket;
end;
$$;

create function private.revoke_event_ticket(p_event_id uuid, p_ticket_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where id = p_ticket_id and event_id = p_event_id and revoked_at is null;
  return found;
end;
$$;

create function private.scan_event_ticket(p_event_id uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.event_tickets;
  v_checkin_id uuid;
begin
  -- Check permissions before token lookup, including for unknown/foreign tokens.
  if auth.uid() is null or not private.can_manage_event(p_event_id) then
    raise exception 'Not authorized to manage this event' using errcode = '42501';
  end if;
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'invalid');
  end if;
  select * into v_ticket from public.event_tickets where token = p_token;
  if not found then return jsonb_build_object('status', 'invalid'); end if;
  if v_ticket.event_id <> p_event_id then
    -- No holder, event, or ticket details escape across event boundaries.
    return jsonb_build_object('status', 'wrong_event');
  end if;
  -- Use the same RSVP -> ticket lock order as issuance and cancellation.
  perform 1 from public.event_rsvps where event_id = p_event_id
    and profile_id = v_ticket.profile_id for key share;
  if not found then return jsonb_build_object('status', 'revoked'); end if;
  select * into v_ticket from public.event_tickets where token = p_token for update;
  if not found then return jsonb_build_object('status', 'invalid'); end if;
  if v_ticket.revoked_at is not null then return jsonb_build_object('status', 'revoked'); end if;
  if v_ticket.used_at is not null then return jsonb_build_object('status', 'already_used'); end if;
  -- The canonical unique (event_id, profile_id) also arbitrates races with
  -- manual check-in. A conflict never reports a new admission.
  insert into public.event_checkins(event_id, profile_id, checked_in_by, method)
    values (p_event_id, v_ticket.profile_id, auth.uid(), 'qr')
    on conflict (event_id, profile_id) do nothing returning id into v_checkin_id;
  update public.event_tickets set used_at = clock_timestamp(), used_by = auth.uid()
    where id = v_ticket.id;
  if v_checkin_id is null then return jsonb_build_object('status', 'already_used'); end if;
  return jsonb_build_object('status', 'checked_in', 'profile_id', v_ticket.profile_id);
end;
$$;

create function private.revoke_cancelled_rsvp_tickets()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.event_tickets set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where event_id = old.event_id and profile_id = old.profile_id and revoked_at is null;
  return old;
end;
$$;
create trigger revoke_cancelled_rsvp_tickets after delete on public.event_rsvps
  for each row execute function private.revoke_cancelled_rsvp_tickets();
revoke all on function private.revoke_cancelled_rsvp_tickets() from public, anon, authenticated;

create function public.issue_event_ticket(p_event_id uuid, p_profile_id uuid, p_reissue boolean default false)
returns public.event_tickets language sql security invoker set search_path = '' as $$
  select private.issue_event_ticket(p_event_id, p_profile_id, p_reissue);
$$;
create function public.revoke_event_ticket(p_event_id uuid, p_ticket_id uuid)
returns boolean language sql security invoker set search_path = '' as $$
  select private.revoke_event_ticket(p_event_id, p_ticket_id);
$$;
create function public.scan_event_ticket(p_event_id uuid, p_token text)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.scan_event_ticket(p_event_id, p_token);
$$;
create function public.can_manage_event_tickets(p_event_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null and private.can_manage_event(p_event_id);
$$;
revoke all on function private.issue_event_ticket(uuid, uuid, boolean),
  private.revoke_event_ticket(uuid, uuid), private.scan_event_ticket(uuid, text),
  public.issue_event_ticket(uuid, uuid, boolean), public.revoke_event_ticket(uuid, uuid),
  public.scan_event_ticket(uuid, text), public.can_manage_event_tickets(uuid) from public, anon;
grant execute on function private.issue_event_ticket(uuid, uuid, boolean),
  private.revoke_event_ticket(uuid, uuid), private.scan_event_ticket(uuid, text),
  public.issue_event_ticket(uuid, uuid, boolean), public.revoke_event_ticket(uuid, uuid),
  public.scan_event_ticket(uuid, text), public.can_manage_event_tickets(uuid) to authenticated;
