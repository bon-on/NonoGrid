import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation.
/// GamePix web builds (`--dart-define=GAMEPIX=true`) use the no-op platform.
abstract class GamePlatform {
  const GamePlatform();

  /// Whether the game may show ads. This game has none; kept false so a
  /// portal build can never enable them by accident.
  bool get allowsAds => false;

  /// Whether finished results may be sent to an external service. This game
  /// has no leaderboard or result upload; kept false for the same reason.
  bool get allowsResultRegistration => false;

  /// Whether the portal asks the game to stay silent (CrazyGames SDK
  /// `settings.muteAudio`). Combined with the player's own mute toggle.
  bool get isAudioMuted => false;

  /// Registers a callback for [isAudioMuted] changes (null clears it), so
  /// music can stop or resume as soon as the portal setting flips.
  void setAudioMuteListener(void Function()? listener) {}

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
