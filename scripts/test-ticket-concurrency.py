#!/usr/bin/env python3
"""Real overlapping transactions against `supabase start` (never a remote DB).

Run: python3 scripts/test-ticket-concurrency.py
Uses Docker's psql; no Python packages or service-role credentials are needed.
"""
import concurrent.futures
import json
import subprocess
import threading
import uuid

CONTAINER = 'supabase_db_My_Uni'
manager, holder, club, event = [str(uuid.uuid4()) for _ in range(4)]


def sql(statement):
    result = subprocess.run(
        ['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-qAt', '-U', 'postgres',
         '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], input=statement, text=True,
        capture_output=True, check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def as_manager(statement):
    return sql(f"begin; set local role authenticated; set local request.jwt.claim.sub = '{manager}'; "
               + statement + '; commit;')


def parallel(statement, count=12):
    gate = threading.Barrier(count)
    def run(_):
        gate.wait(timeout=15)
        return as_manager(statement)[0]
    with concurrent.futures.ThreadPoolExecutor(max_workers=count) as executor:
        return list(executor.map(run, range(count)))


try:
    sql(f"""
      insert into auth.users(id,aud,role,email) values
        ('{manager}','authenticated','authenticated','{manager}@ku.edu.tr'),
        ('{holder}','authenticated','authenticated','{holder}@ku.edu.tr');
      insert into public.profiles(id,email,full_name) values
        ('{holder}','{holder}@ku.edu.tr','Concurrency holder') on conflict(id) do nothing;
      insert into public.clubs(id,name) values('{club}','Ticket concurrency fixture');
      insert into public.club_auth_accounts(auth_user_id,club_id) values('{manager}','{club}');
      insert into public.events(id,club_id,title,event_date,starts_at,is_ticketed)
        values('{event}','{club}','Concurrency test',current_date,now(),true);
      insert into public.event_rsvps(event_id,profile_id) values('{event}','{holder}');
    """)
    tokens = parallel(f"select (public.issue_event_ticket('{event}','{holder}')).token")
    assert len(set(tokens)) == 1, 'Parallel issuance must return the same credential'
    token = tokens[0]
    print('PASS: 12 simultaneous issuances return one ticket')

    # Hold the ticket lock briefly so every scan starts while a competing
    # transaction owns the row; the remaining workers must wait and recheck.
    result = parallel(f"select public.scan_event_ticket('{event}','{token}'); select pg_sleep(0.08)")
    statuses = [json.loads(row)['status'] for row in result]
    assert statuses.count('checked_in') == 1, statuses
    assert statuses.count('already_used') == 11, statuses
    assert sql(f"select count(*) from public.event_checkins where event_id='{event}'") == ['1']
    print('PASS: 12 overlapping scans yield exactly one admission and 11 already-used results')

    # Revocation and scan serialize on the ticket lock. Once revoke returns,
    # no subsequent scan may be successful, regardless of earlier results.
    ticket_id = sql(f"select id from public.event_tickets where event_id='{event}'")[0]
    as_manager(f"select public.revoke_event_ticket('{event}','{ticket_id}')")
    statuses = [json.loads(row)['status'] for row in parallel(f"select public.scan_event_ticket('{event}','{token}')")]
    assert set(statuses) == {'revoked'}, statuses
    print('PASS: parallel scans after revocation all reject admission')
finally:
    sql(f"delete from public.clubs where id='{club}'; delete from auth.users where id in ('{manager}','{holder}');")
