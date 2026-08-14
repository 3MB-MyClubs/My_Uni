import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  test('new clients use one atomic profile RPC', () {
    final source = File(
      '$root/lib/services/student_profile_service.dart',
    ).readAsStringSync();
    final method = source.substring(
      source.indexOf('Future<StudentProfileData?> updateProfile('),
      source.indexOf('Future<StudentProfileData?> updateFullName('),
    );
    expect(method, contains("'update_profile_v2'"));
    expect(method, isNot(contains(".from('student_interests')")));
    expect(method, isNot(contains('_replaceJoinRows')));
  });

  test('post creation uses stable ID and atomic post plus poll RPC', () {
    final source = File(
      '$root/lib/services/supabase_post_service.dart',
    ).readAsStringSync();
    expect(source, contains("'create_club_post_transactional_v2'"));
    expect(source, contains("'p_post_id': postId"));
    expect(source, contains(r"'club_posts/$clubId/$postId/cover.jpg'"));
    expect(source, isNot(contains("'create_poll_v2'")));
  });

  test('content deletes are database-first and preserve durable cleanup', () {
    final post = File(
      '$root/lib/services/supabase_post_service.dart',
    ).readAsStringSync();
    final event = File(
      '$root/lib/services/supabase_event_service.dart',
    ).readAsStringSync();
    expect(post, contains("'delete_club_post_transactional_v2'"));
    expect(event, contains("'delete_club_event_transactional_v2'"));
    expect(post, contains('Database deletion is authoritative'));
    expect(event, contains('queue retries later'));
  });
}
