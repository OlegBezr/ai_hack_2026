import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';
import '../data/stories_repository.dart';

class StoryEditorScreen extends ConsumerStatefulWidget {
  const StoryEditorScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  StoriesRepository get _repo => ref.read(storiesRepositoryProvider);

  Story? _story;
  bool _loading = true;
  String? _error;

  final _titleController = TextEditingController();
  bool _savingTitle = false;
  bool _generatingCover = false;

  // Story-wide page styling (applies to all pages).
  StoryStyle _style = const StoryStyle();
  bool _savingStyle = false;

  // Curated preset swatches for the text/background color pickers.
  static const List<Color?> _colorSwatches = [
    null, // default (no override)
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFF5D4037), // brown
    Color(0xFFB71C1C), // red
    Color(0xFF1A237E), // indigo
    Color(0xFFF5EFE0), // cream
  ];

  static String _hexFromColor(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stories = await _repo.listStories();
      final story = stories.firstWhere(
        (s) => s.id == widget.storyId,
        orElse: () => throw StateError('Story not found'),
      );
      _titleController.text = story.title;
      if (!mounted) return;
      setState(() {
        _story = story;
        _style = story.style;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: isError
            ? SnackBarAction(
                label: 'Copy',
                onPressed: () => Clipboard.setData(ClipboardData(text: msg)),
              )
            : null,
      ),
    );
  }

  Future<void> _saveTitle() async {
    final story = _story;
    if (story == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty || title == story.title) return;
    setState(() => _savingTitle = true);
    try {
      await _repo.updateStory(story.id, title: title);
      ref.read(storiesProvider.notifier).refresh();
      _snack('Title saved');
    } catch (e) {
      _snack('Failed to save title: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingTitle = false);
    }
  }

  /// Prompts for a description and generates the Midjourney cover art.
  Future<void> _generateCover() async {
    final story = _story;
    if (story == null) return;
    final controller = TextEditingController(text: story.title);
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cover texture prompt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe the cover texture...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (prompt == null || prompt.isEmpty) return;

    setState(() => _generatingCover = true);
    try {
      await _repo.generateCoverTexture(story.id, prompt);
      if (!mounted) return;
      ref.read(storiesProvider.notifier).refresh();
      await _load();
      _snack('Cover texture generated');
    } catch (e) {
      _snack('Cover generation failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingCover = false);
    }
  }

  /// Persists the story-wide style. Built directly (not via copyWith) so any
  /// field can be cleared back to null.
  Future<void> _applyStyle(StoryStyle next) async {
    final story = _story;
    if (story == null) return;
    setState(() {
      _style = next;
      _savingStyle = true;
    });
    try {
      await _repo.updateStory(story.id, style: next);
      ref.read(storiesProvider.notifier).refresh();
      _snack('Style saved');
    } catch (e) {
      _snack('Failed to save style: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingStyle = false);
    }
  }

  Future<void> _addPage() async {
    final story = _story;
    if (story == null) return;
    final nextPos = story.pages.isEmpty
        ? 0
        : story.pages.map((p) => p.position).reduce((a, b) => a > b ? a : b) +
              1;
    try {
      await _repo.createPage(story.id, nextPos, '');
      await _load();
    } catch (e) {
      _snack('Failed to add page: $e', isError: true);
    }
  }

  Future<void> _deletePage(StoryPage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete page?'),
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
    try {
      await _repo.deletePage(page.id);
      await _load();
    } catch (e) {
      _snack('Failed to delete page: $e', isError: true);
    }
  }

  /// Swaps the position values of two adjacent pages.
  Future<void> _movePage(int index, int delta) async {
    final story = _story;
    if (story == null) return;
    final target = index + delta;
    if (target < 0 || target >= story.pages.length) return;
    final a = story.pages[index];
    final b = story.pages[target];
    try {
      // Use a temporary position to dodge the unique(story_id, position) index.
      await _repo.updatePage(a.id, position: -1);
      await _repo.updatePage(b.id, position: a.position);
      await _repo.updatePage(a.id, position: b.position);
      await _load();
    } catch (e) {
      _snack('Failed to reorder: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/stories'),
        ),
        title: const Text('Edit story'),
      ),
      floatingActionButton: _story == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addPage,
              icon: const Icon(Icons.note_add),
              label: const Text('Add page'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final story = _story!;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Story title',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _saveTitle(),
                  ),
                ),
                const SizedBox(width: 8),
                _savingTitle
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        tooltip: 'Save title',
                        icon: const Icon(Icons.save),
                        onPressed: _saveTitle,
                      ),
              ],
            ),
            const SizedBox(height: 16),

            // Cover texture (Midjourney).
            _buildTextureSection(
              theme: theme,
              label: 'Cover',
              url: story.coverTexture,
              busy: _generatingCover,
              buttonLabel: 'Generate cover texture',
              onGenerate: _generateCover,
            ),
            const SizedBox(height: 16),

            // Story-wide page styling.
            _buildStyleSection(theme),
            const SizedBox(height: 16),

            Text('Pages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (story.pages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No pages yet. Add one below.')),
              ),
            for (var i = 0; i < story.pages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PageEditor(
                  key: ValueKey(story.pages[i].id),
                  page: story.pages[i],
                  index: i,
                  total: story.pages.length,
                  repo: _repo,
                  onChanged: _load,
                  onDelete: () => _deletePage(story.pages[i]),
                  onMoveUp: () => _movePage(i, -1),
                  onMoveDown: () => _movePage(i, 1),
                  snack: _snack,
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// A texture (cover or page background) preview + generate button.
  Widget _buildTextureSection({
    required ThemeData theme,
    required String label,
    required String? url,
    required bool busy,
    required String buttonLabel,
    required VoidCallback onGenerate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (url != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Text('Could not load texture.'),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onGenerate,
            icon: busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wallpaper),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }

  /// Story-wide text styling (applies to every page).
  Widget _buildStyleSection(ThemeData theme) {
    final scale = _style.fontSizeScale ?? 1.0;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            const Text('Page text style'),
            if (_savingStyle) ...[
              const SizedBox(width: 8),
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        subtitle: const Text('Applies to all pages'),
        children: [
          // Font family.
          Row(
            children: [
              const SizedBox(width: 90, child: Text('Font')),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _style.fontFamily,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Default')),
                    DropdownMenuItem(value: 'Serif', child: Text('Serif')),
                    DropdownMenuItem(value: 'Sans', child: Text('Sans')),
                    DropdownMenuItem(value: 'Mono', child: Text('Mono')),
                  ],
                  onChanged: (value) =>
                      _applyStyle(_styleWith(fontFamily: value, clearFont: true)),
                ),
              ),
            ],
          ),
          // Font size scale.
          Row(
            children: [
              const SizedBox(width: 90, child: Text('Size')),
              Expanded(
                child: Slider(
                  min: 0.8,
                  max: 2.0,
                  divisions: 12,
                  value: scale.clamp(0.8, 2.0),
                  label: scale.toStringAsFixed(2),
                  onChanged: (value) => setState(
                    () => _style = _styleWith(fontSizeScale: value),
                  ),
                  onChangeEnd: (value) =>
                      _applyStyle(_styleWith(fontSizeScale: value)),
                ),
              ),
            ],
          ),
          // Text alignment.
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String?>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
                ButtonSegment(
                  value: 'center',
                  icon: Icon(Icons.format_align_center),
                ),
                ButtonSegment(
                  value: 'right',
                  icon: Icon(Icons.format_align_right),
                ),
                ButtonSegment(
                  value: 'justify',
                  icon: Icon(Icons.format_align_justify),
                ),
              ],
              selected: {_style.textAlign ?? 'left'},
              onSelectionChanged: (selection) =>
                  _applyStyle(_styleWith(textAlign: selection.first)),
            ),
          ),
          const SizedBox(height: 8),
          // Text color swatches.
          _buildColorRow(
            label: 'Text color',
            selectedHex: _style.textColor,
            onPick: (hex) =>
                _applyStyle(_styleWith(textColor: hex, clearText: true)),
          ),
          const SizedBox(height: 8),
          // Page background color swatches.
          _buildColorRow(
            label: 'Page background',
            selectedHex: _style.backgroundColor,
            onPick: (hex) =>
                _applyStyle(_styleWith(backgroundColor: hex, clearBg: true)),
          ),
          const SizedBox(height: 12),
          // Live preview.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _style.resolvedBackgroundColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text(
              'Once upon a time, in a land far away...',
              textAlign: _style.resolvedTextAlign,
              style: TextStyle(
                color: _style.resolvedTextColor,
                fontSize: 14 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a new style from the current one, allowing fields to be set to null
  /// (the `clear*` flags let a null value through instead of being ignored).
  StoryStyle _styleWith({
    String? fontFamily,
    bool clearFont = false,
    double? fontSizeScale,
    String? textColor,
    bool clearText = false,
    String? backgroundColor,
    bool clearBg = false,
    String? textAlign,
  }) {
    return StoryStyle(
      fontFamily: clearFont ? fontFamily : (fontFamily ?? _style.fontFamily),
      fontSizeScale: fontSizeScale ?? _style.fontSizeScale,
      textColor: clearText ? textColor : (textColor ?? _style.textColor),
      backgroundColor:
          clearBg ? backgroundColor : (backgroundColor ?? _style.backgroundColor),
      textAlign: textAlign ?? _style.textAlign,
    );
  }

  Widget _buildColorRow({
    required String label,
    required String? selectedHex,
    required void Function(String?) onPick,
  }) {
    // True when the current value is a custom color (not one of the presets).
    final isCustom = selectedHex != null &&
        !_colorSwatches.any((c) =>
            c != null &&
            _hexFromColor(c).toUpperCase() == selectedHex.toUpperCase());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _colorSwatches)
                _buildSwatch(
                  color: color,
                  selected: color == null
                      ? selectedHex == null
                      : selectedHex?.toUpperCase() ==
                            _hexFromColor(color).toUpperCase(),
                  onTap: () =>
                      onPick(color == null ? null : _hexFromColor(color)),
                ),
              // Custom color picker swatch.
              _buildCustomSwatch(
                selectedHex: isCustom ? selectedHex : null,
                onTap: () async {
                  final hex = await _showCustomColorDialog(selectedHex);
                  if (hex != null) onPick(hex);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The "+" swatch that opens the custom color picker. Shows the picked custom
  /// color (with a ring) when the current value is a custom one.
  Widget _buildCustomSwatch({
    required String? selectedHex,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final custom = StoryStyle.parseColor(selectedHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: custom,
          shape: BoxShape.circle,
          gradient: custom == null
              ? const SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                )
              : null,
          border: Border.all(
            color: custom != null ? theme.colorScheme.primary : theme.dividerColor,
            width: custom != null ? 2.5 : 1,
          ),
        ),
        child: Icon(
          Icons.add,
          size: 16,
          color: custom == null ? Colors.white : Colors.white,
        ),
      ),
    );
  }

  /// A dependency-free RGB color picker. Returns a '#RRGGBB' hex, or null on
  /// cancel.
  Future<String?> _showCustomColorDialog(String? currentHex) {
    var picked = StoryStyle.parseColor(currentHex) ?? const Color(0xFF3F51B5);
    int chan(double c) => (c * 255).round();

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final r = chan(picked.r);
          final g = chan(picked.g);
          final b = chan(picked.b);

          Widget channel(String name, int value, Color tint,
              Color Function(int) rebuild) {
            return Row(
              children: [
                SizedBox(width: 16, child: Text(name)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(activeTrackColor: tint),
                    child: Slider(
                      min: 0,
                      max: 255,
                      divisions: 255,
                      value: value.toDouble(),
                      label: '$value',
                      onChanged: (v) =>
                          setLocal(() => picked = rebuild(v.round())),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$value', textAlign: TextAlign.end),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Custom color'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: picked,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _hexFromColor(picked),
                    style: TextStyle(
                      color: picked.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontFeatures: const [],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                channel('R', r, Colors.red,
                    (v) => Color.fromARGB(255, v, g, b)),
                channel('G', g, Colors.green,
                    (v) => Color.fromARGB(255, r, v, b)),
                channel('B', b, Colors.blue,
                    (v) => Color.fromARGB(255, r, g, v)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_hexFromColor(picked)),
                child: const Text('Select'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwatch({
    required Color? color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
        // "Default" (null) swatch shows a slash to indicate "no override".
        child: color == null
            ? Icon(Icons.block, size: 16, color: theme.hintColor)
            : null,
      ),
    );
  }
}

class _PageEditor extends StatefulWidget {
  const _PageEditor({
    super.key,
    required this.page,
    required this.index,
    required this.total,
    required this.repo,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.snack,
  });

  final StoryPage page;
  final int index;
  final int total;
  final StoriesRepository repo;
  final Future<void> Function() onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(String, {bool isError}) snack;

  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final TextEditingController _textController;
  final _audioPlayer = AudioPlayer();

  bool _savingText = false;
  bool _generatingImage = false;
  bool _generatingAudio = false;

  String? _illustrationUrl;
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.page.text);
    _illustrationUrl = widget.page.illustrationUrl;
    _audioUrl = widget.page.audioUrl;
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveText() async {
    setState(() => _savingText = true);
    try {
      await widget.repo.updatePage(widget.page.id, text: _textController.text);
      widget.snack('Page saved');
    } catch (e) {
      widget.snack('Failed to save page: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingText = false);
    }
  }

  Future<void> _generateIllustration() async {
    final controller = TextEditingController(
      text: _textController.text.trim().isEmpty
          ? ''
          : _textController.text.trim(),
    );
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Illustration prompt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe the illustration...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (prompt == null || prompt.isEmpty) return;

    setState(() => _generatingImage = true);
    try {
      final url = await widget.repo.generateIllustration(widget.page.id, prompt);
      if (!mounted) return;
      setState(() => _illustrationUrl = url);
      widget.snack('Illustration generated');
    } catch (e) {
      widget.snack('Illustration failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _generateAudio() async {
    setState(() => _generatingAudio = true);
    try {
      final text = _textController.text.trim();
      final url = await widget.repo.generateAudio(
        widget.page.id,
        text: text.isEmpty ? null : text,
      );
      if (!mounted) return;
      setState(() => _audioUrl = url);
      widget.snack('Audio generated');
    } catch (e) {
      widget.snack('Audio failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingAudio = false);
    }
  }

  Future<void> _playAudio() async {
    final url = _audioUrl;
    if (url == null) return;
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      widget.snack('Playback failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Page ${widget.index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: widget.index == 0 ? null : widget.onMoveUp,
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: widget.index == widget.total - 1
                      ? null
                      : widget.onMoveDown,
                ),
                IconButton(
                  tooltip: 'Delete page',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            TextField(
              controller: _textController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Page text...',
              ),
              onEditingComplete: _saveText,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _savingText ? null : _saveText,
                  icon: _savingText
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save text'),
                ),
                OutlinedButton.icon(
                  onPressed: _generatingImage ? null : _generateIllustration,
                  icon: _generatingImage
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: const Text('Generate illustration'),
                ),
                OutlinedButton.icon(
                  onPressed: _generatingAudio ? null : _generateAudio,
                  icon: _generatingAudio
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.record_voice_over),
                  label: const Text('Generate audio'),
                ),
              ],
            ),
            if (_illustrationUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _illustrationUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Text('Could not load illustration.'),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ],
            if (_audioUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Play audio',
                    onPressed: _playAudio,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _audioUrl!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
