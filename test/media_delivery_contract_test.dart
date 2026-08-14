import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat Storage contract accepts the uploader video MIME set at 10 MB',
    () async {
      final migration = await File(
        'supabase/migrations/20260813115049_enable_chat_video_media_contract.sql',
      ).readAsString();
      final store = await File('lib/services/chat_store.dart').readAsString();

      expect(migration, contains('file_size_limit = 10485760'));
      for (final mime in [
        'video/mp4',
        'video/quicktime',
        'video/x-m4v',
        'video/x-msvideo',
        'video/webm',
        'video/x-matroska',
        'video/3gpp',
      ]) {
        expect(migration, contains("'$mime'"));
        expect(store, contains("'$mime'"));
      }
      expect(
        store,
        isNot(contains('Video chat attachments are not supported')),
      );
    },
  );

  test(
    'Feed v2 remains paginated at 25 and image delivery is responsive',
    () async {
      final controller = await File(
        'lib/services/feed_v2_controller.dart',
      ).readAsString();
      final image = await File(
        'lib/widgets/app_network_image.dart',
      ).readAsString();
      final feed = await File('lib/screens/feed_screen.dart').readAsString();

      expect(controller, contains('this.pageSize = 25'));
      expect(feed, contains('SliverList'));
      expect(image, contains('mediaDimensionsFor('));
      expect(image, contains('mediaDeliveryService.resolvePublic('));
    },
  );

  test(
    'Chat v2 keeps canonical references until a visible widget signs them',
    () async {
      final service = await File(
        'lib/services/chat_v2_service.dart',
      ).readAsString();
      final image = await File(
        'lib/widgets/app_network_image.dart',
      ).readAsString();

      expect(service, contains('Keep the canonical reference stable'));
      expect(image, contains('class PrivateMediaNetworkImage'));
      expect(image, contains('resolvePrivateForCurrentAccount'));
    },
  );
}
