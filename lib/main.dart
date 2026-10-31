import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/audio/sound_fx.dart';
import 'src/audio/sound_mute_store.dart';
import 'src/platform/game_platform.dart';
import 'src/storage.dart';
import 'src/ui/board.dart';
import 'src/ui/game_screen.dart';
import 'src/ui/how_to_play.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Right-click marks cells with X, so keep the browser menu out of the way.
    await BrowserContextMenu.disableContextMenu();
  }
  final platform = createGamePlatform();
  await platform.initialize();
  final storage = await GameStorage.open();
  runApp(NonoGridApp(storage: storage, platform: platform));
}

class NonoGridApp extends StatelessWidget {
  const NonoGridApp({
    super.key,
    required this.storage,
    this.tutorialStore,
    this.platform = const NoopGamePlatform(),
    this.soundMuteStore = const SoundMuteStore(),
    this.onSfxPlayed,
  });

  final GameStorage storage;
  final TutorialStore? tutorialStore;
  final GamePlatform platform;
  final SoundMuteStore soundMuteStore;
  final void Function(Sfx sfx)? onSfxPlayed;

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
      home: GameScreen(
        storage: storage,
        tutorialStore: tutorialStore,
        platform: platform,
        soundMuteStore: soundMuteStore,
        onSfxPlayed: onSfxPlayed,
      ),
    );
  }
}
