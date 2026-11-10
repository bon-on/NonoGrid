import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../meta/first_run_coach.dart';
import 'paper_ui.dart';

/// Non-blocking first-run tip strip shown next to the board
/// (feature-portal-quality-pass). It only decorates: taps outside the close
/// button fall through to nothing, and the board stays playable.
class CoachStrip extends StatelessWidget {
  const CoachStrip({
    super.key,
    required this.palette,
    required this.step,
    required this.text,
    required this.onDismiss,
    this.maxLines = 3,
  });

  final PaperPalette palette;
  final CoachStep step;
  final String text;
  final VoidCallback onDismiss;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return PaperPanel(
      key: const Key('coach-strip'),
      palette: p,
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
      child: Row(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${step.index + 1}/${FirstRunCoach.tipCount}',
              style: TextStyle(
                color: p.accentInk,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                text,
                key: ValueKey(step),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.panelText,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // 48x48 touch target.
          IconButton(
            key: const Key('coach-dismiss'),
            tooltip: 'Hide tips',
            color: p.panelSubtle,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
