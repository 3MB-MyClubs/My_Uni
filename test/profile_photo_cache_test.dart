import 'package:flutter_application_1/services/student_profile_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('avatar replacement URL changes without changing its storage object', () {
    const original =
        'https://example.supabase.co/storage/v1/object/public/avatars/u1/avatar.jpg';

    final first = versionedAvatarUrl(original, version: 'first');
    final second = versionedAvatarUrl(original, version: 'second');

    expect(first, isNot(second));
    expect(Uri.parse(first).path, Uri.parse(second).path);
    expect(Uri.parse(first).queryParameters['v'], 'first');
    expect(Uri.parse(second).queryParameters['v'], 'second');
  });

  test('avatar cache version preserves existing public URL parameters', () {
    final result = versionedAvatarUrl(
      'https://example.com/avatar.jpg?download=1',
      version: 'new-photo',
    );
    final parameters = Uri.parse(result).queryParameters;

    expect(parameters['download'], '1');
    expect(parameters['v'], 'new-photo');
  });

  testWidgets(
    'writing new bytes to the same local avatar path bumps revision',
    (tester) async {
      final state = UserState();

      state.setProfilePhoto('student', '/tmp/student-avatar.jpg');
      final firstRevision = state.profilePhotoRevisionFor('student');
      state.setProfilePhoto('student', '/tmp/student-avatar.jpg');

      expect(state.profilePhotoRevisionFor('student'), firstRevision + 1);
    },
  );
}
