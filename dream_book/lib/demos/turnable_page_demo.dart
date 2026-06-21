import 'package:flutter/material.dart';
import 'package:turnable_page/turnable_page.dart';

/// Self-contained showcase of the `turnable_page` package.
///
/// This screen has NO external dependencies (no Midjourney / auth / network
/// credentials). It renders a small flippable book whose pages pull random
/// images from https://picsum.photos, which works on every platform — web
/// included — without any API keys.
///
/// Page layout:
///   * page 0  → styled cover (gradient + title + icon)
///   * page 1+ → one illustration + caption per page
class TurnablePageDemoScreen extends StatefulWidget {
  const TurnablePageDemoScreen({super.key});

  @override
  State<TurnablePageDemoScreen> createState() => _TurnablePageDemoScreenState();
}

class _TurnablePageDemoScreenState extends State<TurnablePageDemoScreen> {
  final PageFlipController _controller = PageFlipController();

  /// Captions for the content pages. The book has one cover page plus one
  /// page per caption below, so `_pageCount` is `_captions.length + 1`.
  static const List<String> _captions = <String>[
    'A quiet harbor at first light.',
    'Mountains wrapped in morning mist.',
    'City streets that never sleep.',
    'A forest path leading nowhere and everywhere.',
    'The last page, and a new beginning.',
  ];

  // One cover page + one page per caption.
  int get _pageCount => _captions.length + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1B2E),
      appBar: AppBar(title: const Text('Turnable Page Demo')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TurnablePage(
                  controller: _controller,
                  pageCount: _pageCount,
                  pageViewMode: PageViewMode.single,
                  paperBoundaryDecoration: PaperBoundaryDecoration.vintage,
                  settings: FlipSettings(
                    showCover: true,
                    drawShadow: true,
                    flippingTime: 700,
                  ),
                  builder: _buildPage,
                ),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  /// Builds a single page for the given [pageIndex].
  Widget _buildPage(
    BuildContext context,
    int pageIndex,
    BoxConstraints constraints,
  ) {
    if (pageIndex == 0) return _coverPage(context);

    // Content pages map 1:1 onto [_captions] (offset by the cover).
    final caption = _captions[pageIndex - 1];
    // Vary the seed per page so every illustration is distinct.
    final imageUrl = 'https://picsum.photos/seed/dreambook$pageIndex/800/1000';

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Page $pageIndex of ${_pageCount - 1}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The distinctive cover page: gradient background, icon, and title.
  Widget _coverPage(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A3093), Color(0xFFA044FF)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Turnable Page',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A flippable book demo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Drag a corner or use the arrows to flip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Previous / next controls wired to the [PageFlipController].
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _controller.previousPage(),
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
            iconSize: 32,
            tooltip: 'Previous page',
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () => _controller.nextPage(),
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            iconSize: 32,
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
