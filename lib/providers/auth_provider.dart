import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../services/storage_service.dart';

/// Demo passwordless authentication. In a production build this would be
/// backed by Supabase Auth email magic links. For this MVP preview, the
/// "magic link" step is simulated locally and clearly labeled as demo mode.
class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _restoreSession();
  }

  void _restoreSession() {
    final sessionBox = StorageService.box(StorageService.sessionBox);
    final uid = sessionBox.get('currentUserId');
    if (uid != null) {
      final usersBox = StorageService.box(StorageService.usersBox);
      final data = usersBox.get(uid);
      if (data != null) {
        _currentUser = AppUser.fromJson(Map<String, dynamic>.from(data));
        notifyListeners();
      }
    }
  }

  /// Simulates sending a magic link + immediate "click" for demo purposes.
  Future<AppUser> signInOrRegister({
    required String email,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final usersBox = StorageService.box(StorageService.usersBox);
    Map<dynamic, dynamic>? existing;
    String? existingKey;
    for (final key in usersBox.keys) {
      final data = usersBox.get(key);
      if (data != null && data['email'] == email) {
        existing = data;
        existingKey = key.toString();
        break;
      }
    }

    AppUser user;
    if (existing != null) {
      user = AppUser.fromJson(Map<String, dynamic>.from(existing));
      if (!user.hasRole(role)) {
        user.roles.add(role);
      }
      await usersBox.put(existingKey, user.toJson());
    } else {
      final id = const Uuid().v4();
      user = AppUser(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        roles: [role],
      );
      await usersBox.put(id, user.toJson());
    }

    final sessionBox = StorageService.box(StorageService.sessionBox);
    await sessionBox.put('currentUserId', user.id);

    _currentUser = user;
    _isLoading = false;
    notifyListeners();
    return user;
  }

  Future<void> addRole(UserRole role) async {
    if (_currentUser == null) return;
    if (!_currentUser!.hasRole(role)) {
      _currentUser!.roles.add(role);
      final usersBox = StorageService.box(StorageService.usersBox);
      await usersBox.put(_currentUser!.id, _currentUser!.toJson());
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? fullName, String? phone, String? city}) async {
    if (_currentUser == null) return;
    if (fullName != null) _currentUser!.fullName = fullName;
    if (phone != null) _currentUser!.phone = phone;
    if (city != null) _currentUser!.city = city;
    final usersBox = StorageService.box(StorageService.usersBox);
    await usersBox.put(_currentUser!.id, _currentUser!.toJson());
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final sessionBox = StorageService.box(StorageService.sessionBox);
    await sessionBox.delete('currentUserId');
    notifyListeners();
  }
}
