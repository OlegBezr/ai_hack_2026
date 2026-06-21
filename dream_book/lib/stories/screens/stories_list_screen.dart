import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../data/models.dart';
import '../data/stories_repository.dart';

class StoriesListScreen extends ConsumerWidget {
  const StoriesListScreen({super.key});

  Future<void> _createStory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'New story');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New story'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    if (!context.mounted) return;

    try {
      final story = await ref
          .read(storiesRepositoryProvider)
          .createStory(title);
      await ref.read(storiesProvider.notifier).refresh();
      if (!context.mounted) return;
      context.go('/stories/${story.id}');
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Failed to create story: $e');
    }
  }

  Future<void> _deleteStory(
    BuildContext context,
    WidgetRef ref,
    Story story,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete story?'),
        content: Text('"${story.title}" and its pages will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(storiesRepositoryProvider).deleteStory(story.id);
      await ref.read(storiesProvider.notifier).refresh();
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Failed to delete: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(storiesProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createStory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New story'),
      ),
      body: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.read(storiesProvider.notifier).refresh(),
        ),
        data: (stories) {
          if (stories.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(storiesProvider.notifier).refresh(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final story = stories[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.menu_book),
                        ),
                        title: Text(story.title),
                        subtitle: Text('${story.pages.length} page(s)'),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteStory(context, ref, story),
                        ),
                        onTap: () => context.go('/stories/${story.id}'),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, size: 64),
          const SizedBox(height: 12),
          Text(
            'No stories yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Tap "New story" to create one.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
