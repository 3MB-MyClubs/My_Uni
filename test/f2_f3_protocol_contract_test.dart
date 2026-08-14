import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('released F2/F3 PostgREST request contracts remain unchanged', () async {
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://contract.invalid',
      'released-anon-key',
      httpClient: transport,
    );
    addTearDown(client.dispose);

    const eventId = '10000000-0000-0000-0000-000000000001';
    const attendeeId = '10000000-0000-0000-0000-000000000002';
    const callerActorId = '10000000-0000-0000-0000-000000000003';
    const postId = '20000000-0000-0000-0000-000000000001';
    const pollId = '30000000-0000-0000-0000-000000000001';

    await client.from('event_checkins').insert({
      'event_id': eventId,
      'profile_id': attendeeId,
      'checked_in_by': callerActorId,
      'method': 'manual',
    });
    await client
        .from('event_checkins')
        .delete()
        .eq('event_id', eventId)
        .eq('profile_id', attendeeId);
    await client.from('polls').insert({
      'post_id': postId,
      'question': 'Released question',
      'options': ['A', 'B'],
    });
    await client.from('poll_votes').upsert({
      'poll_id': pollId,
      'profile_id': attendeeId,
      'option_index': 1,
    }, onConflict: 'poll_id,profile_id');

    expect(requests, hasLength(4));

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/rest/v1/event_checkins');
    expect(jsonDecode(requests[0].body), {
      'event_id': eventId,
      'profile_id': attendeeId,
      'checked_in_by': callerActorId,
      'method': 'manual',
    });

    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, '/rest/v1/event_checkins');
    expect(requests[1].url.queryParameters, {
      'event_id': 'eq.$eventId',
      'profile_id': 'eq.$attendeeId',
    });

    expect(requests[2].method, 'POST');
    expect(requests[2].url.path, '/rest/v1/polls');
    expect(jsonDecode(requests[2].body), {
      'post_id': postId,
      'question': 'Released question',
      'options': ['A', 'B'],
    });

    expect(requests[3].method, 'POST');
    expect(requests[3].url.path, '/rest/v1/poll_votes');
    expect(
      requests[3].url.queryParameters['on_conflict'],
      'poll_id,profile_id',
    );
    expect(jsonDecode(requests[3].body), {
      'poll_id': pollId,
      'profile_id': attendeeId,
      'option_index': 1,
    });
  });

  test('new Flutter F2/F3 mutations are v2-only with no v1 fallback', () {
    final interactions = File(
      'lib/services/supabase_interaction_service.dart',
    ).readAsStringSync();
    final posts = File(
      'lib/services/supabase_post_service.dart',
    ).readAsStringSync();

    for (final rpc in const [
      'check_in_event_v2',
      'remove_event_checkin_v2',
      'vote_poll_v2',
      'remove_poll_vote_v2',
    ]) {
      expect(interactions, contains("'$rpc'"));
    }
    expect(posts, contains("'create_club_post_transactional_v2'"));
    expect(posts, contains("'p_poll_options': poll?.options"));

    expect(
      interactions,
      isNot(contains("_insertIgnoringDuplicate(client, 'event_checkins'")),
    );
    expect(interactions, isNot(contains("from('poll_votes').upsert")));
    expect(posts, isNot(contains("from('polls').insert")));

    expect(interactions, isNot(contains("'checked_in_by'")));
    expect(interactions, contains("'p_option_index': optionIndex"));
  });
}
