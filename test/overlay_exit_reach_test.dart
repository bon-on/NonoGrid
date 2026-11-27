import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/art/paper_palette.dart';
import 'package:nono_grid/src/meta/progress_rules.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:nono_grid/src/ui/overlays.dart';

/// Short phone windows (browser bars, landscape) where a card can be taller
/// than the screen. The way out of every card must stay on screen without
/// scrolling.
const _sizes = [Size(360, 560), Size(320, 480), Size(640, 300)];

Future<void> _pump(WidgetTester tester, Size size, Widget overlay) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: overlay)),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder at $size');
  expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
  expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
}

void main() {
  for (final size in _sizes) {
    for (var step = 0; step < nonoGridSteps.length; step++) {
      testWidgets('How to play step $step keeps Skip and Next at $size', (
        tester,
      ) async {
        var skipped = 0;
        var next = 0;
        await _pump(
          tester,
          size,
          HowToPlayOverlay(
            steps: nonoGridSteps,
            step: step,
            onNext: () => next++,
            onSkip: () => skipped++,
          ),
        );
        expect(tester.takeException(), isNull);
        final skip = find.byKey(const Key('how-to-play-skip'));
        _expectOnScreen(tester, skip, size);
        _expectOnScreen(
          tester,
          find.byKey(const Key('how-to-play-next')),
          size,
        );
        await tester.tap(skip);
        expect(skipped, 1);
        await tester.tap(find.byKey(const Key('how-to-play-next')));
        expect(next, 1);
      });
    }

    testWidgets('the themes close button stays pinned at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        size,
        ThemeOverlay(
          palette: PaperPalette.notebook,
          current: NonoTheme.notebook,
          selected: NonoTheme.notebook,
          painterLevel: 1,
          onPick: (_) {},
          onClose: () => closed++,
        ),
      );
      expect(tester.takeException(), isNull);
      final close = find.byIcon(Icons.close_rounded);
      _expectOnScreen(tester, close, size);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      _expectOnScreen(tester, close, size);
      await tester.tap(close);
      expect(closed, 1);
    });
  }
}
