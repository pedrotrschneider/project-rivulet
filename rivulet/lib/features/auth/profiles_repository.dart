import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/rivulet_api.dart';
import 'models/profile.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

part 'profiles_repository.g.dart';

class ProfilesRepository {
  final Dio _dio;
  static const _cacheKey = 'cached_profiles';

  ProfilesRepository(this._dio);

  /// Fetches all profiles for the current account.
  /// Caches successful responses.
  Future<List<Profile>> fetchProfiles() async {
    final response = await _dio.get('/profiles');
    final data = response.data as List<dynamic>;

    // Cache the raw JSON list
    await _cacheProfiles(data);

    return data
        .map((json) => Profile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Saves the profiles list to SharedPreferences.
  Future<void> _cacheProfiles(List<dynamic> profilesJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(profilesJson));
    } catch (_) {
      // Ignore caching errors
    }
  }

  /// Retrieves cached profiles if available.
  Future<List<Profile>> getCachedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data
            .map((json) => Profile.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Ignore cache reading errors
    }
    return [];
  }

  /// Creates a new profile with the given name and optional avatar.
  /// If no avatar is provided, the backend generates one using DiceBear.
  Future<Profile> createProfile(String name, {String? avatar}) async {
    final response = await _dio.post(
      '/profiles',
      data: {'name': name, if (avatar != null) 'avatar': avatar},
    );
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
ProfilesRepository profilesRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return ProfilesRepository(dio);
}
