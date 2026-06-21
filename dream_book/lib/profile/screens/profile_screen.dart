import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../stories/auth/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
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

    final name = _nameController.text.trim();
    final initial = name.isNotEmpty
        ? name.characters.first.toUpperCase()
        : (email != null && email.isNotEmpty
              ? email.characters.first.toUpperCase()
              : '?');

    return MagicScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(onPressed: _close),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: MagicColors.gold),
              ),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(profileProvider),
              ),
              data: (profile) {
                _seed(profile);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                  children: [
                    // ── Avatar header ──────────────────────────────────────
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [MagicColors.gold, MagicColors.amber],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MagicColors.gold.withValues(alpha: 0.45),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: Text(
                          initial,
                          style: AppTheme.displayFont(
                            fontSize: 40,
                            color: const Color(0xFF2A1B05),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Read-only account info ─────────────────────────────
                    // Email is rendered as plain info (not an input) so the
                    // only thing that looks editable here is the name field.
                    if (email != null) ...[
                      const _SectionLabel('Account'),
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: MagicColors.lilac,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email',
                                    style: AppTheme.bodyFont(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: AppTheme.bodyFont(
                                      fontSize: 13,
                                      color: MagicColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tooltip(
                              message: "Can't be changed",
                              child: Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: MagicColors.textMuted.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
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
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Your display name',
                        helperText: 'How your name appears in the app.',
                        prefixIcon: Icon(Icons.badge_outlined),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2A1B05),
                              ),
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
    return Text(
      text.toUpperCase(),
      style: AppTheme.bodyFont(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MagicColors.gold,
        letterSpacing: 1.0,
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
          const Icon(Icons.error_outline, size: 48, color: MagicColors.danger),
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
    );
  }
}
