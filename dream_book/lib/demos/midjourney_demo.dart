import 'package:flutter/material.dart';

import '../midjourney/midjourney_auth.dart';
import '../midjourney/midjourney_client.dart';
import '../midjourney/midjourney_models.dart';

/// The lifecycle of a single image-generation request.
enum _Status { idle, loading, success, error }

/// Demo screen for Midjourney image generation.
///
/// Type a prompt, submit, and view the 4 generated images rendered straight
/// from their CDN URLs. The very first generation may trigger an interactive
/// OAuth flow (handled inside [MidjourneyAuth]).
class MidjourneyDemoScreen extends StatefulWidget {
  const MidjourneyDemoScreen({super.key});

  @override
  State<MidjourneyDemoScreen> createState() => _MidjourneyDemoScreenState();
}

class _MidjourneyDemoScreenState extends State<MidjourneyDemoScreen> {
  /// The client is built lazily and reused for the lifetime of the screen.
  /// `fromDotenv()` picks up the bundled tokens loaded in `main()`.
  late final MidjourneyClient _client = MidjourneyClient(
    auth: MidjourneyAuth.fromDotenv(),
  );

  final _promptController = TextEditingController(
    text: 'a big dragon --ar 16:9',
  );

  _Status _status = _Status.idle;
  String? _error;
  MidjourneyJob? _job;

  bool get _isLoading => _status == _Status.loading;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Submit the current prompt to Midjourney.
  ///
  /// Guards against concurrent requests and empty prompts, then drives the
  /// simple idle → loading → success/error state machine.
  Future<void> _generate() async {
    // Never fire a second request while one is already in flight.
    if (_isLoading) return;

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _status = _Status.error;
        _error = 'Please enter a prompt.';
      });
      return;
    }

    setState(() {
      _status = _Status.loading;
      _error = null;
    });

    try {
      // Blocks for tens of seconds and returns 4 images.
      final job = await _client.generateImage(prompt);
      if (!mounted) return;
      setState(() {
        _job = job;
        _status = _Status.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = _Status.error;
      });
    }
  }

  /// Open a single image full-screen in a zoomable dialog.
  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Pinch / scroll to zoom and pan.
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: _imageLoadingBuilder,
                  errorBuilder: _imageErrorBuilder,
                ),
              ),
            ),
            // A clear way out of the dialog.
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Midjourney Demo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPromptField(),
              const SizedBox(height: 12),
              _buildSubmitButton(),
              const SizedBox(height: 16),
              Expanded(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptField() {
    return TextField(
      controller: _promptController,
      enabled: !_isLoading,
      textInputAction: TextInputAction.go,
      // Submitting from the keyboard also triggers generation.
      onSubmitted: (_) => _generate(),
      minLines: 1,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Prompt',
        hintText: 'Describe an image… (Midjourney flags allowed)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton.icon(
      // Disabling while loading prevents duplicate requests.
      onPressed: _isLoading ? null : _generate,
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(_isLoading ? 'Generating…' : 'Generate'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  /// Renders the body region according to the current [_Status].
  Widget _buildResults(BuildContext context) {
    switch (_status) {
      case _Status.idle:
        return _buildIdle(context);
      case _Status.loading:
        return _buildLoading(context);
      case _Status.error:
        return _buildError(context);
      case _Status.success:
        return _buildGrid(context);
    }
  }

  Widget _buildIdle(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a prompt and tap Generate.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Generating your images…', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'This usually takes tens of seconds.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Generation failed',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final images = _job?.images ?? const <MidjourneyImage>[];
    if (images.isEmpty) {
      return _buildIdle(context);
    }
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [for (final img in images) _buildGridTile(context, img)],
    );
  }

  Widget _buildGridTile(BuildContext context, MidjourneyImage img) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          // Tap to view the image full-screen and zoomable.
          onTap: () => _openImage(context, img.cdnUrl),
          child: Image.network(
            img.cdnUrl,
            fit: BoxFit.cover,
            loadingBuilder: _imageLoadingBuilder,
            errorBuilder: _imageErrorBuilder,
          ),
        ),
      ),
    );
  }

  /// Shared progress indicator while a network image loads.
  Widget _imageLoadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? progress,
  ) {
    if (progress == null) return child;
    final expected = progress.expectedTotalBytes;
    return Center(
      child: CircularProgressIndicator(
        value: expected != null
            ? progress.cumulativeBytesLoaded / expected
            : null,
      ),
    );
  }

  /// Shared broken-image placeholder when a network image fails to load.
  Widget _imageErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
