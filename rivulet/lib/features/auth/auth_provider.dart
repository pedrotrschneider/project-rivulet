import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
class ServerUrl extends _$ServerUrl {
  static const _key = 'server_url';

  @override
  String? build() {
    // We load initial value synchronously if possible, or handle loading state in UI
    // For simplicity, we'll start with null and let a simpler provider read prefs
    // Actually, let's use a FutureProvider wrapper or just init here if we had prefs injected.
    // For now, simple state.
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
  @override
  bool build() {
    return false;
  }

  Future<void> checkStatus() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getToken();
    state = token != null;
  }

  Future<void> login(String email, String password) async {
    // This returns { otp_required: true } or { token: ... }
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);
    if (result['access_token'] != null) {
      await repo.saveToken(
        result['access_token'],
        refreshToken: result['refresh_token'],
      );
      state = true;
    }
    // If otp_required, we don't update state yet, UI handles the flow
  }

  Future<void> verify(String email, String code) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verify(email, code);

    // Add debug print to help user troubleshoot
    print('Auth Verify Response: $result');

    if (result['access_token'] != null) {
      await repo.saveToken(
        result['access_token'],
        refreshToken: result['refresh_token'],
      );
      state = true;
    } else {
      throw Exception(
        'Verification successful but no token received. Response: $result',
      );
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = false;
  }
}
