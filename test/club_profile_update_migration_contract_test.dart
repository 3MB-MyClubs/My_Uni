import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('club profile migration grants only editable-column updates', () {
    final migration = File(
      'supabase/migrations/'
      '20260831070534_grant_authenticated_club_profile_updates.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'grant update (name, short_name, description, logo_url)\n'
        '  on table public.clubs\n'
        '  to authenticated;',
      ),
    );
    expect(migration, isNot(contains('grant update on public.clubs')));
  });

  test('club ownership RLS remains scoped with using and with check', () {
    final hardening = File(
      'supabase/migrations/011_security_performance_hardening.sql',
    ).readAsStringSync();
    final policyStart = hardening.indexOf(
      'create policy "Club admins can update own club profile"',
    );
    final nextPolicy = hardening.indexOf(
      'drop policy if exists "moderation_reports_insert_own"',
      policyStart,
    );
    final policy = hardening.substring(policyStart, nextPolicy);

    expect(policy, contains('for update'));
    expect(policy, contains('using ('));
    expect(policy, contains('with check ('));
    expect(policy, contains('account.auth_user_id = (select auth.uid())'));
    expect(policy, contains('account.club_id = clubs.id'));
  });
}
