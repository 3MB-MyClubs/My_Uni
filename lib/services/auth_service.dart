import '../models/user.dart';
import '../models/app_admin.dart';
import 'mock_data.dart';

// ...existing code...

class AuthService {
  User? _currentUser;
  AppAdmin? _currentAdmin;

  User? get currentUser => _currentUser;
  AppAdmin? get currentAdmin => _currentAdmin;

  bool isValidNumericPassword(String password) {
    return password.length >= 8 && RegExp(r'^[0-9]+$').hasMatch(password);
  }

  bool login(String email, [String? password]) {
    if (email == appAdmin.email) {
      _currentAdmin = appAdmin;
      return true;
    }
    final clubAdmin = clubAdmins.firstWhere(
      (a) => a.email == email && (password == null || a.password == password),
      orElse: () => AppAdmin(id: '', name: '', email: '', password: ''),
    );
    if (clubAdmin.id.isNotEmpty) {
      _currentAdmin = clubAdmin;
      return true;
    }
    final user = users.firstWhere(
      (u) => u.email == email && (password == null || u.password == password),
      orElse: () => User(
        id: '',
        name: '',
        email: '',
        password: '',
        role: '',
        subscribedClubIds: [],
      ),
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
    if (!isValidNumericPassword(password)) {
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
    _currentUser = newUser;
    _currentAdmin = null;
    return true;
  }

  bool hasAccountEmail(String email) {
    final normalized = email.toLowerCase();
    return users.any((u) => u.email.toLowerCase() == normalized) ||
        appAdmin.email.toLowerCase() == normalized ||
        clubAdmins.any((a) => a.email.toLowerCase() == normalized);
  }

  bool resetAccountPassword(String email, String newPassword) {
    if (!isValidNumericPassword(newPassword)) {
      return false;
    }
    final normalized = email.toLowerCase();
    final index = users.indexWhere((u) => u.email.toLowerCase() == normalized);
    if (index >= 0) {
      final user = users[index];
      users[index] = User(
        id: user.id,
        name: user.name,
        email: user.email,
        password: newPassword,
        role: user.role,
        subscribedClubIds: user.subscribedClubIds,
        followingUserIds: user.followingUserIds,
      );
      if (_currentUser?.id == user.id) {
        _currentUser = users[index];
      }
      return true;
    }

    if (appAdmin.email.toLowerCase() == normalized) {
      appAdmin = AppAdmin(
        id: appAdmin.id,
        name: appAdmin.name,
        email: appAdmin.email,
        password: newPassword,
      );
      if (_currentAdmin?.id == appAdmin.id) {
        _currentAdmin = appAdmin;
      }
      return true;
    }

    final adminIndex = clubAdmins.indexWhere(
      (a) => a.email.toLowerCase() == normalized,
    );
    if (adminIndex >= 0) {
      final admin = clubAdmins[adminIndex];
      clubAdmins[adminIndex] = AppAdmin(
        id: admin.id,
        name: admin.name,
        email: admin.email,
        password: newPassword,
      );
      if (_currentAdmin?.id == admin.id) {
        _currentAdmin = clubAdmins[adminIndex];
      }
      return true;
    }

    return false;
  }

  void logout() {
    _currentUser = null;
    _currentAdmin = null;
  }
}

final authService = AuthService();
