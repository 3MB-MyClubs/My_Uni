/// Stable keyset cursor returned by `get_feed_page_v2`.
class FeedCursorV2 {
  final DateTime createdAt;
  final String id;

  const FeedCursorV2({required this.createdAt, required this.id});

  factory FeedCursorV2.fromJson(Map<String, dynamic> json) => FeedCursorV2(
    createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    id: json['id'].toString(),
  );
}

class FeedClubV2 {
  final String id;
  final String name;
  final String? shortName;
  final String description;
  final String? logoUrl;
  final String? categoryId;
  final DateTime? createdAt;
  final int memberCount;

  const FeedClubV2({
    required this.id,
    required this.name,
    this.shortName,
    required this.description,
    this.logoUrl,
    this.categoryId,
    this.createdAt,
    this.memberCount = 0,
  });

  factory FeedClubV2.fromJson(Map<String, dynamic> json) => FeedClubV2(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    shortName: _nullableString(json['short_name']),
    description: json['description']?.toString() ?? '',
    logoUrl: _nullableString(json['logo_url']),
    categoryId: _nullableString(json['category_id']),
    createdAt: _nullableDateTime(json['created_at']),
    memberCount: _integer(json['member_count']),
  );
}

class FeedPersonV2 {
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final bool followsViewer;

  const FeedPersonV2({
    required this.id,
    required this.name,
    this.role = 'student',
    this.avatarUrl,
    this.bio,
    this.followsViewer = false,
  });

  factory FeedPersonV2.fromJson(Map<String, dynamic> json) => FeedPersonV2(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    role: json['role']?.toString() ?? 'student',
    avatarUrl: _nullableString(json['avatar_url']),
    bio: _nullableString(json['bio']),
    followsViewer: json['follows_viewer'] == true,
  );
}

class FeedPollV2 {
  final String id;
  final String question;
  final List<String> options;
  final List<int> optionCounts;
  final int totalVotes;
  final int? viewerOptionIndex;

  const FeedPollV2({
    required this.id,
    required this.question,
    required this.options,
    required this.optionCounts,
    required this.totalVotes,
    this.viewerOptionIndex,
  });

  factory FeedPollV2.fromJson(Map<String, dynamic> json) {
    final options = _stringList(json['options']);
    final rawCounts = _map(json['option_counts']);
    return FeedPollV2(
      id: json['id'].toString(),
      question: json['question']?.toString() ?? '',
      options: options,
      optionCounts: [
        for (var index = 0; index < options.length; index++)
          _integer(rawCounts['$index']),
      ],
      totalVotes: _integer(json['total_votes']),
      viewerOptionIndex: _nullableInteger(json['viewer_option_index']),
    );
  }
}

class FeedEngagementV2 {
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool viewerHasLiked;
  final FeedPersonV2? firstLiker;

  const FeedEngagementV2({
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.viewerHasLiked,
    this.firstLiker,
  });

  factory FeedEngagementV2.fromJson(Map<String, dynamic> json) =>
      FeedEngagementV2(
        likeCount: _integer(json['like_count']),
        commentCount: _integer(json['comment_count']),
        viewCount: _integer(json['view_count']),
        viewerHasLiked: json['viewer_has_liked'] == true,
        firstLiker: json['first_liker'] is Map
            ? FeedPersonV2.fromJson(_map(json['first_liker']))
            : null,
      );
}

class FeedPostV2 {
  final String id;
  final DateTime createdAt;
  final String content;
  final String? mediaUrl;
  final bool isAnnouncement;
  final FeedClubV2 club;
  final FeedPersonV2? author;
  final FeedEngagementV2 engagement;
  final FeedPollV2? poll;
  final bool viewerFollowsClub;

  const FeedPostV2({
    required this.id,
    required this.createdAt,
    required this.content,
    this.mediaUrl,
    required this.isAnnouncement,
    required this.club,
    this.author,
    required this.engagement,
    this.poll,
    required this.viewerFollowsClub,
  });

  factory FeedPostV2.fromJson(Map<String, dynamic> json) => FeedPostV2(
    id: json['id'].toString(),
    createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    content: json['content']?.toString() ?? '',
    mediaUrl: _nullableString(json['media_url']),
    isAnnouncement: json['is_announcement'] == true,
    club: FeedClubV2.fromJson(_map(json['club'])),
    author: json['author'] is Map
        ? FeedPersonV2.fromJson(_map(json['author']))
        : null,
    engagement: FeedEngagementV2.fromJson(_map(json['engagement'])),
    poll: json['poll'] is Map ? FeedPollV2.fromJson(_map(json['poll'])) : null,
    viewerFollowsClub: _map(json['viewer'])['follows_club'] == true,
  );
}

class FeedEventV2 {
  final String id;
  final String title;
  final String description;
  final String location;
  final String? mediaUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? createdByUserId;
  final List<String> tags;
  final String? registrationUrl;
  final List<Map<String, dynamic>> schedule;
  final List<Map<String, dynamic>> speakers;
  final int rsvpCount;
  final bool viewerIsAttending;
  final FeedClubV2 club;

  const FeedEventV2({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    this.mediaUrl,
    required this.startsAt,
    required this.endsAt,
    this.createdByUserId,
    required this.tags,
    this.registrationUrl,
    required this.schedule,
    required this.speakers,
    required this.rsvpCount,
    required this.viewerIsAttending,
    required this.club,
  });

  factory FeedEventV2.fromJson(Map<String, dynamic> json) => FeedEventV2(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    mediaUrl: _nullableString(json['media_url']),
    startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
    endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
    createdByUserId: _nullableString(json['created_by_user_id']),
    tags: _stringList(json['tags']),
    registrationUrl: _nullableString(json['registration_url']),
    schedule: _mapList(json['schedule']),
    speakers: _mapList(json['speakers']),
    rsvpCount: _integer(json['rsvp_count']),
    viewerIsAttending: json['viewer_is_attending'] == true,
    club: FeedClubV2.fromJson(_map(json['club'])),
  );
}

class FeedPageV2 {
  final List<FeedPostV2> items;
  final FeedCursorV2? nextCursor;
  final bool hasMore;
  final int pageSize;
  final List<FeedEventV2> upcomingEvents;
  final List<FeedPersonV2> suggestedPeople;
  final List<FeedClubV2> suggestedClubs;

  const FeedPageV2({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.pageSize,
    this.upcomingEvents = const [],
    this.suggestedPeople = const [],
    this.suggestedClubs = const [],
  });

  factory FeedPageV2.fromJson(Map<String, dynamic> json) => FeedPageV2(
    items: _mapList(json['items']).map(FeedPostV2.fromJson).toList(),
    nextCursor: json['next_cursor'] is Map
        ? FeedCursorV2.fromJson(_map(json['next_cursor']))
        : null,
    hasMore: json['has_more'] == true,
    pageSize: _integer(json['page_size'], fallback: 25),
    upcomingEvents: _mapList(
      json['upcoming_events'],
    ).map(FeedEventV2.fromJson).toList(),
    suggestedPeople: _mapList(
      json['suggested_people'],
    ).map(FeedPersonV2.fromJson).toList(),
    suggestedClubs: _mapList(
      json['suggested_clubs'],
    ).map(FeedClubV2.fromJson).toList(),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

String? _nullableString(Object? value) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? null : result;
}

DateTime? _nullableDateTime(Object? value) {
  final raw = _nullableString(value);
  return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
}

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

int? _nullableInteger(Object? value) {
  if (value == null) return null;
  return value is num ? value.toInt() : int.tryParse('$value');
}
