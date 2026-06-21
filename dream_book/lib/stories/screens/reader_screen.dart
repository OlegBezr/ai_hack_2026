import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:turnable_page/turnable_page.dart';

import '../../audio/background_music.dart';
import '../../audio/page_narration.dart';
import '../../book/book_voice_chat.dart';
import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
import '../data/models.dart';
import '../data/stories_repository.dart';

/// Page-flip "reading" experience for a single story, rendered as a book using
/// the `turnable_page` package. The book floats on the shared twilight
/// [MagicalBackground] for the magical look.
///
/// The reader is **adaptive**:
///   * On narrow screens (width < [_spreadBreakpoint], i.e. phones) it shows a
///     single portrait page at a time — illustration above text.
///   * On wider screens (tablet / web) it shows a classic open-book **spread**:
///     text on the LEFT page, illustration on the RIGHT page.
///
/// Both modes use `showCover: true`, which makes leaf 0 a standalone front
/// cover. With a cover, the package pairs leaves as `[0]`, `[1,2]`, `[3,4]`…
/// so the spread layout has *exact* parity (cover + one `text`/`illustration`
/// pair per story page) and never relies on the hidden white-page padding the
/// package injects for odd, cover-less books.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageFlipController _controller = PageFlipController();

  // Cached once while the widget is alive. Riverpod 3 forbids touching `ref`
  // inside dispose(), so we must hold the long-lived controller directly to be
  // able to resume the soundtrack as the reader is torn down.
  late final BackgroundMusicController _music;

  /// Dedicated player for per-page narration. Scoped to this screen — created
  /// here and disposed in [dispose].
  final PageNarrationController _narration = PageNarrationController();

  @override
  void initState() {
    super.initState();
    _music = ref.read(backgroundMusicProvider.notifier);
    // Reading mode swaps the app-wide soundtrack for per-page narration:
    // pause the background music while here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _music.pause());
  }

  @override
  void dispose() {
    _narration.dispose();
    // Resume the soundtrack when leaving the reader (respects mute state).
    _music.ensureStarted();
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
        title: Text(
          storyAsync.maybeWhen(data: (s) => s.title, orElse: () => 'Reading'),
        ),
        actions: [
          // Live voice-to-voice chat about this book (Deepgram Voice Agent).
          // Only offered once the story (and its full text) has loaded, since
          // the page text becomes the agent's system prompt.
          storyAsync.maybeWhen(
            data: (story) => IconButton(
              tooltip: 'Talk about this book',
              icon: const Icon(Icons.record_voice_over, color: MagicColors.gold),
              onPressed: () => showBookVoiceChat(context, story),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: storyAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MagicColors.gold),
          ),
          error: (e, _) => _ErrorState(message: '$e', onBack: _exit),
          data: (story) => _BookView(
            story: story,
            controller: _controller,
            narration: _narration,
          ),
        ),
      ),
    );
  }
}

/// Lays out the book responsively and wires up the bottom navigation controls.
class _BookView extends StatelessWidget {
  const _BookView({
    required this.story,
    required this.controller,
    required this.narration,
  });

  /// Below this width we render one page at a time (single mode); at or above
  /// it we render an open two-page spread (double mode).
  static const double _spreadBreakpoint = 600;

  static const Color _cream = Color(0xFFFFF8E7);
  static const Color _warmCover = Color(0xFF8D5524);

  final Story story;
  final PageFlipController controller;
  final PageNarrationController narration;

  /// Maps a flip engine *leaf* index (the left/first page of the now-current
  /// spread) to the story page it belongs to, then plays that page's narration.
  ///
  /// Leaf 0 is the standalone cover in both modes (no narration). After that:
  ///   * single mode — one leaf per story page: leaf `i` => `pages[i - 1]`.
  ///   * spread mode — each story page is a `text`+`illustration` pair, so the
  ///     left leaf `i` (the text page) => `pages[(i - 1) ~/ 2]`.
  void _onLeafOpened(int leftLeaf, bool isWide) {
    if (leftLeaf <= 0) {
      narration.openPage(null); // cover — silence
      return;
    }
    final pageIndex = isWide ? (leftLeaf - 1) ~/ 2 : leftLeaf - 1;
    if (pageIndex < 0 || pageIndex >= story.pages.length) return;
    narration.openPage(story.pages[pageIndex].audioUrl);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _spreadBreakpoint;
        final mode = isWide ? PageViewMode.double : PageViewMode.single;
        final leaves = isWide ? _buildSpreadLeaves() : _buildSinglePageLeaves();

        return Column(
          children: [
            Expanded(
              // Isolate the book's expensive custom painting (page curl,
              // shadows, network images) into its own layer. Without this, the
              // narration scrubber's per-tick `markNeedsPaint` walks up to the
              // nearest repaint boundary and drags the whole book into the
              // repaint every audio frame — the "blink", very visible on web.
              child: RepaintBoundary(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 1100 : 560,
                      maxHeight: 820,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isWide ? 24 : 12),
                      child: TurnablePage(
                        // Recreate the flip engine when the structure changes
                        // (single<->double or page count) so its internal state
                        // never goes stale — the package has no didUpdateWidget.
                        key: ValueKey('book-${mode.name}-${leaves.length}'),
                        controller: controller,
                        pageCount: leaves.length,
                        pageViewMode: mode,
                        paperBoundaryDecoration:
                            PaperBoundaryDecoration.vintage,
                        onPageChanged: (left, _) => _onLeafOpened(left, isWide),
                        settings: FlipSettings(
                          showCover: true,
                          drawShadow: true,
                          flippingTime: 700,
                          // Match the package's blank-page / flip backing fill to
                          // the paper color so the moving leaf and any blank
                          // (cover) side blend with the spread instead of
                          // flashing stark white mid-flip.
                          paperColor:
                              story.style.resolvedBackgroundColor ?? _cream,
                        ),
                        builder: (context, index, _) => leaves[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bar paints in its own layer so the scrubber's per-tick repaint
            // never bubbles up to the book.
            RepaintBoundary(child: _NarrationBar(narration: narration)),
            _ReaderControls(controller: controller),
          ],
        );
      },
    );
  }

  /// Single-page (portrait) leaves: a cover, then one combined page per story
  /// page (illustration above text). Pairs trivially in single mode.
  List<Widget> _buildSinglePageLeaves() {
    return <Widget>[
      _CoverPage(story: story, fallbackColor: _warmCover),
      for (final page in story.pages)
        _StoryPageSingle(story: story, page: page, fallbackColor: _cream),
    ];
  }

  /// Spread (double-page) leaves. With `showCover: true` the cover stands alone
  /// as `[0]`, then each story page is its own spread: text LEFT, illustration
  /// RIGHT — i.e. `[1,2]`, `[3,4]`, … Total `1 + 2 * pages` leaves pairs exactly.
  List<Widget> _buildSpreadLeaves() {
    return <Widget>[
      _CoverPage(story: story, fallbackColor: _warmCover),
      for (final page in story.pages) ...[
        _TextPage(story: story, page: page, fallbackColor: _cream),
        _IllustrationPage(story: story, page: page, fallbackColor: _cream),
      ],
    ];
  }
}

/// Bottom navigation bar with previous / next page controls. Kept *below* the
/// book (not overlaid on its edges) so it never competes with the corner-drag
/// and swipe gestures the package uses to flip pages.
class _ReaderControls extends StatelessWidget {
  const _ReaderControls({required this.controller});

  final PageFlipController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            tooltip: 'Previous',
            onPressed: () => controller.previousPage(),
          ),
          const SizedBox(width: 32),
          _NavButton(
            icon: Icons.chevron_right,
            tooltip: 'Next',
            onPressed: () => controller.nextPage(),
          ),
        ],
      ),
    );
  }
}

/// Narration controls for the open page: play / pause, a scrubber, a restart
/// button, and an auto-narrate toggle. Sits just above the page-turn controls.
///
/// Constrained to [_maxWidth] and centered so it stays a tidy pill on wide
/// (desktop / tablet) screens instead of stretching edge to edge.
///
/// Pinned to a *fixed* [_height]: the bar is a sibling of the `Expanded` book
/// in the reader's [Column], so any change to its intrinsic height would
/// re-fire the book's `LayoutBuilder` and make the page flash. A fixed height
/// means position ticks (which only swap the [Slider] value via a scoped
/// [StreamBuilder]) and state transitions never relayout the book.
class _NarrationBar extends StatelessWidget {
  const _NarrationBar({required this.narration});

  final PageNarrationController narration;

  /// Keeps the pill from sprawling across desktop widths.
  static const double _maxWidth = 520;

  /// Constant bar height — see the class doc for why this must not vary.
  static const double _height = 84;

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: ListenableBuilder(
          listenable: narration,
          builder: (context, _) {
            final hasAudio = narration.hasAudio;
            return Container(
              height: _height,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MagicColors.nightTop.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: MagicColors.lilac.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  _playButton(hasAudio),
                  const SizedBox(width: 8),
                  Expanded(child: _scrubber(context, hasAudio)),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Restart narration',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.replay, size: 20),
                    color: hasAudio
                        ? MagicColors.textPrimary
                        : MagicColors.textMuted.withValues(alpha: 0.4),
                    onPressed: hasAudio ? narration.replay : null,
                  ),
                  IconButton(
                    tooltip: narration.autoplay
                        ? 'Auto-narrate on'
                        : 'Auto-narrate off',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      narration.autoplay
                          ? Icons.auto_stories
                          : Icons.auto_stories_outlined,
                      size: 20,
                    ),
                    color: narration.autoplay
                        ? MagicColors.gold
                        : MagicColors.textMuted,
                    onPressed: () => narration.setAutoplay(!narration.autoplay),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _playButton(bool hasAudio) {
    if (narration.isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(9),
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: MagicColors.gold,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: hasAudio
          ? (narration.isPlaying ? 'Pause' : 'Play narration')
          : 'No narration on this page',
      icon: Icon(
        narration.isPlaying
            ? Icons.pause_circle_filled
            : Icons.play_circle_fill,
      ),
      iconSize: 40,
      color: hasAudio
          ? MagicColors.gold
          : MagicColors.textMuted.withValues(alpha: 0.4),
      onPressed: hasAudio ? narration.togglePlay : null,
    );
  }

  Widget _scrubber(BuildContext context, bool hasAudio) {
    if (!hasAudio) {
      return const Text(
        'No narration on this page',
        style: TextStyle(color: MagicColors.textMuted, fontSize: 13),
      );
    }
    return StreamBuilder<Duration>(
      stream: narration.positionStream,
      builder: (context, snapshot) {
        final total = narration.duration ?? Duration.zero;
        final pos = snapshot.data ?? Duration.zero;
        final maxMs = total.inMilliseconds.toDouble();
        final value = maxMs <= 0
            ? 0.0
            : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: MagicColors.gold,
                inactiveTrackColor: MagicColors.textMuted.withValues(
                  alpha: 0.3,
                ),
                thumbColor: MagicColors.gold,
                overlayColor: MagicColors.gold.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: maxMs <= 0 ? 0 : value,
                max: maxMs <= 0 ? 1 : maxMs,
                onChanged: maxMs <= 0
                    ? null
                    : (v) => narration.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(
                      color: MagicColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _fmt(total),
                    style: const TextStyle(
                      color: MagicColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
            ? DecorationImage(image: NetworkImage(texture), fit: BoxFit.cover)
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
          style:
              AppTheme.displayFont(
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

/// Resolves a [StoryStyle.fontFamily] token to a platform family name.
String? _resolveFamily(String? fontFamily) {
  switch (fontFamily) {
    case 'Serif':
      return 'serif';
    case 'Mono':
      return 'monospace';
    default:
      return null; // 'Sans' / null -> platform default.
  }
}

/// The styled body text for a story page, per [Story.style] (story-wide).
TextStyle _bodyTextStyle(Story story) {
  final style = story.style;
  const base = 19.0;
  return TextStyle(
    fontFamily: _resolveFamily(style.fontFamily),
    fontSize: base * (style.fontSizeScale ?? 1.0),
    height: 1.5,
    color: style.resolvedTextColor ?? Colors.black87,
  );
}

/// A network illustration filling its box, with loading / error fallbacks.
/// Returns a soft placeholder when the page has no illustration yet.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.url, required this.fallbackColor});

  final String? url;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: fallbackColor,
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
          child: Icon(
            Icons.broken_image_outlined,
            size: 56,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }
}

/// SPREAD MODE — a story page's text on the LEFT page (scrollable).
class _TextPage extends StatelessWidget {
  const _TextPage({
    required this.story,
    required this.page,
    required this.fallbackColor,
  });

  final Story story;
  final StoryPage page;
  final Color fallbackColor;

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
            style: _bodyTextStyle(story),
          ),
        ),
      ),
    );
  }
}

/// SPREAD MODE — a story page's illustration filling the RIGHT page.
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
    return _Illustration(
      url: page.illustrationUrl,
      fallbackColor: fallbackColor,
    );
  }
}

/// SINGLE MODE — one combined page: illustration on top, text below.
class _StoryPageSingle extends StatelessWidget {
  const _StoryPageSingle({
    required this.story,
    required this.page,
    required this.fallbackColor,
  });

  final Story story;
  final StoryPage page;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return _InnerPage(
      story: story,
      fallbackColor: fallbackColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration takes the top ~55% of the page.
          Expanded(
            flex: 55,
            child: _Illustration(
              url: page.illustrationUrl,
              fallbackColor: fallbackColor,
            ),
          ),
          Expanded(
            flex: 45,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: SingleChildScrollView(
                child: Text(
                  page.text,
                  textAlign: story.style.resolvedTextAlign,
                  style: _bodyTextStyle(story),
                ),
              ),
            ),
          ),
        ],
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
            FilledButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
