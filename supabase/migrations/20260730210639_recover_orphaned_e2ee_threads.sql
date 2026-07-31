-- A client may lose power or connectivity after creating an E2EE thread but
-- before uploading its first key envelope. Only the creator may remove that
-- unusable shell, and only while it still contains no key material.
grant delete on public.e2ee_threads to authenticated;

create policy e2ee_threads_delete_empty_creator
  on public.e2ee_threads
  for delete to authenticated
  using (
    created_by = (select auth.uid())
    and (select private.can_access_e2ee_thread(thread_id, true))
    and not exists (
      select 1
      from public.e2ee_thread_key_envelopes envelope
      where envelope.thread_id = e2ee_threads.thread_id
    )
  );
