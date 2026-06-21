import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shared Supabase client (initialized in main()).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Streams Supabase auth-state changes (sign in/out, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Convenience: the current session (null when signed out).
final sessionProvider = Provider<Session?>((ref) {
  // Re-evaluate whenever auth state changes.
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Thin wrapper around Supabase email-OTP auth.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  Future<void> verifyOtp(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);
