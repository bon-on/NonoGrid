import 'game_platform.dart';

GamePlatform createGamePlatform() =>
    const NoopGamePlatform(shareLink: pagesShareLink);
