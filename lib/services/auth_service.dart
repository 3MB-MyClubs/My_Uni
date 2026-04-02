import '../models/user.dart';
import '../models/app_admin.dart';
import 'mock_data.dart';

// ...existing code...

class AuthService {
  User? _currentUser;
  AppAdmin? _currentAdmin;

  User? get currentUser => _currentUser;
  AppAdmin? get currentAdmin => _currentAdmin;

  bool login(String email, [String? password]) {
    if (email == appAdmin.email) {
      _currentAdmin = appAdmin;
      return true;
    }
    final user = users.firstWhere(
      (u) => u.email == email && (password == null || u.password == password),
      orElse: () => User(id: '', name: '', email: '', password: '', role: '', subscribedClubIds: []),
    );
    if (user.id.isNotEmpty) {
      _currentUser = user;
      return true;
    }
    return false;
  }

  bool signUp(String name, String email, String password) {
    if (users.any((u) => u.email == email)) {
      return false;
    }
    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      password: password,
      role: 'student',
      subscribedClubIds: [],
    );
    users.add(newUser);
    return true;
  }


  void logout() {
    _currentUser = null;
    _currentAdmin = null;
  }
}

final authService = AuthService();
