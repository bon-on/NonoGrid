// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/platform/crazygames_platform.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/platform/game_platform_factory_web.dart'
    as web_factory;
import 'package:nono_grid/src/platform/gamepix_platform.dart';

void main() {
  test('default web build keeps the no-op platform with the Pages link', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: false,
    );
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.shareLink, pagesShareLink);
    expect(platform.showsRunBreakAds, isFalse);
  });

  test('GamePix build uses the SDK adapter without a link or results', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: true,
    );
    expect(platform, isA<GamePixPlatform>());
    expect(platform.allowsResultRegistration, isFalse);
    expect(platform.allowsAds, isFalse);
    expect(platform.shareLink, isNull, reason: 'GamePix: no outbound link');
  });

  test('GAMEPIX wins over CRAZYGAMES', () {
    expect(
      web_factory.selectGamePlatform(crazyGames: true, gamePix: true),
      isA<GamePixPlatform>(),
    );
    expect(
      web_factory.selectGamePlatform(crazyGames: true, gamePix: false),
      isA<CrazyGamesPlatform>(),
    );
  });
}
