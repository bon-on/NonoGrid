import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/storage.dart';
import 'src/ui/board.dart';
import 'src/ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Right-click marks cells with X, so keep the browser menu out of the way.
    await BrowserContextMenu.disableContextMenu();
  }
  final storage = await GameStorage.open();
  runApp(NonoGridApp(storage: storage));
}

class NonoGridApp extends StatelessWidget {
  const NonoGridApp({super.key, required this.storage});

  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NonoGrid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: NonoColors.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: NonoColors.background,
      ),
      home: GameScreen(storage: storage),
    );
  }
}
