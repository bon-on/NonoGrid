import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../art/desk_scenery.dart';
import '../art/paper_palette.dart';
import '../art/shapes.dart';
import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../logic/clues.dart';
import '../logic/game.dart';
import '../logic/line_solver.dart';
import '../logic/logic_hint.dart';
import '../logic/puzzle.dart';
import '../meta/daily.dart';
import '../meta/first_run_coach.dart';
import '../meta/progress_rules.dart';
import '../platform/game_platform.dart';
import '../share/result_copy.dart';
import '../storage.dart';
import 'board.dart';
import 'board_fx.dart';
import 'coach_strip.dart';
import 'daily_ui.dart';
import 'how_to_play.dart';
import 'overlays.dart';
import 'paper_ui.dart';

export 'overlays.dart' show formatTime;

/// Keys the browser owns (focus change, reload, Ctrl/Meta/Alt shortcuts) stay
/// unhandled so overlays do not block them on web.
bool _isBrowserShortcut(KeyEvent e) {
  final k = e.logicalKey;
  if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.f5) return true;
  final kb = HardwareKeyboard.instance;
  return kb.isControlPressed || kb.isMetaPressed || kb.isAltPressed;
}

/// Tool panel height below which the key hint is left out.
const double _kHintMinPanelHeight = 440;

/// How the game screen is arranged for a window size
/// (feature-short-viewport-layout).
enum ScreenLayout {
  /// Portrait and square windows: header, board, tools stacked.
  stacked,

  /// Short landscape windows (portal previews, phones on their side) that
  /// are too narrow for [wide]: compact info column, board, tool column.
  compact,

  /// Wide landscape windows: info panel, board, tool panel.
  wide,
}

/// Height under which a landscape window that is not [ScreenLayout.wide]
/// switches to [ScreenLayout.compact]; the stacked header and tool rows
/// would leave the board too little height there.
const double kCompactMaxHeight = 560;

/// Compact windows narrower than this show the tool column as icons only.
const double kCompactIconToolsMaxWidth = 600;

/// Stacked windows shorter than this fold Daily, Levels, Album and Themes
/// into a single row so the board keeps its height.
const double kFoldedMetaMaxHeight = 700;

ScreenLayout screenLayoutFor(Size size) {
  if (size.width >= 700 && size.width > size.height * 1.3) {
    return ScreenLayout.wide;
  }
  if (size.width > size.height && size.height < kCompactMaxHeight) {
    return ScreenLayout.compact;
  }
  return ScreenLayout.stacked;
}

/// Info panel height below which Levels/Album/Themes become an icon row
/// under the Daily card instead of labelled buttons at the bottom.
const double _kMetaRowMaxPanelHeight = 600;

/// Overlays other than the tutorial.
enum _Panel { none, summary, album, levels, themes, logic, daily }

/// Strength of a haptic pulse.
enum HapticKind { light, medium, heavy }

/// Which rows/columns match their clue or hold more filled cells than it.
class _LineState {
  _LineState(Puzzle puzzle, List<Mark> cells) {
    final n = puzzle.size;
    final clues = puzzle.clues;
    for (var i = 0; i < n; i++) {
      final row = [for (var c = 0; c < n; c++) cells[i * n + c] == Mark.filled];
      final col = [for (var r = 0; r < n; r++) cells[r * n + i] == Mark.filled];
      if (sameRuns(runsOf(row), clues.rows[i])) rowsDone.add(i);
      if (sameRuns(runsOf(col), clues.cols[i])) colsDone.add(i);
      int sum(List<int> l) => l.fold(0, (a, b) => a + b);
      if (row.where((f) => f).length > sum(clues.rows[i])) rowsOver.add(i);
      if (col.where((f) => f).length > sum(clues.cols[i])) colsOver.add(i);
    }
  }

  final Set<int> rowsDone = {};
  final Set<int> colsDone = {};
  final Set<int> rowsOver = {};
  final Set<int> colsOver = {};
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.storage,
    this.tutorialStore,
    this.platform = const NoopGamePlatform(),
    this.soundMuteStore = const SoundMuteStore(),
    this.onSfxPlayed,
    this.onHaptic,
    this.clock = DateTime.now,
    this.copier = const ResultCopier(),
  });

  final GameStorage storage;

  /// Local time source for the daily puzzle; tests inject a fixed clock.
  final DateTime Function() clock;

  /// Clipboard access for the daily copy-result text; tests inject a fake.
  final ResultCopier copier;

  /// Receives gameplay start/stop events (CrazyGames SDK on portal builds).
  final GamePlatform platform;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Called for every sound that is actually played (not muted); for tests.
  final void Function(Sfx sfx)? onSfxPlayed;

  /// Receives each haptic pulse instead of the device; tests inject it.
  final void Function(HapticKind kind)? onHaptic;

  /// Defaults to [PrefsTutorialStore].
  final TutorialStore? tutorialStore;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _level;
  late NonoGame _game;

  /// Day of the daily puzzle on the board, null while playing levels.
  int? _dailyDay;
  String? _toast;
  Timer? _toastTimer;
  Tool _tool = Tool.fill;
  (int, int) _cursor = (0, 0);
  bool _showCursor = false;
  Set<int> _mistakes = {};
  Timer? _mistakeTimer;
  LogicHint? _logicHint;
  String? _message;
  Timer? _messageTimer;

  /// Check found a wrong cell on this board: the second star is lost.
  bool _mistakeMade = false;

  // Timer: seconds carried over from a saved session plus the running clock.
  int _baseSeconds = 0;
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addStatusListener(_onRevealStatus);
  final FocusNode _focus = FocusNode(debugLabel: 'board');

  // Effects: one clock, ticking only while something animates.
  late final BoardFx _fx = BoardFx(onNeedsTick: _ensureFxTicker);
  late final Ticker _fxTicker = createTicker(_onFxTick);
  Duration _fxBase = Duration.zero;

  // Input and the clock stay blocked until the tutorial flag has been read.
  bool _tutorialChecked = false;
  bool _tutorialOpen = false;
  int _tutorialStep = 0;
  bool _resumeAfterOverlay = false;
  late final TutorialStore _tutorialStore =
      widget.tutorialStore ?? PrefsTutorialStore();

  /// First-run tips next to the board; replaces the old blocking card on
  /// first launch (feature-portal-quality-pass).
  FirstRunCoach _coach = FirstRunCoach(active: false);
  bool _tutorialSaved = false;

  _Panel _panel = _Panel.none;
  ClearResult? _result;
  bool _revealDone = false;

  /// The summary of the current win has been shown (Esc keeps it closed).
  bool _summaryShown = false;

  /// Bumped on every load/restart so a late recordClear result of an old
  /// board is ignored.
  int _boardGeneration = 0;
  int _mapPage = 0;
  int _mapSel = 1;
  NonoTheme _themeSel = NonoTheme.notebook;

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
  (int, int) _strokeOrigin = (0, 0);

  bool get _overlayOpen => _tutorialOpen || _panel != _Panel.none;
  bool get _inputBlocked => !_appActive || !_tutorialChecked || _overlayOpen;

  // Whether the platform currently believes gameplay is running.
  bool _appActive =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool _gameplayActive = false;

  /// Reports gameplay start/stop to the platform exactly on transitions.
  void _syncGameplay() {
    final wantActive =
        _appActive && _tutorialChecked && !_overlayOpen && !_game.isWon;
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
  PaperPalette get _palette => PaperPalette.of(_storage.theme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final level = _storage.startupLevel;
    _load(level);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_clock.isRunning && mounted) setState(() {});
    });
    _checkTutorial();
    _loadSoundMuted();
    widget.platform.setAudioMuteListener(_sfx.refreshMute);
  }

  Future<void> _loadSoundMuted() async {
    var muted = false;
    try {
      muted = await widget.soundMuteStore.loadMuted();
    } catch (_) {}
    if (!mounted) return;
    if (!_soundTouched) setState(() => _soundMuted = muted);
    // Music is requested only now, so native shells never start the loop
    // for a player whose saved choice is "sound off".
    _sfx.startMusic();
  }

  void _toggleSound() {
    _soundTouched = true;
    final muted = !_soundMuted;
    setState(() => _soundMuted = muted);
    _sfx.onUserInput();
    _sfx.refreshMute();
    () async {
      try {
        await widget.soundMuteStore.saveMuted(muted);
      } catch (_) {}
    }();
    _focus.requestFocus();
  }

  /// Any pointer or key input: browsers only allow music after one.
  void _onAnyInput() => _sfx.onUserInput();

  // ---- Effects clock ----------------------------------------------------

  void _ensureFxTicker() {
    if (!mounted || _fxTicker.isActive) return;
    _fxBase = _fx.now;
    _fxTicker.start();
  }

  void _onFxTick(Duration elapsed) {
    _fx.tick(_fxBase + elapsed);
    if (!_fx.isActive) _fxTicker.stop();
  }

  /// Queues pop/erase effects for cells that differ from [before], rippling
  /// outward from the stroke origin.
  void _cellFx(List<Mark> before) {
    final n = _game.size;
    final changed = <int>[
      for (var i = 0; i < before.length; i++)
        if (before[i] != _game.cells[i]) i,
    ];
    if (changed.isEmpty) return;
    int dist(int i) =>
        (i ~/ n - _strokeOrigin.$1).abs() + (i % n - _strokeOrigin.$2).abs();
    changed.sort((a, b) => dist(a).compareTo(dist(b)));
    final d0 = dist(changed.first);
    for (final i in changed) {
      final existing = _fx.pops[i];
      // Cells already animating along this stroke keep their stagger.
      final delay = existing == null
          ? Duration(milliseconds: 22 * math.min(8, dist(i) - d0))
          : Duration.zero;
      _fx.cellChanged(i, before[i], _game.cells[i], delay: delay);
    }
  }

  /// Phone vibration, skipped on web and while sound is muted.
  void _haptic(HapticKind kind) {
    final muted = _soundMuted || widget.platform.isAudioMuted;
    final hook = widget.onHaptic;
    if (hook != null) {
      if (!muted) hook(kind);
      return;
    }
    if (kIsWeb || muted) return;
    final Future<void> pulse = switch (kind) {
      HapticKind.light => HapticFeedback.lightImpact(),
      HapticKind.medium => HapticFeedback.mediumImpact(),
      HapticKind.heavy => HapticFeedback.heavyImpact(),
    };
    pulse.catchError((Object _) {});
  }

  /// Line effects and sounds after a finished action that changed the board.
  /// Returns how many lines it celebrated.
  int _lineFeedback(List<Mark> before) {
    if (_game.isWon) return 0;
    final was = _LineState(_game.puzzle, before);
    final now = _LineState(_game.puzzle, _game.cells);
    final newOverRows = now.rowsOver.difference(was.rowsOver);
    final newOverCols = now.colsOver.difference(was.colsOver);
    if (newOverRows.isNotEmpty || newOverCols.isNotEmpty) {
      for (final r in newOverRows) {
        _fx.lineError(true, r);
      }
      for (final c in newOverCols) {
        _fx.lineError(false, c);
      }
      _fx.shake();
      _sfx.play(Sfx.mistake);
      _haptic(HapticKind.medium);
      return 0;
    }
    final doneRows = now.rowsDone.difference(was.rowsDone);
    final doneCols = now.colsDone.difference(was.colsDone);
    // Lines with an empty clue are "done" from the start; only celebrate
    // lines that hold ink.
    final rows = doneRows.where((r) => _game.puzzle.clues.rows[r].isNotEmpty);
    final cols = doneCols.where((c) => _game.puzzle.clues.cols[c].isNotEmpty);
    for (final r in rows) {
      _fx.lineDone(true, r);
    }
    for (final c in cols) {
      _fx.lineDone(false, c);
    }
    final count = rows.length + cols.length;
    if (count > 0) {
      _sfx.play(Sfx.lineDone);
      _haptic(HapticKind.light);
    }
    if (count >= 2) {
      _flash(count == 2 ? 'Double line!' : '$count lines at once!');
    }
    return count;
  }

  /// Plays the one sound of a finished fill/mark action: level_clear on a
  /// win, otherwise fill or mark when the board changed (plus a line chime
  /// or mistake buzz).
  void _playChange(List<Mark>? before, Tool tool) {
    if (_game.isWon) {
      _sfx.play(Sfx.levelClear);
      _haptic(HapticKind.heavy);
    } else if (before != null && !listEquals(before, _game.cells)) {
      _sfx.play(tool == Tool.fill ? Sfx.fill : Sfx.mark);
      final lines = _lineFeedback(before);
      var filled = 0, crossed = 0;
      for (var i = 0; i < before.length; i++) {
        if (before[i] == _game.cells[i]) continue;
        if (_game.cells[i] == Mark.filled) filled++;
        if (_game.cells[i] == Mark.crossed) crossed++;
      }
      _coachChanged(
        _coach.onBoardChange(
          filledAdded: filled,
          crossedAdded: crossed,
          linesDone: lines,
        ),
      );
    }
  }

  // ---- Tutorial and overlays -------------------------------------------

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
      // New players get the tip strip and can play right away; the full
      // How to play card stays one tap away on "?".
      if (!seen) _coach = FirstRunCoach(active: true);
    });
    _syncGameplay();
  }

  /// Stores the tutorial flag once; failures never break play.
  void _markTutorialSeen() {
    if (_tutorialSaved) return;
    _tutorialSaved = true;
    () async {
      try {
        await _tutorialStore.markSeen();
      } catch (_) {}
    }();
  }

  /// Applies a coach transition: redraws, and stores the flag when done.
  void _coachChanged(bool changed) {
    if (!changed) return;
    if (!_coach.visible) _markTutorialSeen();
    if (mounted) setState(() {});
  }

  void _dismissCoach() {
    _coachChanged(_coach.dismiss());
    _focus.requestFocus();
  }

  /// Size of the board when the puzzle has a completely filled line.
  int? get _fullLine {
    final n = _game.size;
    final clues = _game.puzzle.clues;
    final full = [
      ...clues.rows,
      ...clues.cols,
    ].any((l) => l.length == 1 && l.first == n);
    return full ? n : null;
  }

  bool get _showCoach => _coach.visible && _tutorialChecked && !_game.isWon;

  Widget _coachStrip(PaperPalette p, {required bool pointer}) => CoachStrip(
    palette: p,
    step: _coach.step,
    text: coachText(_coach.step, fullLine: _fullLine, pointer: pointer),
    onDismiss: _dismissCoach,
  );

  /// Pauses the clock for an overlay. Call inside setState.
  void _pauseForOverlay() {
    if (_clock.isRunning) {
      _clock.stop();
      _resumeAfterOverlay = true;
      _saveProgress();
    }
  }

  void _resumeAfterClose() {
    if (_resumeAfterOverlay && !_overlayOpen) _startClock();
    if (!_overlayOpen) _resumeAfterOverlay = false;
  }

  /// Opens the tutorial at step 1 and pauses the clock. Call inside setState.
  void _openTutorial() {
    _tutorialOpen = true;
    _tutorialStep = 0;
    _pauseForOverlay();
    _syncGameplay();
  }

  void _closeTutorial() {
    setState(() {
      _tutorialOpen = false;
      // Reading the full card covers what the tip strip would teach.
      _coach.dismiss();
      _resumeAfterClose();
    });
    _syncGameplay();
    _focus.requestFocus();
    _maybeOpenSummary();
    _tutorialSaved = false;
    _markTutorialSeen();
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

  void _openPanel(_Panel panel) {
    if (_tutorialOpen) return;
    setState(() {
      _panel = panel;
      if (panel == _Panel.levels) {
        _mapSel = _level;
        _mapPage = (_level - 1) ~/ kMapPageSize;
      } else if (panel == _Panel.themes) {
        _themeSel = _storage.theme;
      }
      _pauseForOverlay();
    });
    _syncGameplay();
  }

  void _closePanel() {
    if (_panel == _Panel.none) return;
    setState(() {
      _panel = _Panel.none;
      _resumeAfterClose();
    });
    _syncGameplay();
    _focus.requestFocus();
    // A win whose bloom ended while another overlay was open still gets
    // its summary.
    _maybeOpenSummary();
  }

  /// Leaves an overlay for another level (no clock resume for the old one).
  void _openLevelFromOverlay(int level) {
    if (level < 1 || level > _storage.unlocked) return;
    _resumeAfterOverlay = false;
    setState(() => _panel = _Panel.none);
    _goTo(level);
    _focus.requestFocus();
  }

  void _applyTheme(NonoTheme theme) {
    if (!theme.unlockedAt(_storage.painterLevel.level)) return;
    setState(() {
      _themeSel = theme;
      _storage.setTheme(theme);
    });
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _revealDone = true;
      _maybeOpenSummary();
    }
  }

  void _maybeOpenSummary() {
    if (!mounted || !_revealDone || _result == null || !_game.isWon) return;
    if (_summaryShown) return;
    final r = _result!;
    final sameBoard = r.daily == null
        ? _dailyDay == null && r.level == _level
        : r.daily!.day == _dailyDay;
    if (!sameBoard || _panel != _Panel.none || _tutorialOpen) return;
    setState(() {
      _panel = _Panel.summary;
      _summaryShown = true;
    });
    _syncGameplay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.platform.setAudioMuteListener(null);
    _ticker?.cancel();
    _mistakeTimer?.cancel();
    _messageTimer?.cancel();
    _toastTimer?.cancel();
    _reveal.dispose();
    _fxTicker.dispose();
    _fx.dispose();
    _focus.dispose();
    _sfx.dispose();
    super.dispose();
  }

  /// Pauses the clock and music while the app or browser tab is not visible
  /// and saves the elapsed time so a reload does not lose it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _sfx.setAppVisible(_appActive);
    _syncGameplay();
    if (state == AppLifecycleState.resumed) {
      if (_wasRunning && !_overlayOpen) _startClock();
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
    final day = _dailyDay;
    if (day != null) {
      unawaited(
        _storage.saveDailyProgress(
          DailyProgress(day, _game.encode(), _elapsed, mistakes: _mistakeMade),
        ),
      );
      return;
    }
    unawaited(
      _storage.saveProgress(
        SavedProgress(_level, _game.encode(), _elapsed, mistakes: _mistakeMade),
      ),
    );
  }

  /// Keeps the elapsed time of a running daily board before it is left.
  void _leaveBoard() {
    if (_clock.isRunning && !_game.isWon) {
      _clock.stop();
      _saveProgress();
    }
  }

  /// Puts [puzzle] on the board with a fresh clock and no effects.
  void _resetBoard(Puzzle puzzle) {
    _game = NonoGame(puzzle);
    _clock
      ..stop()
      ..reset();
    _baseSeconds = 0;
    _reveal.value = 0;
    _revealDone = false;
    _summaryShown = false;
    _boardGeneration++;
    _result = null;
    _mistakes = {};
    _mistakeMade = false;
    _cursor = (0, 0);
    _fx.clear();
  }

  void _load(int level) {
    if (_dailyDay != null) _leaveBoard();
    _dailyDay = null;
    _level = level;
    _resetBoard(_storage.puzzleFor(level));
    final saved = _storage.progress;
    if (saved != null && saved.level == level) {
      if (_game.restore(saved.cells) && !_game.isWon) {
        _baseSeconds = saved.elapsedSeconds;
        _mistakeMade = saved.mistakes;
      } else {
        _game.restart();
      }
    }
    unawaited(_storage.setLevel(level));
  }

  /// Opens [day]'s daily puzzle, resuming its saved board of that day.
  void _loadDaily(int day) {
    _dailyDay = day;
    _resetBoard(_storage.dailyPuzzleFor(day));
    final saved = _storage.dailyProgressFor(day);
    if (saved != null) {
      if (_game.restore(saved.cells) && !_game.isWon) {
        _baseSeconds = saved.elapsedSeconds;
        _mistakeMade = saved.mistakes;
      } else {
        _game.restart();
      }
    }
  }

  int get _today => dayIndexOf(widget.clock());

  DailyInfo _dailyInfo() {
    final today = _today;
    final live = _dailyDay == today && !_game.isWon ? _elapsed : null;
    return DailyInfo.of(_storage, today, liveElapsed: live);
  }

  void _openDaily() {
    if (_tutorialOpen) return;
    _onStrokeEnd();
    _openPanel(_Panel.daily);
  }

  /// Enter/Play in the daily overlay: start or resume today's daily, or
  /// close when it is already solved.
  void _playDaily() {
    final today = _today;
    if (_storage.dailyResultFor(today) != null || _dailyDay == today) {
      _closePanel();
      return;
    }
    _resumeAfterOverlay = false;
    setState(() {
      _panel = _Panel.none;
      _loadDaily(today);
    });
    _syncGameplay();
    _focus.requestFocus();
  }

  /// Leaves the daily board for the level the player was on.
  void _backToLevels() {
    if (_dailyDay == null) return;
    _resumeAfterOverlay = false;
    setState(() {
      _panel = _Panel.none;
      _load(_storage.level.clamp(1, _storage.unlocked));
    });
    _syncGameplay();
    _focus.requestFocus();
  }

  /// Copies the result of the latest solved daily (today's, or the board's).
  Future<void> _copyDaily() async {
    final day = _dailyDay ?? _today;
    final result =
        _storage.dailyResultFor(day) ?? _storage.dailyResultFor(_today);
    if (result == null) return;
    final text = dailyShareText(
      day: result.day,
      size: dailySize(result.day),
      seconds: result.seconds,
      stars: result.stars,
      streak: streakOn(_storage.daily.streak, result.day).current,
      link: widget.platform.shareLink,
    );
    var ok = false;
    try {
      ok = await widget.copier.copyText(text);
    } catch (_) {
      ok = false;
    }
    if (mounted) _showToast(ok ? 'Copied!' : 'Could not copy');
  }

  /// Short message drawn above every overlay.
  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// Next button / Enter after a win.
  void _advance() {
    if (_dailyDay != null) {
      _backToLevels();
    } else {
      _goTo(_level + 1);
    }
  }

  void _goTo(int level) {
    if (level < 1 || level > _storage.unlocked) return;
    // Saved progress is kept: it belongs to one level and is restored when
    // that level is opened again, until a move on another level replaces it.
    setState(() {
      if (_panel == _Panel.summary) _panel = _Panel.none;
      _load(level);
    });
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
    _strokeOrigin = (r, c);
    final before = List<Mark>.of(_game.cells);
    setState(() {
      _showCursor = false;
      _cursor = (r, c);
      _game.beginStroke(r, c, tool);
    });
    _cellFx(before);
  }

  void _onStrokeMove(int r, int c) {
    if (!_game.isStroking) return;
    final before = List<Mark>.of(_game.cells);
    setState(() => _game.updateStroke(r, c));
    _cellFx(before);
  }

  void _onStrokeEnd() {
    if (!_game.isStroking) return;
    final beforeEnd = List<Mark>.of(_game.cells);
    setState(_game.endStroke);
    _cellFx(beforeEnd);
    _afterChange();
    _playChange(_strokeBefore, _strokeTool);
    _strokeBefore = null;
  }

  void _tapAtCursor(Tool tool) {
    if (_game.isWon) return;
    _startClock();
    final before = List<Mark>.of(_game.cells);
    _strokeOrigin = _cursor;
    setState(() => _game.tap(_cursor.$1, _cursor.$2, tool));
    _cellFx(before);
    _afterChange();
    _playChange(before, tool);
  }

  void _undo() {
    if (!_game.canUndo) return;
    var undone = false;
    final before = List<Mark>.of(_game.cells);
    setState(() => undone = _game.undo());
    _cellFx(before);
    _afterChange();
    if (_game.isWon) {
      _sfx.play(Sfx.levelClear);
    } else if (undone) {
      _sfx.play(Sfx.undo);
    }
  }

  void _restart() {
    setState(() {
      _game.restart();
      _clock
        ..stop()
        ..reset();
      _baseSeconds = 0;
      _reveal.value = 0;
      _revealDone = false;
      _summaryShown = false;
      _boardGeneration++;
      _result = null;
      _mistakes = {};
      _mistakeMade = false;
      _fx.clear();
    });
    if (_dailyDay != null) {
      unawaited(_storage.clearDailyProgress());
    } else if (_storage.progress?.level == _level) {
      unawaited(_storage.clearProgress());
    }
    _syncGameplay();
  }

  LogicHint _deduceHint() => findLogicHint(_game.puzzle.clues, [
    for (final mark in _game.cells)
      switch (mark) {
        Mark.empty => kUnknown,
        Mark.filled => kFilled,
        Mark.crossed => kEmpty,
      },
  ]);

  void _openLogicHint() {
    if (_game.isWon || _inputBlocked) return;
    _onStrokeEnd();
    if (_game.isWon) return;
    _logicHint = _deduceHint();
    _coachChanged(_coach.onHintOpened());
    _openPanel(_Panel.logic);
  }

  void _applyLogicHint() {
    if (_panel != _Panel.logic || _game.isWon) return;
    final hint = _deduceHint();
    final shown = _logicHint;
    if (!hint.hasStep ||
        hint.row != shown?.row ||
        hint.col != shown?.col ||
        hint.value != shown?.value) {
      setState(() => _logicHint = hint);
      return;
    }
    _closePanel();
    setState(() {
      _cursor = (hint.row!, hint.col!);
      _showCursor = true;
    });
    _tapAtCursor(hint.value == kFilled ? Tool.fill : Tool.cross);
  }

  void _check() {
    if (_game.isWon) return;
    final wrong = _game.mistakes();
    _mistakeTimer?.cancel();
    setState(() {
      _mistakes = wrong.toSet();
      if (wrong.isNotEmpty) _mistakeMade = true;
    });
    _mistakeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _mistakes = {});
    });
    if (wrong.isNotEmpty) {
      _fx.shake();
      _sfx.play(Sfx.mistake);
      _haptic(HapticKind.medium);
      _saveProgress();
    }
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
      _coachChanged(_coach.onSolved());
      _clock.stop();
      final seconds = _elapsed;
      final generation = _boardGeneration;
      final day = _dailyDay;
      final Future<ClearResult> record;
      if (day != null) {
        record = _storage.recordDailyClear(
          day,
          seconds,
          mistakes: _mistakeMade,
        );
      } else {
        unawaited(_storage.clearProgress());
        record = _storage.recordClear(_level, seconds, mistakes: _mistakeMade);
      }
      record.then((r) {
        if (!mounted || generation != _boardGeneration) return;
        setState(() => _result = r);
        _maybeOpenSummary();
      });
      if (_reveal.value == 0) {
        _revealDone = false;
        _reveal.forward(from: 0);
        _fx.confetti();
      }
    } else {
      _saveProgress();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) _onAnyInput();
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
    if (_panel != _Panel.none) {
      if (_isBrowserShortcut(event)) return KeyEventResult.ignored;
      if (event is KeyDownEvent) _panelKey(event.logicalKey);
      return KeyEventResult.handled;
    }
    if (_inputBlocked) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Auto-repeat only moves the cursor; actions need a fresh key press so a
    // held Enter/Space from an overlay cannot paint after it closes.
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
      _advance();
    } else if (key == LogicalKeyboardKey.keyD) {
      _openDaily();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _panelKey(LogicalKeyboardKey k) {
    final enter =
        k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;
    if (k == LogicalKeyboardKey.escape) {
      _closePanel();
      return;
    }
    switch (_panel) {
      case _Panel.summary:
        if (enter || k == LogicalKeyboardKey.space) {
          _advance();
        } else if (k == LogicalKeyboardKey.keyC && _result?.daily != null) {
          _copyDaily();
        }
      case _Panel.album:
        if (enter) {
          final goal = _storage.setGoal;
          if (goal != null) {
            _openLevelFromOverlay(goal.level);
          } else {
            _closePanel();
          }
        }
      case _Panel.daily:
        if (enter || k == LogicalKeyboardKey.space) {
          _playDaily();
        } else if (k == LogicalKeyboardKey.keyC &&
            _storage.dailyResultFor(_today) != null) {
          _copyDaily();
        } else if (k == LogicalKeyboardKey.keyL && _dailyDay != null) {
          _backToLevels();
        }
      case _Panel.levels:
        var sel = _mapSel;
        if (k == LogicalKeyboardKey.arrowRight) sel++;
        if (k == LogicalKeyboardKey.arrowLeft) sel--;
        if (k == LogicalKeyboardKey.arrowDown) sel += 5;
        if (k == LogicalKeyboardKey.arrowUp) sel -= 5;
        if (k == LogicalKeyboardKey.pageDown) sel += kMapPageSize;
        if (k == LogicalKeyboardKey.pageUp) sel -= kMapPageSize;
        sel = sel.clamp(1, _storage.unlocked);
        if (sel != _mapSel) {
          setState(() {
            _mapSel = sel;
            _mapPage = (sel - 1) ~/ kMapPageSize;
          });
        }
        if (enter) _openLevelFromOverlay(_mapSel);
      case _Panel.themes:
        const all = NonoTheme.values;
        var i = all.indexOf(_themeSel);
        if (k == LogicalKeyboardKey.arrowRight ||
            k == LogicalKeyboardKey.arrowDown) {
          i = (i + 1) % all.length;
        }
        if (k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.arrowUp) {
          i = (i - 1 + all.length) % all.length;
        }
        if (all[i] != _themeSel) setState(() => _themeSel = all[i]);
        if (enter) _applyTheme(_themeSel);
      case _Panel.logic:
        break;
      case _Panel.none:
        break;
    }
  }

  // ---- Build ------------------------------------------------------------

  String get _levelTitle => _dailyDay != null
      ? 'Daily ${dayLabel(_dailyDay!)}'
      : _game.puzzle.name ?? 'Level $_level';

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final size = MediaQuery.sizeOf(context);
    final layout = screenLayoutFor(size);
    final wide = layout == ScreenLayout.wide;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ExcludeFocus(
        child: Scaffold(
          backgroundColor: p.deskBottom,
          body: Listener(
            onPointerDown: (_) => _onAnyInput(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DeskScenery(palette: p, showProps: wide),
                ),
                SafeArea(
                  child: switch (layout) {
                    ScreenLayout.wide => _wideLayout(p, size),
                    ScreenLayout.compact => _compactLayout(p, size),
                    ScreenLayout.stacked => _narrowLayout(p, size),
                  },
                ),
                ..._overlays(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _overlays(PaperPalette p) {
    final result = _result;
    return [
      if (_panel == _Panel.logic && _logicHint != null)
        _panelLayer(
          ColoredBox(
            color: Colors.black54,
            child: AlertDialog(
              title: const Text('Logic hint'),
              content: SingleChildScrollView(
                child: Text(
                  '${_logicHint!.explanation}\n\n'
                  'This assumes your current fills and X marks are correct. '
                  'It does not check the hidden picture.\n\n'
                  'Logic hints do not cost stars or XP. Check still affects '
                  'the No mistakes star when it finds a wrong fill.',
                ),
              ),
              actions: [
                TextButton(onPressed: _closePanel, child: const Text('Close')),
                if (_logicHint!.hasStep)
                  TextButton(
                    key: const Key('apply-logic-hint'),
                    onPressed: _applyLogicHint,
                    child: const Text('Apply step'),
                  ),
              ],
            ),
          ),
        ),
      if (_panel == _Panel.summary && result != null)
        _panelLayer(
          SummaryOverlay(
            key: ValueKey('summary-${_dailyDay ?? 'level'}-$_level'),
            palette: p,
            result: result,
            puzzle: _game.puzzle,
            title: _levelTitle,
            onNext: _advance,
            onCopy: result.daily != null ? _copyDaily : null,
            today: _today,
            onReplay: () {
              _closePanel();
              _restart();
            },
            onAlbum: () => setState(() => _panel = _Panel.album),
            onClose: _closePanel,
            onStar: (_) => _sfx.play(Sfx.star),
            onFinished: () {
              if (result.leveledUp) _sfx.play(Sfx.levelUp);
            },
          ),
        ),
      if (_panel == _Panel.album)
        _panelLayer(
          AlbumOverlay(
            palette: p,
            sets: _storage.albumSets,
            goal: _storage.setGoal,
            unlocked: _storage.unlocked,
            dailyTotal: _storage.daily.streak.total,
            dailyBest: _storage.daily.streak.best,
            solved: _storage.solvedLevels,
            starsOf: _storage.stars,
            puzzleOf: _storage.previewPuzzle,
            onOpen: _openLevelFromOverlay,
            onClose: _closePanel,
          ),
        ),
      if (_panel == _Panel.levels)
        _panelLayer(
          LevelMapOverlay(
            palette: p,
            page: _mapPage,
            selected: _mapSel,
            current: _level,
            unlocked: _storage.unlocked,
            starsOf: _storage.stars,
            puzzleOf: _storage.previewPuzzle,
            onSelect: _openLevelFromOverlay,
            onPage: (page) => setState(() {
              _mapPage = math.max(0, page);
              // Keep the keyboard selection on the visible page.
              final first = _mapPage * kMapPageSize + 1;
              _mapSel = _mapSel.clamp(
                math.min(first, _storage.unlocked),
                math.min(first + kMapPageSize - 1, _storage.unlocked),
              );
            }),
            onClose: _closePanel,
          ),
        ),
      if (_panel == _Panel.themes)
        _panelLayer(
          ThemeOverlay(
            palette: p,
            current: _storage.theme,
            selected: _themeSel,
            painterLevel: _storage.painterLevel.level,
            onPick: _applyTheme,
            onClose: _closePanel,
          ),
        ),
      if (_panel == _Panel.daily)
        _panelLayer(
          DailyOverlay(
            palette: p,
            info: _dailyInfo(),
            playing: _dailyDay != null && _dailyDay == _today,
            onPlay: _playDaily,
            onBack: _backToLevels,
            onCopy: _copyDaily,
            onClose: _closePanel,
          ),
        ),
      if (_tutorialOpen)
        _panelLayer(
          HowToPlayOverlay(
            palette: p,
            steps: nonoGridSteps,
            step: _tutorialStep,
            onNext: _tutorialNext,
            onSkip: _closeTutorial,
          ),
        ),
      if (_toast != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: IgnorePointer(
            child: Center(
              child: PaperPanel(
                key: const Key('toast'),
                palette: p,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _toast!,
                  style: TextStyle(
                    color: p.panelText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// Full-screen overlay layer that eases in instead of popping.
  Widget _panelLayer(Widget child) =>
      Positioned.fill(child: _FadeIn(child: child));

  Widget _board(PaperPalette p) => NonoBoard(
    game: _game,
    tool: _tool,
    cursor: _cursor,
    showCursor: _showCursor,
    reveal: _reveal,
    palette: p,
    picture: PicturePalette.forLevel(_game.puzzle.level),
    mistakes: _mistakes,
    fx: _fx,
    onStrokeStart: _onStrokeStart,
    onStrokeMove: _onStrokeMove,
    onStrokeEnd: _onStrokeEnd,
  );

  bool get _showWinBar => _game.isWon && _panel != _Panel.summary;

  // Wide: left info panel, board, right tool panel.
  Widget _wideLayout(PaperPalette p, Size size) {
    final leftW = (size.width * 0.21).clamp(200.0, 270.0);
    final rightW = (size.width * 0.18).clamp(180.0, 236.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: leftW, child: _infoPanel(p)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              // Bottom-up so the strip paints over the board card's tape.
              child: Column(
                verticalDirection: VerticalDirection.up,
                children: [
                  Expanded(child: _board(p)),
                  // Room for the board card's tape, drawn above the card.
                  if (_showCoach) const SizedBox(height: 10),
                  if (_showCoach)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _coachStrip(p, pointer: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: rightW, child: _toolPanel(p)),
        ],
      ),
    );
  }

  /// Header of the daily board: back to levels, date and size.
  Widget _dailyNav(PaperPalette p, {required bool big}) {
    final day = _dailyDay!;
    final stars = _storage.dailyResultFor(day)?.stars ?? 0;
    return Row(
      children: [
        IconButton(
          key: const Key('daily-nav-back'),
          tooltip: 'Back to levels',
          color: p.panelText,
          visualDensity: VisualDensity.compact,
          onPressed: _backToLevels,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Daily',
                  key: const Key('daily-title'),
                  style: TextStyle(
                    color: p.panelText,
                    fontSize: big ? 20 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${dayLabel(day)}  ${_game.size}x${_game.size}',
                      style: TextStyle(color: p.panelSubtle, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    StarRow(count: stars, palette: p, size: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _levelNav(PaperPalette p, {required bool big}) {
    if (_dailyDay != null) return _dailyNav(p, big: big);
    final best = _storage.stars(_level);
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous level',
          color: p.panelText,
          disabledColor: p.panelText.withValues(alpha: 0.25),
          visualDensity: VisualDensity.compact,
          onPressed: _level > 1 ? () => _goTo(_level - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Level $_level',
                  style: TextStyle(
                    color: p.panelText,
                    fontSize: big ? 20 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_game.size}x${_game.size}',
                      style: TextStyle(color: p.panelSubtle, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    StarRow(count: best, palette: p, size: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Next level',
          color: p.panelText,
          disabledColor: p.panelText.withValues(alpha: 0.25),
          visualDensity: VisualDensity.compact,
          onPressed: _level < _storage.unlocked
              ? () => _goTo(_level + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _timeBlock(PaperPalette p, {required bool big, bool small = false}) {
    final best = _dailyDay != null ? null : _storage.bestSeconds(_level);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: big
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      children: [
        Text(
          formatTime(_elapsed),
          style: TextStyle(
            color: p.panelText,
            fontSize: small ? 20 : (big ? 30 : 18),
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          _dailyDay != null
              ? 'Daily'
              : best == null
              ? 'Best --'
              : 'Best ${formatTime(best)}',
          style: TextStyle(color: p.panelSubtle, fontSize: 12),
        ),
      ],
    );
  }

  /// The three star goals of this board, ticked live.
  Widget _goals(PaperPalette p) {
    final par = parSeconds(_game.size);
    Widget goal(bool ok, bool failed, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok
                ? Icons.star_rounded
                : failed
                ? Icons.star_border_rounded
                : Icons.star_outline_rounded,
            size: 18,
            color: ok
                ? const Color(0xFFF2B01E)
                : p.panelSubtle.withValues(alpha: failed ? 0.4 : 0.9),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: failed
                    ? p.panelSubtle.withValues(alpha: 0.6)
                    : p.panelText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: failed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
    final won = _game.isWon;
    final overPar = _elapsed > par;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Star goals',
          style: TextStyle(
            color: p.panelSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        goal(won, false, 'Solve the picture'),
        goal(won && !_mistakeMade, _mistakeMade, 'No mistakes from Check'),
        goal(won && !overPar, overPar, 'Under par ${formatTime(par)}'),
      ],
    );
  }

  Widget _xpBlock(PaperPalette p) {
    final lv = _storage.painterLevel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XpBar(level: lv, palette: p),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                'Painter  ${lv.xpInto}/${lv.xpNeeded} XP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.panelSubtle, fontSize: 11),
              ),
            ),
            CustomPaint(
              size: const Size.square(12),
              painter: _MiniStarPainter(p),
            ),
            const SizedBox(width: 3),
            Text(
              '${_storage.totalStars}',
              style: TextStyle(
                color: p.panelText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _metaButtons(
    PaperPalette p, {
    required bool expand,
    bool iconOnly = false,
  }) => [
    PaperButton(
      key: const Key('open-levels'),
      palette: p,
      label: 'Levels',
      icon: Icons.map_outlined,
      compact: true,
      expand: expand,
      iconOnly: iconOnly,
      onPressed: () => _openPanel(_Panel.levels),
    ),
    PaperButton(
      key: const Key('open-album'),
      palette: p,
      label: 'Album',
      icon: Icons.photo_library_outlined,
      compact: true,
      expand: expand,
      iconOnly: iconOnly,
      onPressed: () => _openPanel(_Panel.album),
    ),
    PaperButton(
      key: const Key('open-themes'),
      palette: p,
      label: 'Themes',
      icon: Icons.palette_outlined,
      compact: true,
      expand: expand,
      iconOnly: iconOnly,
      onPressed: () => _openPanel(_Panel.themes),
    ),
  ];

  /// Levels, Album and Themes as one row of icon buttons.
  Widget _metaIconRow(PaperPalette p) => Row(
    children: [
      for (final b in _metaButtons(p, expand: true, iconOnly: true)) ...[
        Expanded(child: b),
        const SizedBox(width: 4),
      ],
    ]..removeLast(),
  );

  Widget _dailyCard(PaperPalette p, {required bool compact}) => DailyCard(
    palette: p,
    info: _dailyInfo(),
    compact: compact,
    playing: _dailyDay != null && _dailyDay == _today,
    onTap: _openDaily,
  );

  Widget _infoPanel(PaperPalette p) => PaperPanel(
    palette: p,
    tape: true,
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
    child: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: NonoLogo(palette: p, size: 28)),
              const SizedBox(height: 12),
              _levelNav(p, big: true),
              if (_game.puzzle.name != null)
                Center(
                  child: Text(
                    _game.isWon ? _game.puzzle.name! : '? ? ?',
                    style: TextStyle(color: p.panelSubtle, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              _timeBlock(p, big: true),
              const SizedBox(height: 10),
              // Kept high so short landscape screens show it unscrolled.
              _dailyCard(p, compact: c.maxHeight < 520),
              // Short panels lift Levels/Album/Themes next to Daily as icon
              // buttons so every menu stays reachable without scrolling.
              if (c.maxHeight < _kMetaRowMaxPanelHeight) ...[
                const SizedBox(height: 8),
                _metaIconRow(p),
              ],
              const SizedBox(height: 12),
              _goals(p),
              const SizedBox(height: 14),
              _xpBlock(p),
              if (c.maxHeight >= _kMetaRowMaxPanelHeight) ...[
                const SizedBox(height: 16),
                for (final b in _metaButtons(p, expand: true)) ...[
                  b,
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _soundHelp(PaperPalette p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const Key('sound-toggle'),
        tooltip: _soundMuted ? 'Sound off' : 'Sound on',
        color: p.panelText,
        visualDensity: VisualDensity.compact,
        onPressed: _toggleSound,
        icon: Icon(
          _soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        ),
      ),
      IconButton(
        key: const Key('how-to-play-button'),
        tooltip: 'How to play',
        color: p.panelText,
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(_openTutorial),
        icon: const Icon(Icons.help_outline_rounded),
      ),
    ],
  );

  Widget _toolButtons(
    PaperPalette p, {
    required bool vertical,
    bool dense = false,
    bool slim = false,
    bool iconOnly = false,
  }) {
    final items = <Widget>[
      PaperButton(
        key: const Key('tool-fill'),
        palette: p,
        label: 'Fill',
        iconOnly: iconOnly,
        icon: Icons.square_rounded,
        selected: _tool == Tool.fill,
        compact: !vertical || dense,
        expand: vertical,
        onPressed: () => setState(() => _tool = Tool.fill),
      ),
      PaperButton(
        key: const Key('tool-cross'),
        palette: p,
        label: 'Mark X',
        iconOnly: iconOnly,
        icon: Icons.close_rounded,
        selected: _tool == Tool.cross,
        compact: !vertical || dense,
        expand: vertical,
        onPressed: () => setState(() => _tool = Tool.cross),
      ),
      PaperButton(
        palette: p,
        label: 'Undo',
        iconOnly: slim || iconOnly,
        icon: Icons.undo_rounded,
        compact: true,
        expand: vertical,
        onPressed: _game.canUndo ? _undo : null,
      ),
      PaperButton(
        key: const Key('logic-hint'),
        palette: p,
        label: 'Logic hint',
        iconOnly: iconOnly,
        icon: Icons.lightbulb_outline,
        compact: true,
        expand: vertical,
        onPressed: _game.isWon || _inputBlocked ? null : _openLogicHint,
      ),
      PaperButton(
        palette: p,
        label: 'Check',
        iconOnly: slim || iconOnly,
        icon: Icons.fact_check_outlined,
        compact: true,
        expand: vertical,
        onPressed: _game.isWon ? null : _check,
      ),
      PaperButton(
        palette: p,
        label: 'Restart',
        iconOnly: slim || iconOnly,
        icon: Icons.refresh_rounded,
        compact: true,
        expand: vertical,
        onPressed: _restart,
      ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            SizedBox(height: dense ? 4 : (i == 1 ? 16 : 8)),
          ],
        ],
      );
    }
    return Wrap(
      key: const ValueKey('tools'),
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: items,
    );
  }

  Widget _winBox(
    PaperPalette p, {
    required bool vertical,
    bool small = false,
    bool iconOnly = false,
  }) {
    final best = _dailyDay != null ? null : _storage.bestSeconds(_level);
    final text = Text(
      iconOnly
          ? formatTime(_elapsed)
          : '$_levelTitle! Solved in ${formatTime(_elapsed)}'
                '${best != null ? '  Best ${formatTime(best)}' : ''}',
      textAlign: vertical ? TextAlign.center : TextAlign.start,
      maxLines: small ? 4 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: p.panelText,
        fontSize: small ? 13 : 15,
        fontWeight: FontWeight.w800,
      ),
    );
    final next = PaperButton(
      key: const Key('win-next'),
      palette: p,
      label: _dailyDay != null ? 'Levels' : 'Next',
      icon: _dailyDay != null
          ? Icons.map_outlined
          : Icons.arrow_forward_rounded,
      primary: true,
      expand: vertical,
      iconOnly: iconOnly,
      onPressed: _advance,
    );
    if (vertical) {
      return Column(
        key: const ValueKey('win'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [text, const SizedBox(height: 10), next],
      );
    }
    return Row(
      key: const ValueKey('win'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: text),
        const SizedBox(width: 12),
        next,
      ],
    );
  }

  String _hint(bool wide) {
    if (_game.isWon) {
      return _dailyDay != null
          ? 'Press Enter to go back to the levels'
          : 'Press Next or Enter for the next puzzle';
    }
    return wide
        ? 'Drag to paint. Right-click: X. Keys: arrows, Space, X, U undo, '
              'R restart, D daily'
        : 'Tap or drag to paint  -  Switch to X to mark empty cells';
  }

  Widget _toolPanel(PaperPalette p) => PaperPanel(
    palette: p,
    tape: true,
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
    child: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tools',
                style: TextStyle(
                  color: p.panelSubtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _showWinBar
                    ? _winBox(p, vertical: true)
                    : _game.isWon
                    ? const SizedBox(key: ValueKey('none'), height: 1)
                    : _toolButtons(p, vertical: true, dense: c.maxHeight < 400),
              ),
              const SizedBox(height: 12),
              // Short panels (landscape phones) drop the key hint, which the
              // tutorial also covers, so nothing is clipped; messages keep a
              // single line there.
              if (_message != null || c.maxHeight >= _kHintMinPanelHeight)
                Text(
                  _message ?? _hint(true),
                  key: const Key('panel-hint'),
                  maxLines: c.maxHeight >= _kHintMinPanelHeight ? null : 1,
                  overflow: c.maxHeight >= _kHintMinPanelHeight
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _message != null ? p.accent : p.panelSubtle,
                    fontSize: _message != null ? 14 : 11,
                    height: 1.3,
                    fontWeight: _message != null
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              const SizedBox(height: 4),
              Center(child: _soundHelp(p)),
            ],
          ),
        ),
      ),
    ),
  );

  // Compact: short landscape windows (portal previews such as 620x349, phones
  // on their side). Board first: slim info column, board, slim tool column.
  Widget _compactLayout(PaperPalette p, Size size) {
    final leftW = (size.width * 0.27).clamp(160.0, 190.0);
    // Under 600 px the tool column shows icons only (labels stay as tooltips
    // and semantics) so 15x15 boards keep their 11 px clue font.
    final iconTools = size.width < kCompactIconToolsMaxWidth;
    final rightW = iconTools ? 64.0 : (size.width * 0.21).clamp(124.0, 150.0);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('compact-info'),
            width: leftW,
            child: _compactInfoPanel(p),
          ),
          Expanded(
            child: _stripOverBoard(
              p,
              stripPadding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              board: _board(p),
            ),
          ),
          SizedBox(
            key: const Key('compact-tools'),
            width: rightW,
            child: _compactToolPanel(p, iconOnly: iconTools),
          ),
        ],
      ),
    );
  }

  /// The first-run tip strip above the board. Laid out bottom-up so the strip
  /// paints after the board: the card's tape tucks under the strip instead
  /// of covering its edge, without spending board height on a tape gap.
  Widget _stripOverBoard(
    PaperPalette p, {
    required EdgeInsets stripPadding,
    required Widget board,
  }) => Column(
    verticalDirection: VerticalDirection.up,
    children: [
      Expanded(child: board),
      if (_showCoach)
        Padding(padding: stripPadding, child: _coachStrip(p, pointer: false)),
    ],
  );

  Widget _compactInfoPanel(PaperPalette p) => PaperPanel(
    palette: p,
    padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
    child: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _levelNav(p, big: false),
                  Center(child: _timeBlock(p, big: true, small: true)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _dailyCard(p, compact: true),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _metaIconRow(p),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _xpBlock(p),
                  ),
                ],
              ),
              // Check results and other short messages; the slim tool column
              // has no room for text.
              if (_message != null)
                Text(
                  _message!,
                  key: const Key('panel-hint'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Center(child: _soundHelp(p)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _compactToolPanel(PaperPalette p, {required bool iconOnly}) =>
      PaperPanel(
        palette: p,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _showWinBar
                        ? _winBox(
                            p,
                            vertical: true,
                            small: true,
                            iconOnly: iconOnly,
                          )
                        : _game.isWon
                        ? const SizedBox(key: ValueKey('none'), height: 1)
                        : _toolButtons(
                            p,
                            vertical: true,
                            dense: true,
                            iconOnly: iconOnly,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // Narrow: stacked header, board, tools. Short windows fold Daily and the
  // Levels/Album/Themes buttons into one row.
  Widget _narrowLayout(PaperPalette p, Size size) {
    final folded = size.height < kFoldedMetaMaxHeight;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 0),
          child: Row(
            children: [
              Expanded(child: NonoLogo(palette: p, size: 22)),
              _soundHelp(p),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: PaperPanel(
            palette: p,
            padding: const EdgeInsets.fromLTRB(2, 4, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _levelNav(p, big: false)),
                    _timeBlock(p, big: false),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _xpBlock(p),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (folded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(child: _dailyCard(p, compact: true)),
                const SizedBox(width: 6),
                SizedBox(width: 132, child: _metaIconRow(p)),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (final b in _metaButtons(p, expand: true)) ...[
                  Expanded(child: b),
                  const SizedBox(width: 6),
                ],
              ]..removeLast(),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _dailyCard(p, compact: true),
          ),
        ],
        Expanded(
          child: _stripOverBoard(
            p,
            stripPadding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            board: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: _board(p),
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: Text(
            _message ?? _hint(false),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _message != null ? p.accent : p.deskText,
              fontSize: 13,
              fontWeight: _message != null ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showWinBar
                ? PaperPanel(
                    palette: p,
                    padding: const EdgeInsets.all(8),
                    child: _winBox(p, vertical: false),
                  )
                : _game.isWon
                ? const SizedBox(key: ValueKey('none'), height: 1)
                : _toolButtons(p, vertical: false, slim: folded),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MiniStarPainter extends CustomPainter {
  _MiniStarPainter(this.p);
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) => Shapes.paintStar(
    canvas,
    size.center(Offset.zero),
    size.width / 2,
    filled: true,
    fill: const Color(0xFFFFC93C),
    outline: p.panelBorder,
  );

  @override
  bool shouldRepaint(_MiniStarPainter old) => old.p != p;
}

/// Short ease-in for overlays (no repeat, no cost once settled). Opacity
/// starts above zero so the overlay is never dropped from semantics.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: 0.25 + 0.75 * t,
      child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
    ),
    child: child,
  );
}
