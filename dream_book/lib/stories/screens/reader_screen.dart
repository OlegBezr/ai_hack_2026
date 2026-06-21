import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../audio/background_music.dart';
import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
import '../data/models.dart';
import '../data/stories_repository.dart';

/// Page-flip "reading" experience for a single story, rendered as a book using
/// the `turnable_page` package in double (spread) mode. The book floats on the
/// shared twilight [MagicalBackground] for the magical look.
///
/// Leaf layout. In `turnable_page` double mode the book is always shown as an
/// open spread and leaves pair up as (0,1), (2,3), (4,5)… — i.e. EVEN leaves are
/// LEFT pages and ODD leaves are RIGHT pages:
///   leaf 0 (LEFT)    -> front cover (title over cover texture)
///   leaf 1 (RIGHT)   -> title page (next to the back of the cover)
///   leaf 2 (LEFT)    -> story page 0 text
///   leaf 3 (RIGHT)   -> story page 0 illustration
///   leaf 4 (LEFT)    -> story page 1 text
///   leaf 5 (RIGHT)   -> story page 1 illustration
///   ...                (text always LEFT, illustration always RIGHT)
///   last leaf        -> trailing blank page (behind the back cover)
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  static const Color _cream = Color(0xFFFFF8E7);
  static const Color _warmCover = Color(0xFF8D5524);

  final PageFlipController _controller = PageFlipController();

  @override
  void initState() {
    super.initState();
    // Reading mode is silent: pause the app-wide soundtrack while here.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(backgroundMusicProvider.notifier).pause(),
    );
  }

  @override
  void dispose() {
    // Resume the soundtrack when leaving the reader (respects mute state).
    ref.read(backgroundMusicProvider.notifier).ensureStarted();
    super.dispose();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/stories');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyAsync = ref.watch(storyProvider(widget.storyId));

    return MagicScaffold(
      // Reading mode is silent — no floating music controls here.
      showMusicControls: false,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: _exit,
        ),
        title: Text(storyAsync.maybeWhen(
          data: (s) => s.title,
          orElse: () => 'Reading',
        )),
      ),
      body: storyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MagicColors.gold),
        ),
        error: (e, _) => _ErrorState(message: '$e', onBack: _exit),
        data: (story) => _BookView(
          story: story,
          controller: _controller,
          buildLeaves: _buildLeaves,
        ),
      ),
    );
  }

  /// Builds the ordered list of leaf widgets for [TurnablePage].
  List<Widget> _buildLeaves(Story story) {
    final leaves = <Widget>[];

    // leaf 0 — front cover.
    leaves.add(_CoverPage(story: story, fallbackColor: _warmCover));

    // leaf 1 — title page (RIGHT of the opening spread, next to the cover).
    leaves.add(_InnerPage(
      story: story,
      fallbackColor: _cream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            story.title,
            textAlign: TextAlign.center,
            style: AppTheme.serifFont(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    ));

    // Each story page is its own spread: text (LEFT, even) then illustration
    // (RIGHT, odd). Cover+title occupy leaves 0,1 so page 0 starts at leaf 2.
    for (final page in story.pages) {
      leaves.add(_TextPage(story: story, page: page, fallbackColor: _cream));
      leaves.add(_IllustrationPage(story: story, page: page, fallbackColor: _cream));
    }

    // Trailing blank leaf so the final page (behind the back cover) is empty.
    leaves.add(_InnerPage(story: story, fallbackColor: _cream));

    return leaves;
  }
}

/// Centers and constrains the book, wiring up prev/next overlay buttons.
class _BookView extends StatelessWidget {
  const _BookView({
    required this.story,
    required this.controller,
    required this.buildLeaves,
  });

  final Story story;
  final PageFlipController controller;
  final List<Widget> Function(Story) buildLeaves;

  @override
  Widget build(BuildContext context) {
    final leaves = buildLeaves(story);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                TurnablePage(
                  controller: controller,
                  pageCount: leaves.length,
                  pageViewMode: PageViewMode.double,
                  builder: (context, index, constraints) => leaves[index],
                ),
                Positioned(
                  left: 0,
                  child: _NavButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous',
                    onPressed: () => controller.previousPage(),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _NavButton(
                    icon: Icons.chevron_right,
                    tooltip: 'Next',
                    onPressed: () => controller.nextPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassy circular page-turn button with a soft golden glow.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: MagicColors.gold.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
      child: Material(
        color: MagicColors.nightTop.withValues(alpha: 0.55),
        shape: CircleBorder(
          side: BorderSide(color: MagicColors.lilac.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: MagicColors.gold),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// A non-cover page: filled with the story style's background color, else cream.
class _InnerPage extends StatelessWidget {
  const _InnerPage({
    required this.story,
    required this.fallbackColor,
    this.child,
  });

  final Story story;
  final Color fallbackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bgColor = story.style.resolvedBackgroundColor ?? fallbackColor;
    return DecoratedBox(
      decoration: BoxDecoration(color: bgColor),
      child: SizedBox.expand(child: child),
    );
  }
}

/// Front cover: cover texture (or warm solid) with the title overlaid on a
/// legible scrim.
class _CoverPage extends StatelessWidget {
  const _CoverPage({required this.story, required this.fallbackColor});

  final Story story;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final texture = story.coverTexture;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fallbackColor,
        image: (texture != null && texture.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(texture),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent, Colors.black87],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Text(
          story.title,
          textAlign: TextAlign.center,
          style: AppTheme.displayFont(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ).copyWith(
            shadows: [
              const Shadow(
                blurRadius: 12,
                color: Colors.black,
                offset: Offset(0, 2),
              ),
              Shadow(
                color: MagicColors.gold.withValues(alpha: 0.5),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A story page's text, styled per [Story.style] (story-wide), scrollable.
class _TextPage extends StatelessWidget {
  const _TextPage({
    required this.story,
    required this.page,
    required this.fallbackColor,
  });

  final Story story;
  final StoryPage page;
  final Color fallbackColor;

  static String? _resolveFamily(String? fontFamily) {
    switch (fontFamily) {
      case 'Serif':
        return 'serif';
      case 'Mono':
        return 'monospace';
      default:
        return null; // 'Sans' / null -> platform default.
    }
  }

  TextStyle _textStyle() {
    final style = story.style;
    const base = 19.0;
    return TextStyle(
      fontFamily: _resolveFamily(style.fontFamily),
      fontSize: base * (style.fontSizeScale ?? 1.0),
      height: 1.5,
      color: style.resolvedTextColor ?? Colors.black87,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      story: story,
      fallbackColor: fallbackColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
        child: SingleChildScrollView(
          child: Text(
            page.text,
            textAlign: story.style.resolvedTextAlign,
            style: _textStyle(),
          ),
        ),
      ),
    );
  }
}

/// A story page's illustration filling the page, or a soft placeholder.
class _IllustrationPage extends StatelessWidget {
  const _IllustrationPage({
    required this.story,
    required this.page,
    required this.fallbackColor,
  });

  final Story story;
  final StoryPage page;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = page.illustrationUrl;
    if (url == null || url.isEmpty) {
      return _InnerPage(
        story: story,
        fallbackColor: fallbackColor,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 56, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'No illustration yet',
                style: TextStyle(color: Colors.black45, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: fallbackColor,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: MagicColors.gold),
          );
        },
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image_outlined,
              size: 56, color: Colors.black26),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
            FilledButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
