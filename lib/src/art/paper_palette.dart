import 'package:flutter/painting.dart';

import '../meta/progress_rules.dart';

/// Colors of one paper/ink theme: the craft desk, the paper card, the ink.
class PaperPalette {
  const PaperPalette({
    required this.deskTop,
    required this.deskBottom,
    required this.grain,
    required this.paper,
    required this.paperShade,
    required this.clueBand,
    required this.clueHighlight,
    required this.clueText,
    required this.clueDone,
    required this.ink,
    required this.inkHighlight,
    required this.cross,
    required this.gridThin,
    required this.gridBold,
    required this.accent,
    required this.accentInk,
    required this.mistake,
    required this.flash,
    required this.tape,
    required this.tapeStripe,
    required this.panel,
    required this.panelBorder,
    required this.panelText,
    required this.panelSubtle,
    required this.deskText,
    required this.night,
  });

  final Color deskTop;
  final Color deskBottom;
  final Color grain;
  final Color paper;
  final Color paperShade;
  final Color clueBand;
  final Color clueHighlight;
  final Color clueText;
  final Color clueDone;
  final Color ink;
  final Color inkHighlight;
  final Color cross;
  final Color gridThin;
  final Color gridBold;
  final Color accent;

  /// Text/icon color on [accent].
  final Color accentInk;
  final Color mistake;

  /// Line-complete glow.
  final Color flash;
  final Color tape;
  final Color tapeStripe;
  final Color panel;
  final Color panelBorder;
  final Color panelText;
  final Color panelSubtle;

  /// Text drawn straight on the desk (hints).
  final Color deskText;

  /// Dark theme: the desk gets a lamp glow and a few stars.
  final bool night;

  static PaperPalette of(NonoTheme theme) => switch (theme) {
    NonoTheme.notebook => notebook,
    NonoTheme.kraft => kraft,
    NonoTheme.washi => washi,
    NonoTheme.midnight => midnight,
  };

  static const notebook = PaperPalette(
    deskTop: Color(0xFFD8B184),
    deskBottom: Color(0xFFB98B5C),
    grain: Color(0xFF9C7048),
    paper: Color(0xFFFBF6EA),
    paperShade: Color(0xFFEDE4D0),
    clueBand: Color(0xFFF1E9D6),
    clueHighlight: Color(0xFFE4D8BC),
    clueText: Color(0xFF233059),
    clueDone: Color(0x66233059),
    ink: Color(0xFF233059),
    inkHighlight: Color(0xFF3B4C82),
    cross: Color(0xFF8A7F70),
    gridThin: Color(0xFFD5CAB3),
    gridBold: Color(0xFF233059),
    accent: Color(0xFFE8704F),
    accentInk: Color(0xFFFFFBF3),
    mistake: Color(0xFFD9473A),
    flash: Color(0xFFFFD45C),
    tape: Color(0xCC9ED8C6),
    tapeStripe: Color(0x66FFFFFF),
    panel: Color(0xFFFBF6EA),
    panelBorder: Color(0xFF233059),
    panelText: Color(0xFF233059),
    panelSubtle: Color(0xFF6C6A78),
    deskText: Color(0xFF4A3220),
    night: false,
  );

  static const kraft = PaperPalette(
    deskTop: Color(0xFF5B4130),
    deskBottom: Color(0xFF3E2B1F),
    grain: Color(0xFF2E1F16),
    paper: Color(0xFFDDBF8F),
    paperShade: Color(0xFFC9A673),
    clueBand: Color(0xFFD1B27F),
    clueHighlight: Color(0xFFC29E68),
    clueText: Color(0xFF2B2420),
    clueDone: Color(0x662B2420),
    ink: Color(0xFF2B2420),
    inkHighlight: Color(0xFF4A3F38),
    cross: Color(0xFF7A6142),
    gridThin: Color(0xFFBF9F6E),
    gridBold: Color(0xFF2B2420),
    accent: Color(0xFFE38B2C),
    accentInk: Color(0xFF2B1A0C),
    mistake: Color(0xFFC0392B),
    flash: Color(0xFFFFF1B8),
    tape: Color(0xDDF2EBDD),
    tapeStripe: Color(0x55C9A673),
    panel: Color(0xFFE6CC9F),
    panelBorder: Color(0xFF2B2420),
    panelText: Color(0xFF2B2420),
    panelSubtle: Color(0xFF6B553C),
    deskText: Color(0xFFF2E2C4),
    night: false,
  );

  static const washi = PaperPalette(
    deskTop: Color(0xFFE6D7B4),
    deskBottom: Color(0xFFCDB98E),
    grain: Color(0xFFB59E70),
    paper: Color(0xFFFBEDEA),
    paperShade: Color(0xFFF0D9D4),
    clueBand: Color(0xFFF6E0DC),
    clueHighlight: Color(0xFFEDCAC4),
    clueText: Color(0xFF5B2346),
    clueDone: Color(0x665B2346),
    ink: Color(0xFF5B2346),
    inkHighlight: Color(0xFF7E3A64),
    cross: Color(0xFFA27F8C),
    gridThin: Color(0xFFE6C7C2),
    gridBold: Color(0xFF5B2346),
    accent: Color(0xFFE0688A),
    accentInk: Color(0xFFFFF7F8),
    mistake: Color(0xFFD23C3C),
    flash: Color(0xFFFFE08A),
    tape: Color(0xCCF6B9C6),
    tapeStripe: Color(0x88FFFFFF),
    panel: Color(0xFFFBEDEA),
    panelBorder: Color(0xFF5B2346),
    panelText: Color(0xFF5B2346),
    panelSubtle: Color(0xFF8C6676),
    deskText: Color(0xFF5A4526),
    night: false,
  );

  static const midnight = PaperPalette(
    deskTop: Color(0xFF151A30),
    deskBottom: Color(0xFF0B0E1C),
    grain: Color(0xFF1F2742),
    paper: Color(0xFF1F2A48),
    paperShade: Color(0xFF18213A),
    clueBand: Color(0xFF26335A),
    clueHighlight: Color(0xFF32426F),
    clueText: Color(0xFFEDE3C6),
    clueDone: Color(0x66EDE3C6),
    ink: Color(0xFFE8C66A),
    inkHighlight: Color(0xFFF7E3A1),
    cross: Color(0xFF7D8BB3),
    gridThin: Color(0xFF34436E),
    gridBold: Color(0xFFE8C66A),
    accent: Color(0xFF7FB7FF),
    accentInk: Color(0xFF0E1426),
    mistake: Color(0xFFFF6B6B),
    flash: Color(0xFFFFF4C2),
    tape: Color(0xAA7FB7FF),
    tapeStripe: Color(0x44FFFFFF),
    panel: Color(0xFF1F2A48),
    panelBorder: Color(0xFFE8C66A),
    panelText: Color(0xFFEDE3C6),
    panelSubtle: Color(0xFF9AA6C8),
    deskText: Color(0xFFB9C3E0),
    night: true,
  );
}

/// Colors a solved picture blooms into, chosen per level.
class PicturePalette {
  const PicturePalette(this.colors, this.background);

  /// Top-to-bottom gradient stops for filled cells.
  final List<Color> colors;

  /// Soft tint for empty cells of the revealed picture.
  final Color background;

  static const _named = <int, PicturePalette>{
    // Heart, Arrow, House.
    1: PicturePalette([
      Color(0xFFFF7A8A),
      Color(0xFFE8405A),
      Color(0xFFB8233F),
    ], Color(0xFFFFEFF0)),
    2: PicturePalette([
      Color(0xFF7FD3F7),
      Color(0xFF3E9BE0),
      Color(0xFF2A62B8),
    ], Color(0xFFEFF8FF)),
    3: PicturePalette([
      Color(0xFFE2563F),
      Color(0xFFF2B35A),
      Color(0xFF8C5A3C),
    ], Color(0xFFEAF6E4)),
  };

  static const _cycle = <PicturePalette>[
    PicturePalette([
      Color(0xFFFFB35C),
      Color(0xFFF2675A),
      Color(0xFF9C3D7A),
    ], Color(0xFFFFF3E6)), // sunset
    PicturePalette([
      Color(0xFF9BD771),
      Color(0xFF4FA36A),
      Color(0xFF2E6B57),
    ], Color(0xFFF1F8E8)), // forest
    PicturePalette([
      Color(0xFF8FE3E0),
      Color(0xFF3FA7C9),
      Color(0xFF2B5C9E),
    ], Color(0xFFEAF7F8)), // lagoon
    PicturePalette([
      Color(0xFFE6A1F0),
      Color(0xFFB164D6),
      Color(0xFF5D3A9B),
    ], Color(0xFFF7EEFB)), // berry
    PicturePalette([
      Color(0xFFFFE07A),
      Color(0xFFF5A742),
      Color(0xFFD9603B),
    ], Color(0xFFFFF8E2)), // marigold
    PicturePalette([
      Color(0xFFFFA9B8),
      Color(0xFFF07090),
      Color(0xFF6C4BA8),
    ], Color(0xFFFFF0F3)), // blossom
    PicturePalette([
      Color(0xFFB7E3A1),
      Color(0xFF6CC3B5),
      Color(0xFF3C7FA8),
    ], Color(0xFFEFF9F3)), // meadow
    PicturePalette([
      Color(0xFFF7C59F),
      Color(0xFFC97B63),
      Color(0xFF5E4B6E),
    ], Color(0xFFFBF1EA)), // clay
  ];

  static PicturePalette forLevel(int level) =>
      _named[level] ?? _cycle[(level * 5 + 3) % _cycle.length];

  /// Color of the filled cell ([row], [col]) on an [n] x [n] picture.
  Color cellColor(int row, int col, int n) {
    final t = n <= 1 ? 0.0 : (row + col * 0.35) / ((n - 1) * 1.35);
    final scaled = t.clamp(0.0, 1.0) * (colors.length - 1);
    final i = scaled.floor().clamp(0, colors.length - 2);
    final base = Color.lerp(colors[i], colors[i + 1], scaled - i)!;
    // A little per-cell variation so the picture looks hand coloured.
    final h = ((row * 73856093) ^ (col * 19349663)) & 0xFF;
    final shift = (h / 255 - 0.5) * 0.12;
    return shift >= 0
        ? Color.lerp(base, const Color(0xFFFFFFFF), shift)!
        : Color.lerp(base, const Color(0xFF000000), -shift)!;
  }
}
