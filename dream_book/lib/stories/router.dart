import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home_page.dart';
import '../profile/screens/profile_screen.dart';
import 'screens/create_story_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/stories_list_screen.dart';
import 'screens/story_editor_screen.dart';

/// Bridges a [Stream] to a [Listenable] so go_router re-evaluates redirects
/// whenever Supabase auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = GoRouterRefreshStream(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final loc = state.matchedLocation;
      final atLogin = loc == '/stories/login';
      final inStories = loc.startsWith('/stories');
      final inProfile = loc.startsWith('/profile');
      final inRead = loc.startsWith('/read');
      final inCreate = loc.startsWith('/create');
      final requiresAuth =
          (inStories && !atLogin) || inProfile || inRead || inCreate;

      if (!loggedIn && requiresAuth) {
        return '/stories/login';
      }
      if (loggedIn && atLogin) {
        return '/stories';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/stories/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoriesListScreen(),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/stories/:id',
        builder: (context, state) =>
            StoryEditorScreen(storyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/read/:id',
        builder: (context, state) =>
            ReaderScreen(storyId: state.pathParameters['id']!),
      ),
    ],
  );
});
