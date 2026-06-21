import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'stories/router.dart';
import 'stories/supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://62962a3f26d98d6a44a02aac50bec1df@o4511599354118144.ingest.us.sentry.io/4511599650144256';
      // Adds request headers and IP for users, for more info visit:
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      options.enableLogs = true;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      // Configure Session Replay
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    // All binding init and runApp happen inside Sentry's guarded zone so the
    // Flutter bindings are initialized in the same zone runApp runs in —
    // otherwise Flutter logs a "Zone mismatch" error.
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      // NOTE: rive_native (RiveNative.init) is intentionally NOT initialized
      // here. Its web init blocks the isolate and hangs app startup; the Rive
      // demo is disabled for now. Re-add init guarded per-platform if revived.
      // Loads bundled dream_book/.env (MJ_ACCESS_TOKEN / MJ_REFRESH_TOKEN /
      // MJ_CLIENT_ID). isOptional => app still runs (interactive OAuth) if absent.
      await dotenv.load(fileName: '.env', isOptional: true);
      // Initialize Supabase (defaults to local stack; override via dart-define).
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      runApp(ProviderScope(child: SentryWidget(child: const MainApp())));
    },
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'dream_book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: router,
    );
  }
}
