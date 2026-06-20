import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'book/book_reader_page.dart';
import 'midjourney/midjourney_auth.dart';
import 'midjourney/midjourney_client.dart';
import 'midjourney/midjourney_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads bundled dream_book/.env (MJ_ACCESS_TOKEN / MJ_REFRESH_TOKEN /
  // MJ_CLIENT_ID). isOptional => app still runs (interactive OAuth) if absent.
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dream_book',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const MidjourneyDemoPage(),
    );
  }
}

/// Minimal smoke-test screen for the Midjourney client.
/// Type a prompt, tap Generate, see the 4 results. First tap triggers OAuth.
class MidjourneyDemoPage extends StatefulWidget {
  const MidjourneyDemoPage({super.key});

  @override
  State<MidjourneyDemoPage> createState() => _MidjourneyDemoPageState();
}

class _MidjourneyDemoPageState extends State<MidjourneyDemoPage> {
  late final MidjourneyClient _client =
      MidjourneyClient(auth: MidjourneyAuth.fromDotenv());
  final _controller = TextEditingController(text: 'a big dragon --ar 16:9');

  bool _loading = false;
  String? _error;
  MidjourneyJob? _job;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final job = await _client.generateImage(_controller.text.trim());
      setState(() => _job = job);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dream_book · Midjourney')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Generating…' : 'Generate'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_job != null && _job!.images.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookReaderPage(
                        job: _job!,
                        title: _controller.text.trim().isEmpty
                            ? 'My Dream Book'
                            : _controller.text.trim(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_stories),
                label: const Text('Read as book'),
              ),
              const SizedBox(height: 12),
            ],
            if (_job != null)
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final img in _job!.images)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(img.cdnUrl, fit: BoxFit.cover),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
