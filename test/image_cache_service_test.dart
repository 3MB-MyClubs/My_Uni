import 'package:flutter_application_1/services/image_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed Supabase URLs share a cache key across token refreshes', () {
    const first =
        'https://project.supabase.co/storage/v1/object/sign/chat-attachments/u1/m1.jpg?token=first';
    const second =
        'https://project.supabase.co/storage/v1/object/sign/chat-attachments/u1/m1.jpg?token=second';

    expect(
      stableSupabaseSignedUrlCacheKey(first),
      stableSupabaseSignedUrlCacheKey(second),
    );
    expect(
      stableSupabaseSignedUrlCacheKey(first),
      'signed-out/project.supabase.co/chat-attachments/u1/m1.jpg',
    );
  });

  test('versioned storage URLs preserve existing query parameters', () {
    final result = versionedStorageUrl(
      'https://project.supabase.co/storage/v1/object/public/group-chat-photos/g/avatar.jpg?download=1',
      version: 'new-photo',
    );

    final parameters = Uri.parse(result).queryParameters;
    expect(parameters['download'], '1');
    expect(parameters['v'], 'new-photo');
  });

  test('transformed signed URLs keep rendition identity but ignore token', () {
    const first =
        'https://x.supabase.co/storage/v1/render/image/sign/'
        'chat-attachments/u/a.jpg?width=384&quality=92&token=one';
    const rotated =
        'https://x.supabase.co/storage/v1/render/image/sign/'
        'chat-attachments/u/a.jpg?quality=92&width=384&token=two';
    const screen =
        'https://x.supabase.co/storage/v1/render/image/sign/'
        'chat-attachments/u/a.jpg?quality=92&width=1600&token=three';

    expect(
      stableSupabaseSignedUrlCacheKey(first),
      stableSupabaseSignedUrlCacheKey(rotated),
    );
    expect(
      stableSupabaseSignedUrlCacheKey(first),
      isNot(stableSupabaseSignedUrlCacheKey(screen)),
    );
  });
}
