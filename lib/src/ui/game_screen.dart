import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../logic/game.dart';
import '../logic/puzzle.dart';
import '../platform/game_platform.dart';
import '../storage.dart';
import 'board.dart';
import 'how_to_play.dart';

/// Keys the browser owns (focus change, reload, Ctrl/Meta/Alt shortcuts) stay
/// unhandled so the how-to-play card does not block them on web.
bool _isBrowserShortcut(KeyEvent e) {
  final k = e.logicalKey;
  if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.f5) return true;
  final kb = HardwareKeyboard.instance;
  return kb.isControlPressed || kb.isMetaPressed || kb.isAltPressed;
}

String formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.storage,
    this.tutorialStore,
    this.platform = const NoopGamePlatform(),
    this.soundMuteStore = const SoundMuteStore(),
    this.onSfxPlayed,
  });

  final GameStorage storage;

  /// Receives gameplay start/stop events (CrazyGames SDK on portal builds).
  final GamePlatform platform;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Called for every sound that is actually played (not muted); for tests.
  final void Function(Sfx sfx)? onSfxPlayed;

  /// Defaults to [PrefsTutorialStore].
  final TutorialStore? tutorialStore;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _level;
  late NonoGame _game;
  Tool _tool = Tool.fill;
  (int, int) _cursor = (0, 0);
  bool _showCursor = false;
  Set<int> _mistakes = {};
  Timer? _mistakeTimer;
  String? _message;
  Timer? _messageTimer;

  // Timer: seconds carried over from a saved session plus the running clock.
  int _baseSeconds = 0;
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;

  bool _newBest = false;
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final FocusNode _focus = FocusNode(debugLabel: 'board');

  // Input and the clock stay blocked until the tutorial flag has been read.
  bool _tutorialChecked = false;
  bool _tutorialOpen = false;
  int _tutorialStep = 0;
  bool _resumeAfterTutorial = false;
  late final TutorialStore _tutorialStore =
      widget.tutorialStore ?? PrefsTutorialStore();

  // User sound toggle; effective mute also includes the platform mute.
  bool _soundMuted = false;
  bool _soundTouched = false;
  late final SoundFx _sfx = SoundFx(
    isMuted: () => _soundMuted || widget.platform.isAudioMuted,
    onPlay: widget.onSfxPlayed,
  );

  // Board snapshot and tool of the stroke in progress, for its one sound.
  List<Mark>? _strokeBefore;
  Tool _strokeTool = Tool.fill;

  bool get _inputBlocked => !_tutorialChecked || _tutorialOpen;

  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;

  /// Reports gameplay start/stop to the platform exactly on transitions.
  void _syncGameplay() {
    final wantActive = _tutorialChecked && !_tutorialOpen && !_game.isWon;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  GameStorage get _storage => widget.storage;
  int get _elapsed => _baseSeconds + _clock.elapsed.inSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final level = _storage.level.clamp(1, _storage.unlocked);
    _load(level);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_clock.isRunning && mounted) setState(() {});
    });
    _checkTutorial();
    _loadSoundMuted();
  }

  Future<void> _loadSoundMuted() async {
    var muted = false;
    try {
      muted = await widget.soundMuteStore.loadMuted();
    } catch (_) {}
    if (!mounted || _soundTouched) return;
    setState(() => _soundMuted = muted);
  }

  void _toggleSound() {
    _soundTouched = true;
    final muted = !_soundMuted;
    setState(() => _soundMuted = muted);
    () async {
      try {
        await widget.soundMuteStore.saveMuted(muted);
      } catch (_) {}
    }();
    _focus.requestFocus();
  }

  /// Plays the one sound of a finished fill/mark action: level_clear on a
  /// win, otherwise fill or mark when the board changed.
  void _playChange(List<Mark>? before, Tool tool) {
    if (_game.isWon) {
      _sfx.play(Sfx.levelClear);
    } else if (before != null && !listEquals(before, _game.cells)) {
      _sfx.play(tool == Tool.fill ? Sfx.fill : Sfx.mark);
    }
  }

  Future<void> _checkTutorial() async {
    var seen = false;
    try {
      seen = await _tutorialStore.isSeen();
    } catch (_) {
      seen = false;
    }
    if (!mounted) return;
    setState(() {
      _tutorialChecked = true;
      if (!seen) _openTutorial();
    });
    _syncGameplay();
  }

  /// Opens the tutorial at step 1 and pauses the clock. Call inside setState.
  void _openTutorial() {
    _tutorialOpen = true;
    _tutorialStep = 0;
    if (_clock.isRunning) {
      _clock.stop();
      _resumeAfterTutorial = true;
      _saveProgress();
    }
    _syncGameplay();
  }

  void _closeTutorial() {
    setState(() {
      _tutorialOpen = false;
      if (_resumeAfterTutorial) _startClock();
      _resumeAfterTutorial = false;
    });
    _syncGameplay();
    _focus.requestFocus();
    () async {
      try {
        await _tutorialStore.markSeen();
      } catch (_) {}
    }();
  }

  void _tutorialNext() {
    if (_tutorialStep >= nonoGridSteps.length - 1) {
      _closeTutorial();
    } else {
      setState(() => _tutorialStep++);
    }
  }

  void _tutorialPrev() {
    if (_tutorialStep > 0) setState(() => _tutorialStep--);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _mistakeTimer?.cancel();
    _messageTimer?.cancel();
    _reveal.dispose();
    _focus.dispose();
    _sfx.dispose();
    super.dispose();
  }

  /// Pauses the clock while the app or browser tab is not visible and saves
  /// the elapsed time so a reload does not lose it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wasRunning && !_tutorialOpen) _startClock();
      _wasRunning = false;
    } else if (_clock.isRunning) {
      _wasRunning = true;
      _clock.stop();
      _saveProgress();
    }
  }

  bool _wasRunning = false;

  void _saveProgress() {
    if (_game.isWon) return;
    unawaited(
      _storage.saveProgress(SavedProgress(_level, _game.encode(), _elapsed)),
    );
  }

  void _load(int level) {
    _level = level;
    _game = NonoGame(puzzleForLevel(level));
    _clock
      ..stop()
      ..reset();
    _baseSeconds = 0;
    _reveal.value = 0;
    _newBest = false;
    _mistakes = {};
    _cursor = (0, 0);
    final saved = _storage.progress;
    if (saved != null && saved.level == level) {
      if (_game.restore(saved.cells) && !_game.isWon) {
        _baseSeconds = saved.elapsedSeconds;
      } else {
        _game.restart();
      }
    }
    unawaited(_storage.setLevel(level));
  }

  void _goTo(int level) {
    if (level < 1 || level > _storage.unlocked) return;
    // Saved progress is kept: it belongs to one level and is restored when
    // that level is opened again, until a move on another level replaces it.
    setState(() => _load(level));
    _syncGameplay();
  }

  // ---- Input ------------------------------------------------------------

  void _startClock() {
    if (!_clock.isRunning && !_game.isWon && !_inputBlocked) _clock.start();
  }

  void _onStrokeStart(int r, int c, Tool tool) {
    if (_game.isWon || _inputBlocked) return;
    _focus.requestFocus();
    _startClock();
    _strokeBefore = List<Mark>.of(_game.cells);
    _strokeTool = tool;
    setState(() {
      _showCursor = false;
      _cursor = (r, c);
      _game.beginStroke(r, c, tool);
    });
  }

  void _onStrokeMove(int r, int c) {
    if (!_game.isStroking) return;
    setState(() => _game.updateStroke(r, c));
  }

  void _onStrokeEnd() {
    if (!_game.isStroking) return;
    setState(_game.endStroke);
    _afterChange();
    _playChange(_strokeBefore, _strokeTool);
    _strokeBefore = null;
  }

  void _tapAtCursor(Tool tool) {
    if (_game.isWon) return;
    _startClock();
    final before = List<Mark>.of(_game.cells);
    setState(() => _game.tap(_cursor.$1, _cursor.$2, tool));
    _afterChange();
    _playChange(before, tool);
  }

  void _undo() {
    if (!_game.canUndo) return;
    setState(_game.undo);
    _afterChange();
    _sfx.play(Sfx.undo);
  }

  void _restart() {
    setState(() {
      _game.restart();
      _clock
        ..stop()
        ..reset();
      _baseSeconds = 0;
      _reveal.value = 0;
      _mistakes = {};
      _newBest = false;
    });
    if (_storage.progress?.level == _level) {
      unawaited(_storage.clearProgress());
    }
    _syncGameplay();
  }

  void _check() {
    if (_game.isWon) return;
    final wrong = _game.mistakes();
    _mistakeTimer?.cancel();
    setState(() => _mistakes = wrong.toSet());
    _mistakeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _mistakes = {});
    });
    _flash(
      wrong.isEmpty
          ? 'No mistakes so far'
          : '${wrong.length} wrong ${wrong.length == 1 ? 'cell' : 'cells'}',
    );
  }

  void _flash(String text) {
    _messageTimer?.cancel();
    setState(() => _message = text);
    _messageTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _afterChange() {
    _syncGameplay();
    if (_game.isWon) {
      _clock.stop();
      final seconds = _elapsed;
      unawaited(_storage.clearProgress());
      _storage.recordClear(_level, seconds).then((best) {
        if (mounted) setState(() => _newBest = best);
      });
      _reveal.forward(from: 0);
    } else {
      _saveProgress();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_tutorialOpen) {
      if (_isBrowserShortcut(event)) return KeyEventResult.ignored;
      if (event is KeyDownEvent) {
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) {
          _tutorialNext();
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (_tutorialStep < nonoGridSteps.length - 1) _tutorialNext();
        } else if (k == LogicalKeyboardKey.arrowLeft) {
          _tutorialPrev();
        } else if (k == LogicalKeyboardKey.escape) {
          _closeTutorial();
        }
      }
      return KeyEventResult.handled;
    }
    if (_inputBlocked) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Auto-repeat only moves the cursor; actions need a fresh key press so a
    // held Enter/Space from the tutorial cannot paint after it closes.
    if (event is KeyRepeatEvent &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final n = _game.size;
    void move(int dr, int dc) => setState(() {
      _showCursor = true;
      _cursor = (
        (_cursor.$1 + dr).clamp(0, n - 1),
        (_cursor.$2 + dc).clamp(0, n - 1),
      );
    });
    if (key == LogicalKeyboardKey.arrowUp) {
      move(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      move(1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      move(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      move(0, 1);
    } else if (key == LogicalKeyboardKey.space) {
      setState(() => _showCursor = true);
      _tapAtCursor(Tool.fill);
    } else if (key == LogicalKeyboardKey.keyX) {
      setState(() => _showCursor = true);
      _tapAtCursor(Tool.cross);
    } else if (key == LogicalKeyboardKey.keyU) {
      _undo();
    } else if (key == LogicalKeyboardKey.keyR) {
      _restart();
    } else if (key == LogicalKeyboardKey.enter && _game.isWon) {
      _goTo(_level + 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---- Build ------------------------------------------------------------

  Color get _revealColor => HSVColor.fromAHSV(
    1,
    (_level * 47 % 360).toDouble(),
    0.55,
    0.78,
  ).toColor();

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ExcludeFocus(
        child: Scaffold(
          backgroundColor: NonoColors.background,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: NonoBoard(
                          game: _game,
                          tool: _tool,
                          cursor: _cursor,
                          showCursor: _showCursor,
                          reveal: _reveal,
                          revealColor: _revealColor,
                          mistakes: _mistakes,
                          onStrokeStart: _onStrokeStart,
                          onStrokeMove: _onStrokeMove,
                          onStrokeEnd: _onStrokeEnd,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Text(
                        _message ?? _hint(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _message != null
                              ? NonoColors.accent
                              : NonoColors.paper.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _game.isWon ? _winBar() : _toolBar(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              if (_tutorialOpen)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    steps: nonoGridSteps,
                    step: _tutorialStep,
                    onNext: _tutorialNext,
                    onSkip: _closeTutorial,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _hint(BuildContext context) {
    if (_game.isWon) return 'Press Next or Enter for the next puzzle';
    return MediaQuery.sizeOf(context).width >= 700
        ? 'Drag to paint  -  Right-click: X  -  Arrows, Space, X, U undo, R restart'
        : 'Tap or drag to paint  -  Switch to X to mark empty cells';
  }

  Widget _topBar() {
    final best = _storage.bestSeconds(_level);
    const titleStyle = TextStyle(
      color: NonoColors.paper,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
    final sub = TextStyle(
      color: NonoColors.paper.withValues(alpha: 0.7),
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'NonoGrid',
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Previous level',
              color: NonoColors.paper,
              disabledColor: NonoColors.paper.withValues(alpha: 0.25),
              onPressed: _level > 1 ? () => _goTo(_level - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Level $_level',
                  style: const TextStyle(
                    color: NonoColors.paper,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('${_game.size}x${_game.size}', style: sub),
              ],
            ),
            IconButton(
              tooltip: 'Next level',
              color: NonoColors.paper,
              disabledColor: NonoColors.paper.withValues(alpha: 0.25),
              onPressed: _level < _storage.unlocked
                  ? () => _goTo(_level + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatTime(_elapsed),
                      style: const TextStyle(
                        color: NonoColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      best == null ? 'Best --' : 'Best ${formatTime(best)}',
                      style: sub,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('sound-toggle'),
              tooltip: _soundMuted ? 'Sound off' : 'Sound on',
              color: NonoColors.paper,
              visualDensity: VisualDensity.compact,
              onPressed: _toggleSound,
              icon: Icon(
                _soundMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
            IconButton(
              key: const Key('how-to-play-button'),
              tooltip: 'How to play',
              color: NonoColors.paper,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(_openTutorial),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBar() {
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: NonoColors.paper,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
    return Wrap(
      key: const ValueKey('tools'),
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        SegmentedButton<Tool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            foregroundColor: NonoColors.paper,
            selectedForegroundColor: NonoColors.ink,
            selectedBackgroundColor: NonoColors.accent,
            side: BorderSide(color: NonoColors.paper.withValues(alpha: 0.4)),
          ),
          segments: const [
            ButtonSegment(
              value: Tool.fill,
              icon: Icon(Icons.square_rounded),
              label: Text('Fill'),
            ),
            ButtonSegment(
              value: Tool.cross,
              icon: Icon(Icons.close),
              label: Text('Mark X'),
            ),
          ],
          selected: {_tool},
          onSelectionChanged: (s) => setState(() => _tool = s.first),
        ),
        TextButton.icon(
          style: buttonStyle,
          onPressed: _game.canUndo ? _undo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        TextButton.icon(
          style: buttonStyle,
          onPressed: _check,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Check'),
        ),
        TextButton.icon(
          style: buttonStyle,
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          label: const Text('Restart'),
        ),
      ],
    );
  }

  Widget _winBar() {
    final name = _game.puzzle.name;
    final best = _storage.bestSeconds(_level);
    return Row(
      key: const ValueKey('win'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '${name != null ? '$name! ' : ''}Solved in ${formatTime(_elapsed)}'
            '${_newBest ? '  New best!' : (best != null ? '  Best ${formatTime(best)}' : '')}',
            style: const TextStyle(
              color: NonoColors.paper,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: NonoColors.accent,
            foregroundColor: NonoColors.ink,
          ),
          onPressed: () => _goTo(_level + 1),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
