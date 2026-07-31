class AppAdmin {
  final String id;
  final String name;
  final String email;
  final String password;
  final bool isPlatformAdmin;

  AppAdmin({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.isPlatformAdmin = false,
  });
}
