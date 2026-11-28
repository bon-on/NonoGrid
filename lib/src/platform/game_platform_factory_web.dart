import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// Picks the portal adapter from explicit flags; GAMEPIX wins over
/// CRAZYGAMES (feature-gamepix-sdk). Used by tests only: the build itself goes
/// through [createGamePlatform], whose constant flags let the compiler drop
/// the unused adapters (the GamePix bundle has no CrazyGames code and the
/// CrazyGames bundle no GamePix code). GamePix gets no share link (no
/// outbound URLs in that bundle).
GamePlatform selectGamePlatform({
  required bool crazyGames,
  required bool gamePix,
}) {
  if (gamePix) return GamePixPlatform();
  if (crazyGames) return CrazyGamesPlatform();
  return const NoopGamePlatform(shareLink: pagesShareLink);
}

GamePlatform createGamePlatform() => _gamePixBuild
    ? GamePixPlatform()
    : _crazyGamesBuild
    ? CrazyGamesPlatform()
    : const NoopGamePlatform(shareLink: pagesShareLink);
