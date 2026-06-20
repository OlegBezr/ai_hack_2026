import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Self-contained showcase of the "3D Book with Page Flip" Rive animation.
///
/// The `.riv` file is the free CC-BY community file from the Rive marketplace:
/// https://rive.app/marketplace/24847-46420-3d-book-with-page-flip-animation/
/// It ships in `assets/rive/book.riv`.
///
/// IMPORTANT — how this file is driven:
/// The artboard is "Book" and the state machine is "State Machine 1". The flip
/// is NOT wired to Rive pointer listeners, so dragging/tapping the artboard does
/// nothing on its own. Instead the state machine exposes *trigger inputs*
/// (e.g. `Next`, `Trigger 1`) that we fire programmatically to turn pages. This
/// screen discovers those triggers at runtime and exposes a button per trigger,
/// plus tap-to-advance on the book itself.
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

  /// Trigger inputs discovered on the state machine, in declaration order.
  final List<TriggerInput> _triggers = <TriggerInput>[];

  /// The trigger used for tap-to-advance: the one named "Next" if present,
  /// otherwise the first trigger on the state machine.
  TriggerInput? _advanceTrigger;

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

      // Discover the trigger inputs that actually drive the page flip.
      // ignore: deprecated_member_use
      for (final input in controller.stateMachine.inputs) {
        if (input is TriggerInput) _triggers.add(input);
      }
      // Tap-to-advance prefers a trigger named "Next", else the first one.
      for (final t in _triggers) {
        if (t.name.toLowerCase() == 'next') {
          _advanceTrigger = t;
          break;
        }
      }
      _advanceTrigger ??= _triggers.isNotEmpty ? _triggers.first : null;

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

  @override
  void dispose() {
    for (final t in _triggers) {
      t.dispose();
    }
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

    // Tapping the book fires the forward trigger — the file has no pointer
    // listeners of its own, so we forward taps to the state machine.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _advanceTrigger?.fire(),
      child: RiveWidget(
        controller: controller,
        fit: Fit.contain,
      ),
    );
  }

  Widget _buildControls() {
    if (_controller == null || _triggers.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final trigger in _triggers)
                ElevatedButton.icon(
                  onPressed: () => trigger.fire(),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: Text(trigger.name),
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
