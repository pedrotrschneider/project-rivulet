import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/rivulet_api.dart';
import 'models/profile.dart';

part 'profiles_repository.g.dart';

class ProfilesRepository {
  final Dio _dio;

  ProfilesRepository(this._dio);

  /// Fetches all profiles for the current account.
  Future<List<Profile>> fetchProfiles() async {
    final response = await _dio.get('/profiles');
    final data = response.data as List<dynamic>;
    return data
        .map((json) => Profile.fromJson(json as Map<String, dynamic>))
        .toList();
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
