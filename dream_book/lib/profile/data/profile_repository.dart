import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stories/auth/auth_providers.dart';
import 'profile_model.dart';

/// Supabase data access for the current user's profile. RLS scopes every
/// query to the signed-in user, so we never filter by id from the client.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Not signed in');
    }
    return id;
  }

  /// The signed-in user's profile, or null if no row exists yet.
  Future<UserProfile?> fetchMyProfile() async {
    final row = await _client
        .from('profile')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  /// Upserts the display name and returns the saved profile. Upsert (rather
  /// than update) makes this resilient if the auto-provision trigger hasn't
  /// created the row yet.
  Future<UserProfile> updateName(String name) async {
    final row = await _client
        .from('profile')
        .upsert({'id': _userId, 'name': name})
        .select()
        .single();
    return UserProfile.fromJson(row);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's profile. Refreshable after edits.
class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() {
    return ref.watch(profileRepositoryProvider).fetchMyProfile();
  }

  /// Saves [name] and updates state with the result.
  Future<void> save(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateName(name),
    );
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);
