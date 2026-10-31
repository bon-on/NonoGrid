import 'crazygames_platform.dart';
import 'game_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// GAMEPIX (`--dart-define=GAMEPIX=true`) wins over CRAZYGAMES and uses the
/// no-op platform, so the GamePix bundle contains no SDK adapter at all.
/// Both flags are compile-time constants so the unused branch is tree-shaken.
GamePlatform createGamePlatform() => _gamePixBuild
    ? const NoopGamePlatform()
    : _crazyGamesBuild
    ? CrazyGamesPlatform()
    : const NoopGamePlatform();
