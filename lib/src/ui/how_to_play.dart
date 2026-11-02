import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../art/paper_palette.dart';
import 'paper_ui.dart';

/// Remembers whether the first-run tutorial has been seen.
abstract class TutorialStore {
  Future<bool> isSeen();
  Future<void> markSeen();
}

class PrefsTutorialStore implements TutorialStore {
  static const _key = 'tutorial_seen_v1';

  @override
  Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

class MemoryTutorialStore implements TutorialStore {
  MemoryTutorialStore({this.seen = false});
  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

class HowToPlayStep {
  const HowToPlayStep(this.icon, this.text);
  final IconData icon;
  final String text;
}

const nonoGridSteps = [
  HowToPlayStep(
    Icons.grid_on,
    'Fill the grid so every row and column matches its number clues.',
  ),
  HowToPlayStep(
    Icons.touch_app_outlined,
    'Tap or drag to fill. Use Mark X (or right-click) to mark empty cells.',
  ),
  HowToPlayStep(
    Icons.keyboard_outlined,
    'Keys: arrows, Space fill, X mark, U undo, R restart. Check flags '
    'mistakes (finding one costs a star). Beat the par time for 3 stars.',
  ),
];

/// Scrim + paper card. Stateless: the owner keeps [step] and handles keys.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.step,
    required this.onNext,
    required this.onSkip,
    this.palette = PaperPalette.notebook,
  });

  final List<HowToPlayStep> steps;
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final PaperPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final last = step == steps.length - 1;
    final s = steps[step];
    return Stack(
      children: [
        // Absorbs taps so the game underneath is unreachable.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const ColoredBox(color: Color(0x99000000)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: PaperPanel(
                key: const Key('how-to-play'),
                palette: p,
                tape: true,
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'How to play',
                        style: TextStyle(
                          color: p.panelText,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.panelBorder, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: p.panelBorder,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(s.icon, size: 36, color: p.accentInk),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.text,
                        key: const Key('how-to-play-text'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.panelText,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: i == step ? 20 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: i == step
                                    ? p.accent
                                    : p.panelBorder.withValues(alpha: 0.25),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PaperButton(
                            key: const Key('how-to-play-skip'),
                            palette: p,
                            label: 'Skip',
                            compact: true,
                            onPressed: onSkip,
                          ),
                          PaperButton(
                            key: const Key('how-to-play-next'),
                            palette: p,
                            label: last ? 'Play' : 'Next',
                            primary: true,
                            onPressed: onNext,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
