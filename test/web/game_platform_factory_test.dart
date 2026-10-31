// Run with: flutter test --platform chrome test/web
// GamePix selection: flutter test --platform chrome test/web \
//   --dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/platform/crazygames_platform.dart';
import 'package:nono_grid/src/platform/game_platform.dart';

void main() {
  const gamePix = bool.fromEnvironment('GAMEPIX');
  const crazyGames = bool.fromEnvironment('CRAZYGAMES');

  test('platform selection follows the build flags', () {
    final platform = createGamePlatform();
    if (gamePix) {
      // GAMEPIX wins even when CRAZYGAMES is also set.
      expect(platform, isA<NoopGamePlatform>());
      expect(platform, isNot(isA<CrazyGamesPlatform>()));
    } else if (crazyGames) {
      expect(platform, isA<CrazyGamesPlatform>());
    } else {
      expect(platform, isA<NoopGamePlatform>());
    }
  });

  test('portal platforms register no results and show no ads', () {
    final platform = createGamePlatform();
    expect(platform.allowsResultRegistration, isFalse);
    expect(platform.allowsAds, isFalse);
  });
}
