class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role; // 'admin' or 'student'
  final List<String> subscribedClubIds;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.subscribedClubIds,
  });
}
