import 'package:flutter/material.dart';
import 'package:turnable_page/turnable_page.dart';

import '../midjourney/midjourney_models.dart';

/// Full-screen reader that presents a Midjourney job's images as a
/// flippable book using `turnable_page`.
///
/// Page layout:
///   * page 0  → cover (title + prompt)
///   * page 1+ → one generated image per page
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({
    super.key,
    required this.job,
    this.title = 'My Dream Book',
  });

  /// The generated job whose images become the book's pages.
  final MidjourneyJob job;

  /// Shown on the cover page.
  final String title;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final PageFlipController _controller = PageFlipController();

  // One cover page + one page per image.
  int get _pageCount => widget.job.images.length + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2118),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
      ),
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

  Widget _buildPage(
    BuildContext context,
    int pageIndex,
    BoxConstraints constraints,
  ) {
    if (pageIndex == 0) return _coverPage();

    final image = widget.job.images[pageIndex - 1];
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Image.network(
              image.cdnUrl,
              fit: BoxFit.cover,
              width: double.infinity,
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
            padding: const EdgeInsets.all(12),
            child: Text(
              'Page $pageIndex',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3526), Color(0xFF8B5E3C)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories, size: 56, color: Colors.white70),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.job.images.length} pages',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

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
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () => _controller.nextPage(),
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}
