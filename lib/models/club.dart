class Club {
  final String id;
  final String name;
  final String description;
  final List<String> adminUserIds;

  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.adminUserIds,
  });
}
