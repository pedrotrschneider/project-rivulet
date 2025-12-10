import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
class ServerUrl extends _$ServerUrl {
  static const _key = 'server_url';

  @override
  String? build() {
    return null;
  }

  Future<void> setUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
    state = url;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}

@riverpod
class Auth extends _$Auth {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return false;
  }

  Future<void> checkStatus() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getToken();

    if (token != null) {
      state = true;
      // Validate session immediately
      try {
        await repo.checkHealth();
        _startValidationTimer();
      } catch (e) {
        print('Session invalid on startup: $e');
        await logout();
      }
    } else {
      state = false;
    }
  }

  void _startValidationTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final repo = ref.read(authRepositoryProvider);
        await repo.checkHealth();
      } catch (e) {
        print('Session expired during validation: $e');
        _timer?.cancel();
        await logout();
      }
    });
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);
    if (result['access_token'] != null) {
      await repo.saveToken(
        result['access_token'],
        refreshToken: result['refresh_token'],
      );
      state = true;
      _startValidationTimer();
    }
  }

  Future<void> verify(String email, String code) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verify(email, code);

    print('Auth Verify Response: $result');

    if (result['access_token'] != null) {
      await repo.saveToken(
        result['access_token'],
        refreshToken: result['refresh_token'],
      );
      state = true;
      _startValidationTimer();
    } else {
      throw Exception(
        'Verification successful but no token received. Response: $result',
      );
    }
  }

  Future<void> logout() async {
    _timer?.cancel();
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = false;
  }
}
