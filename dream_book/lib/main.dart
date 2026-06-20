import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'home_page.dart';

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
      home: const HomePage(),
    );
  }
}
