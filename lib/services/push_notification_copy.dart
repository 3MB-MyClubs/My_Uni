class PushNotificationCopy {
  const PushNotificationCopy({required this.title, required this.body});

  final String title;
  final String body;
}

PushNotificationCopy localizedPushNotificationCopy({
  required String type,
  required Map<String, dynamic> args,
  required String languageCode,
  required String fallbackTitle,
  required String fallbackBody,
}) {
  String value(String key, String fallback) {
    final text = args[key]?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  final isTurkish = languageCode.toLowerCase() == 'tr';
  final actor = value('actorName', isTurkish ? 'Birisi' : 'Someone');
  final club = value('clubName', isTurkish ? 'Bir kulüp' : 'A club');
  final group = value('groupName', isTurkish ? 'Grup sohbeti' : 'Group chat');
  final content = value('content', '');
  final eventTitle = value(
    'eventTitle',
    isTurkish ? 'etkinliğin' : 'your event',
  );
  final postPreview = value(
    'postPreview',
    isTurkish ? 'son gönderin' : 'your latest post',
  );
  final comment = value('comment', '');

  if (isTurkish) {
    return switch (type) {
      'direct_message' => PushNotificationCopy(
        title: actor,
        body: '$actor: $content',
      ),
      'group_message' => PushNotificationCopy(
        title: group,
        body: '$actor: $content',
      ),
      'club_channel_message' => PushNotificationCopy(
        title: club,
        body: '$club: $content',
      ),
      'club_inbox_message' => PushNotificationCopy(
        title: actor,
        body: '$actor: $content',
      ),
      'club_post' => PushNotificationCopy(
        title: '$club yeni bir gönderi paylaştı',
        body:
            '$club yeni bir gönderi paylaştı: “$content” Gönderiyi görmek '
            'için dokun.',
      ),
      'club_event' => PushNotificationCopy(
        title: '$club yeni bir etkinlik duyurdu',
        body:
            '$club, “$eventTitle” etkinliğini duyurdu. Ayrıntıları görmek '
            've katılmak için dokun.',
      ),
      'post_like' => PushNotificationCopy(
        title: '$actor gönderini beğendi',
        body: '$actor, “$postPreview” gönderini beğendi.',
      ),
      'post_comment' => PushNotificationCopy(
        title: '$actor gönderine yorum yaptı',
        body: '$actor: “$comment” Yanıtlamak için dokun.',
      ),
      'event_rsvp' => PushNotificationCopy(
        title: '$actor etkinliğine katılıyor',
        body:
            '$actor, “$eventTitle” etkinliğine katılıyor. Misafir listen '
            'büyüyor!',
      ),
      'profile_follow' => PushNotificationCopy(
        title: '$actor seni takip etmeye başladı',
        body: '$actor seni takip etmeye başladı. Profilini görmek için dokun.',
      ),
      _ => PushNotificationCopy(title: fallbackTitle, body: fallbackBody),
    };
  }

  return switch (type) {
    'direct_message' => PushNotificationCopy(
      title: actor,
      body: '$actor: $content',
    ),
    'group_message' => PushNotificationCopy(
      title: group,
      body: '$actor: $content',
    ),
    'club_channel_message' => PushNotificationCopy(
      title: club,
      body: '$club: $content',
    ),
    'club_inbox_message' => PushNotificationCopy(
      title: actor,
      body: '$actor: $content',
    ),
    'club_post' => PushNotificationCopy(
      title: '$club posted something new',
      body: '$club shared “$content”. Tap to view the post.',
    ),
    'club_event' => PushNotificationCopy(
      title: 'New event from $club',
      body: '$club announced “$eventTitle”. Tap for details and RSVP.',
    ),
    'post_like' => PushNotificationCopy(
      title: '$actor liked your post',
      body: '$actor liked your post “$postPreview”.',
    ),
    'post_comment' => PushNotificationCopy(
      title: '$actor commented on your post',
      body: '$actor commented: “$comment”. Tap to reply.',
    ),
    'event_rsvp' => PushNotificationCopy(
      title: '$actor is going to your event',
      body: '$actor is going to “$eventTitle”. Your guest list is growing!',
    ),
    'profile_follow' => PushNotificationCopy(
      title: '$actor followed you',
      body: '$actor started following you. Tap to view their profile.',
    ),
    _ => PushNotificationCopy(title: fallbackTitle, body: fallbackBody),
  };
}
