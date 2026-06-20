import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Self-contained showcase of the "3D Book with Page Flip" Rive animation.
///
/// The `.riv` file is the free CC-BY community file from the Rive marketplace:
/// https://rive.app/marketplace/24847-46420-3d-book-with-page-flip-animation/
/// It ships in `assets/rive/book.riv`.
///
/// How this file is driven (verified from the file's binary):
/// The artboard is "Book" and the state machine is "State Machine 1". Its
/// inputs are:
///   * `isFirstPage` (boolean)  – true while showing the front cover
///   * `isLastPage`  (boolean)  – true while showing the back cover
///   * `Back`        (trigger)  – flip one page backward
///   * `Next`        (trigger)  – flip one page forward
///
/// The flip is NOT wired to Rive pointer listeners, so we drive it by firing
/// the `Next` / `Back` triggers. Two gotchas this screen handles:
///
///  1. `RiveWidget` installs its own raw pointer listener that forwards pointer
///     events into the state machine. If we *also* wrap it in a tap handler,
///     every click is processed twice and can knock the book into a bad state.
///     We set [RiveHitTestBehavior.none] so Rive ignores pointers and our
///     [GestureDetector] is the sole handler.
///  2. Firing `Next` past the last page (or `Back` past the first) can flip the
///     book into an empty/closed state that looks "dismissed". We gate every
///     fire on the `isFirstPage` / `isLastPage` booleans.
class RiveBookDemoScreen extends StatefulWidget {
  const RiveBookDemoScreen({super.key});

  @override
  State<RiveBookDemoScreen> createState() => _RiveBookDemoScreenState();
}

class _RiveBookDemoScreenState extends State<RiveBookDemoScreen> {
  static const String _asset = 'assets/rive/book.riv';
  static const String _stateMachine = 'State Machine 1';

  File? _file;
  RiveWidgetController? _controller;
  ViewModelInstance? _viewModelInstance;

  TriggerInput? _next;
  TriggerInput? _back;
  BooleanInput? _isFirstPage;
  BooleanInput? _isLastPage;

  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Use the Rive renderer for the highest fidelity to the editor.
      final file = await File.asset(_asset, riveFactory: Factory.rive);
      if (file == null) {
        throw StateError('Could not decode $_asset');
      }
      final controller = RiveWidgetController(
        file,
        stateMachineSelector: StateMachineSelector.byName(_stateMachine),
      );
      // Bind the default view-model instance so the file's data-bound
      // illustrations render.
      final vmi = controller.dataBind(DataBind.auto());

      // Look up the page-flip controls by name (verified from the .riv).
      // ignore: deprecated_member_use
      _next = controller.stateMachine.trigger('Next');
      // ignore: deprecated_member_use
      _back = controller.stateMachine.trigger('Back');
      // ignore: deprecated_member_use
      _isFirstPage = controller.stateMachine.boolean('isFirstPage');
      // ignore: deprecated_member_use
      _isLastPage = controller.stateMachine.boolean('isLastPage');

      if (!mounted) {
        file.dispose();
        controller.dispose();
        vmi.dispose();
        return;
      }
      setState(() {
        _file = file;
        _controller = controller;
        _viewModelInstance = vmi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Flip forward, unless we're already on the last page.
  void _flipNext() {
    if (_isLastPage?.value == true) return;
    _next?.fire();
  }

  /// Flip backward, unless we're already on the first page.
  void _flipBack() {
    if (_isFirstPage?.value == true) return;
    _back?.fire();
  }

  @override
  void dispose() {
    _next?.dispose();
    _back?.dispose();
    _isFirstPage?.dispose();
    _isLastPage?.dispose();
    _viewModelInstance?.dispose();
    _controller?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14111F),
      appBar: AppBar(
        title: const Text('Rive · 3D Page Flip'),
        backgroundColor: const Color(0xFF14111F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildStage()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load the Rive animation.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Rive ignores pointers (hitTestBehavior: none) so this GestureDetector is
    // the only thing handling taps — no double-processing with Rive's own
    // internal pointer listener.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _flipNext,
      child: RiveWidget(
        controller: controller,
        fit: Fit.contain,
        hitTestBehavior: RiveHitTestBehavior.none,
      ),
    );
  }

  Widget _buildControls() {
    if (_controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _flipBack,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _flipNext,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the book or use the buttons to flip pages.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
