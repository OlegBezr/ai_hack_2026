import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'demos/deepgram_demo.dart';
import 'demos/midjourney_demo.dart';
import 'demos/rive_book_demo.dart';
import 'demos/turnable_page_demo.dart';
import 'theme/app_theme.dart';
import 'theme/magical_widgets.dart';

/// Enchanted landing page — routes to the app's demo screens.
///
/// A whimsical launcher we'll grow into a real product later. Each entry is a
/// glass card that pushes a self-contained demo.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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

    return MagicScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
              children: [
                const SizedBox(height: 12),
                const MagicWordmark(text: 'Dream Book', fontSize: 42),
                const SizedBox(height: 10),
                Text(
                  'Where your stories come to life',
                  textAlign: TextAlign.center,
                  style: AppTheme.serifFont(
                    fontSize: 19,
                    fontStyle: FontStyle.italic,
                    color: MagicColors.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                _PrimaryPortal(onTap: () => context.go('/stories')),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const _Sparkle(),
                    const SizedBox(width: 10),
                    Text(
                      'Pick a spell',
                      style: AppTheme.displayFont(fontSize: 18, letterSpacing: 1),
                    ),
                    const SizedBox(width: 10),
                    const _Sparkle(),
                  ],
                ),
                const SizedBox(height: 16),
                for (final demo in demos) ...[
                  _DemoCard(entry: demo),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero call-to-action — a glowing portal into the user's own stories.
class _PrimaryPortal extends StatelessWidget {
  const _PrimaryPortal({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [MagicColors.gold, MagicColors.amber],
              ),
              boxShadow: [
                BoxShadow(
                  color: MagicColors.gold.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.auto_stories, color: Color(0xFF2A1B05)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Stories',
                  style: AppTheme.displayFont(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to weave and edit your tales.',
                  style: AppTheme.bodyFont(
                    fontSize: 13,
                    color: MagicColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MagicColors.gold),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MagicColors.lilac.withValues(alpha: 0),
              MagicColors.lilac.withValues(alpha: 0.5),
              MagicColors.lilac.withValues(alpha: 0),
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
    return GlassCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: entry.builder)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MagicColors.lilac.withValues(alpha: 0.16),
              border: Border.all(
                color: MagicColors.lilac.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(entry.icon, color: MagicColors.lilac, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: AppTheme.bodyFont(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: AppTheme.bodyFont(
                    fontSize: 12.5,
                    color: MagicColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MagicColors.lilac),
        ],
      ),
    );
  }
}
