import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation.
abstract class GamePlatform {
  const GamePlatform();

  /// Prepares the portal SDK. Never throws; failures downgrade to no-op.
  Future<void> initialize();

  /// The player is actively playing (no overlay, level not cleared).
  void gameplayStart();

  /// The player stopped playing (overlay open, level cleared).
  void gameplayStop();
}

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform();

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
