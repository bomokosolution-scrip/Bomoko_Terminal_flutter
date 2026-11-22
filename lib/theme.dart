import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

import 'data.dart';

class Pal {
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF2DD4FF);
  static const amber = Color(0xFFFFB020);
  static const mint = Color(0xFF34D399);
  static const rose = Color(0xFFFF5C7A);
  static const aurora = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Pairs used for host avatars and menu tiles.
const List<List<Color>> kGrads = [
  [Color(0xFF7C5CFF), Color(0xFF2DD4FF)], // 0 aurore
  [Color(0xFFFF5C7A), Color(0xFFFFB020)], // 1 braise
  [Color(0xFF34D399), Color(0xFF2DD4FF)], // 2 lagon
  [Color(0xFF4F6BFF), Color(0xFFB05CFF)], // 3 indigo
  [Color(0xFFFFB020), Color(0xFFFF6B4A)], // 4 ambre
  [Color(0xFF14B8A6), Color(0xFF84CC16)], // 5 jungle
  [Color(0xFFEC4899), Color(0xFF8B5CF6)], // 6 orchidée
  [Color(0xFF38BDF8), Color(0xFF6366F1)], // 7 ciel
];

class C {
  final Color bg, surface, surface2, text, muted, line;
  const C({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.line,
  });

  static const dark = C(
    bg: Color(0xFF0B1020),
    surface: Color(0xFF131A2E),
    surface2: Color(0xFF1B2440),
    text: Color(0xFFE8ECF8),
    muted: Color(0xFF8B95B5),
    line: Color(0x1FFFFFFF),
  );
  static const light = C(
    bg: Color(0xFFF3F5FC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE9EDFA),
    text: Color(0xFF141A33),
    muted: Color(0xFF6A7394),
    line: Color(0x1A141A33),
  );

  static const graphite = C(
    bg: Color(0xFF121214),
    surface: Color(0xFF1C1C20),
    surface2: Color(0xFF28282E),
    text: Color(0xFFF2F2F5),
    muted: Color(0xFF9A9AA5),
    line: Color(0x1FFFFFFF),
  );
  static const amoled = C(
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E11),
    surface2: Color(0xFF1B1B20),
    text: Color(0xFFF4F4F8),
    muted: Color(0xFF8E8E9A),
    line: Color(0x22FFFFFF),
  );
  static const List<C> darkVariants = [dark, graphite, amoled];

  static C of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? darkVariants[data.darkVariant.clamp(0, 2).toInt()]
      : light;
}

ThemeData buildTheme(Brightness b, C c) {
  final base = ThemeData(brightness: b, useMaterial3: true);
  final text = GoogleFonts.soraTextTheme(base.textTheme)
      .apply(bodyColor: c.text, displayColor: c.text);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: Pal.violet, brightness: b)
        .copyWith(primary: Pal.violet, surface: c.surface),
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.text,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    }),
  );
}

final ThemeData lightTheme = buildTheme(Brightness.light, C.light);
final List<ThemeData> darkThemes = [
  for (final v in C.darkVariants) buildTheme(Brightness.dark, v),
];

// ---------------------------------------------------------------- terminal

class TermPalette {
  final String name;
  final TerminalTheme theme;
  const TermPalette(this.name, this.theme);
}

TerminalTheme _term(int bg, int fg, int cursor, List<int> a, List<int> b) =>
    TerminalTheme(
      cursor: Color(cursor),
      selection: Color(cursor).withOpacity(0.30),
      foreground: Color(fg),
      background: Color(bg),
      black: Color(a[0]),
      red: Color(a[1]),
      green: Color(a[2]),
      yellow: Color(a[3]),
      blue: Color(a[4]),
      magenta: Color(a[5]),
      cyan: Color(a[6]),
      white: Color(a[7]),
      brightBlack: Color(b[0]),
      brightRed: Color(b[1]),
      brightGreen: Color(b[2]),
      brightYellow: Color(b[3]),
      brightBlue: Color(b[4]),
      brightMagenta: Color(b[5]),
      brightCyan: Color(b[6]),
      brightWhite: Color(b[7]),
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: const Color(0xFF000000),
    );

final List<TermPalette> termPalettes = [
  TermPalette(
    'Aurore',
    _term(
      0xFF0B1020, 0xFFE8ECF8, 0xFFFFB020,
      [0xFF1B2440, 0xFFFF5C7A, 0xFF34D399, 0xFFFFB020, 0xFF7C9CFF, 0xFFB07CFF, 0xFF2DD4FF, 0xFFC9D1EE],
      [0xFF4A5578, 0xFFFF8FA3, 0xFF6EE7B7, 0xFFFFD166, 0xFFA5BBFF, 0xFFD0A8FF, 0xFF7DE3FF, 0xFFFFFFFF],
    ),
  ),
  TermPalette(
    'Océan',
    _term(
      0xFF06222B, 0xFFD6EEF2, 0xFF5EEAD4,
      [0xFF0F3A47, 0xFFFF7A90, 0xFF4ADE80, 0xFFFACC15, 0xFF60A5FA, 0xFFC084FC, 0xFF22D3EE, 0xFFCBE4EA],
      [0xFF3E6B78, 0xFFFFA3B3, 0xFF86EFAC, 0xFFFDE68A, 0xFF93C5FD, 0xFFD8B4FE, 0xFF67E8F9, 0xFFFFFFFF],
    ),
  ),
  TermPalette(
    'Braise',
    _term(
      0xFF1A1210, 0xFFF2E6DC, 0xFFFF8A3D,
      [0xFF2C1F1B, 0xFFFF6B6B, 0xFFA3E635, 0xFFFFB84D, 0xFF7AA2F7, 0xFFE879F9, 0xFF5EEAD4, 0xFFE8D8CB],
      [0xFF6B5148, 0xFFFF9A9A, 0xFFBEF264, 0xFFFFD58A, 0xFFA5C0FA, 0xFFF0ABFC, 0xFF99F6E4, 0xFFFFFFFF],
    ),
  ),
  TermPalette(
    'Papier',
    _term(
      0xFFF7F8FC, 0xFF1C2340, 0xFF6C4BFF,
      [0xFF1C2340, 0xFFD6254D, 0xFF12805C, 0xFFB7791F, 0xFF3B5BDB, 0xFF8E3FD1, 0xFF0A7EA4, 0xFF9AA3C2],
      [0xFF5C6585, 0xFFEF5A7A, 0xFF22A878, 0xFFD99A2B, 0xFF5C7CFA, 0xFFA95CE8, 0xFF1CA3CF, 0xFFE4E8F6],
    ),
  ),
  TermPalette(
    'Nocturne',
    _term(
      0xFF1E1B2E, 0xFFE6E1F5, 0xFFC792EA,
      [0xFF2B2640, 0xFFFF6E8A, 0xFF8CE99A, 0xFFFFD866, 0xFF82AAFF, 0xFFC792EA, 0xFF89DDFF, 0xFFD9D4EC],
      [0xFF5B5580, 0xFFFF9DB0, 0xFFB5F5BE, 0xFFFFE699, 0xFFA8C4FF, 0xFFDDB6F5, 0xFFB4EBFF, 0xFFFFFFFF],
    ),
  ),
  TermPalette(
    'Forêt',
    _term(
      0xFF0F1A14, 0xFFD8EBDD, 0xFFA3E635,
      [0xFF1B2B22, 0xFFF07178, 0xFF7FD962, 0xFFE5C95B, 0xFF6CB6FF, 0xFFC49BFF, 0xFF4FD6BE, 0xFFC9DDCF],
      [0xFF47624F, 0xFFFF9BA0, 0xFFA5EE8B, 0xFFF2DE8A, 0xFF9BCDFF, 0xFFD8BEFF, 0xFF85E8D3, 0xFFFFFFFF],
    ),
  ),
  TermPalette(
    'Phosphore',
    _term(
      0xFF050805, 0xFF33FF66, 0xFF33FF66,
      [0xFF0B140B, 0xFFFF5555, 0xFF33FF66, 0xFFD7E04A, 0xFF4D9DFF, 0xFFD070FF, 0xFF3FE0D0, 0xFF9FE8B0],
      [0xFF2B5A35, 0xFFFF8888, 0xFF7DFF9B, 0xFFF0F58A, 0xFF86BDFF, 0xFFE2A2FF, 0xFF86F0E4, 0xFFE8FFEE],
    ),
  ),
  TermPalette(
    'Brume',
    _term(
      0xFFEEF1F7, 0xFF222B45, 0xFF0A7EA4,
      [0xFF222B45, 0xFFC62D4A, 0xFF1A8754, 0xFFA8741A, 0xFF2F5DD1, 0xFF8A3FC4, 0xFF0B7E9E, 0xFF8C96B3],
      [0xFF59627F, 0xFFE0506B, 0xFF28A86A, 0xFFC48D2A, 0xFF4D7CF0, 0xFFA65BE0, 0xFF18A0C4, 0xFFDDE2EF],
    ),
  ),
];
