import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../stories/auth/auth_providers.dart';
import '../data/profile_model.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Populate the field once, the first time the profile loads.
  void _seed(UserProfile? profile) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = profile?.name ?? '';
  }

  /// Leave the screen: pop if we were pushed onto a stack, otherwise fall back
  /// to the stories list (covers deep-links straight to /profile).
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/stories');
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(name);
      if (!mounted) return;
      _showSnack('Profile saved');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: isError
            ? SnackBarAction(
                label: 'Copy',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: message)),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final email = ref.watch(sessionProvider)?.user.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(onPressed: _close),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (profile) {
              _seed(profile);
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // ── Read-only account info ─────────────────────────────
                  // Email is rendered as plain info (not an input) so the only
                  // thing that looks editable on this screen is the name field.
                  if (email != null) ...[
                    const _SectionLabel('Account'),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(email),
                        trailing: Tooltip(
                          message: "Can't be changed",
                          child: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Editable display name ──────────────────────────────
                  const _SectionLabel('Display name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Your display name',
                      helperText: 'How your name appears in the app.',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _saving ? null : _save(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Small muted section heading used to group the form.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
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
    return Padding(
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
    );
  }
}
