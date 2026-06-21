import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'demos/deepgram_demo.dart';
import 'demos/midjourney_demo.dart';
import 'demos/rive_book_demo.dart';
import 'demos/turnable_page_demo.dart';

/// Simple landing page that routes to the app's demo screens.
///
/// This is intentionally lightweight — a launcher we'll grow into a real
/// product later. Each entry is a card that pushes a self-contained demo.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final demos = <_DemoEntry>[
      _DemoEntry(
        title: 'Turnable Page',
        subtitle: 'Flippable book powered by the turnable_page package.',
        icon: Icons.auto_stories,
        builder: (_) => const TurnablePageDemoScreen(),
      ),
      _DemoEntry(
        title: 'Rive 3D Page Flip',
        subtitle: 'Interactive 3D book rendered with the Rive runtime.',
        icon: Icons.menu_book,
        builder: (_) => const RiveBookDemoScreen(),
      ),
      _DemoEntry(
        title: 'Midjourney Image Generation',
        subtitle: 'Prompt → 4 generated images, rendered from their URLs.',
        icon: Icons.auto_awesome,
        builder: (_) => const MidjourneyDemoScreen(),
      ),
      _DemoEntry(
        title: 'Deepgram Speech',
        subtitle: 'Speech-to-text and text-to-speech over REST.',
        icon: Icons.record_voice_over,
        builder: (_) => const DeepgramDemoScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('dream_book · Demos')),
      body: Center(
        child: ConstrainedBox(
          // Keep the launcher readable on wide web/desktop windows.
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: const Icon(Icons.auto_stories),
                  ),
                  title: Text(
                    'My Stories (Login)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    'Sign in to create and edit your stories.',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  onTap: () => context.go('/stories'),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Pick a demo',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              for (final demo in demos) ...[
                _DemoCard(entry: demo),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoEntry {
  const _DemoEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.entry});

  final _DemoEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(entry.icon),
        ),
        title: Text(entry.title, style: theme.textTheme.titleMedium),
        subtitle: Text(entry.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: entry.builder)),
      ),
    );
  }
}
