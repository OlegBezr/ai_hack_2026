import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/data/profile_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
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
      _showSnack(context, 'Failed to create story: $e', isError: true);
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
      _showSnack(context, 'Failed to delete: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);

    return MagicScaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        actions: [
          const _ProfileButton(),
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: MagicColors.gold),
        ),
        error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.read(storiesProvider.notifier).refresh(),
        ),
        data: (stories) {
          if (stories.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: MagicColors.gold,
            backgroundColor: MagicColors.nightMid,
            onRefresh: () => ref.read(storiesProvider.notifier).refresh(),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
                    itemCount: stories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final story = stories[i];
                      return _StoryCard(
                        story: story,
                        onTap: () => context.go('/stories/${story.id}'),
                        onRead: () => context.push('/read/${story.id}'),
                        onDelete: () => _deleteStory(context, ref, story),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: isError
          ? SnackBarAction(
              label: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: message)),
            )
          : null,
    ),
  );
}

/// App-bar entry point to the profile screen: a circular avatar showing the
/// user's initial. Reads the saved name (falls back to email) for the letter.
class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider).value?.name;
    final email = ref.watch(sessionProvider)?.user.email;
    final source = (name != null && name.trim().isNotEmpty) ? name : email;
    final initial = (source != null && source.trim().isNotEmpty)
        ? source.trim().characters.first.toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: 'Profile',
        onPressed: () => context.push('/profile'),
        icon: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [MagicColors.gold, MagicColors.amber],
            ),
            boxShadow: [
              BoxShadow(
                color: MagicColors.gold.withValues(alpha: 0.4),
                blurRadius: 14,
              ),
            ],
          ),
          child: Text(
            initial,
            style: AppTheme.bodyFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A1B05),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onTap,
    required this.onRead,
    required this.onDelete,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [MagicColors.gold, MagicColors.amber],
              ),
              boxShadow: [
                BoxShadow(
                  color: MagicColors.gold.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.menu_book, color: Color(0xFF2A1B05)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: AppTheme.serifFont(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${story.pages.length} page(s)',
                  style: AppTheme.bodyFont(
                    fontSize: 12.5,
                    color: MagicColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Read',
            icon: const Icon(Icons.auto_stories),
            color: MagicColors.gold,
            onPressed: onRead,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            color: MagicColors.textMuted,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_stories,
            size: 72,
            color: MagicColors.gold,
          ),
          const SizedBox(height: 16),
          Text(
            'Your library awaits',
            style: AppTheme.displayFont(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "New story" to begin your first tale.',
            style: AppTheme.bodyFont(color: MagicColors.textMuted),
          ),
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: MagicColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont(color: MagicColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
