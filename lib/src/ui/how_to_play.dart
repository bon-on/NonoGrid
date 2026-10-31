import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'Keys: arrows, Space fill, X mark, U undo, R restart. Check flags mistakes.',
  ),
];

/// Scrim + card. Stateless: the owner keeps [step] and handles keys.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  final List<HowToPlayStep> steps;
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final last = step == steps.length - 1;
    final s = steps[step];
    return Stack(
      children: [
        // Absorbs taps so the game underneath is unreachable.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const ColoredBox(color: Color(0xB3000000)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Card(
                key: const Key('how-to-play'),
                elevation: 8,
                color: const Color(0xFF1E293B),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'How to play',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        s.icon,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.text,
                        key: const Key('how-to-play-text'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == step
                                    ? Colors.white
                                    : Colors.white24,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            key: const Key('how-to-play-skip'),
                            onPressed: onSkip,
                            child: const Text('Skip'),
                          ),
                          FilledButton(
                            key: const Key('how-to-play-next'),
                            onPressed: onNext,
                            child: Text(last ? 'Play' : 'Next'),
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
