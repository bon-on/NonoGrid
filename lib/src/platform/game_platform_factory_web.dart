import 'crazygames_platform.dart';
import 'game_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');

GamePlatform createGamePlatform() =>
    _crazyGamesBuild ? CrazyGamesPlatform() : const NoopGamePlatform();
