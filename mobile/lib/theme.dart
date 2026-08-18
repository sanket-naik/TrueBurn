/// The palette from design/prototype.html.
///
/// Neutrals are biased green so they read as chosen rather than inherited, and tie to
/// the accent. One accent — a deep chart-ink teal — reserved for *measured* state. Amber
/// is semantic only: the estimating state and the safety floor, never decoration.
///
/// Every number renders mono, every word sans: instruments label in sans and read out
/// in mono.
library;

import 'package:flutter/material.dart';

/// `ink3` carries most of the hint and label text, so it has to clear WCAG AA for body
/// copy (4.5:1) — not just the 3:1 large-text floor. The original #8B9A94 measured
/// 2.94:1 on white, failing even that. Verified with a contrast script rather than by
/// eye, because low-contrast grey is exactly the failure a designer stops seeing.
class Palette {
  final Color ground, surface, sunken, ink, ink2, ink3, line, accent, accentSoft;
  final Color warn, warnSoft, onAccent;
  const Palette({
    required this.ground,
    required this.surface,
    required this.sunken,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.warn,
    required this.warnSoft,
    required this.onAccent,
  });
}

const lightPalette = Palette(
  ground: Color(0xFFF6F8F7),
  surface: Color(0xFFFFFFFF),
  sunken: Color(0xFFF0F3F2),
  ink: Color(0xFF141C1A),
  ink2: Color(0xFF5C6B66),
  ink3: Color(0xFF697872),
  line: Color(0xFFE1E7E4),
  accent: Color(0xFF0E6B5B),
  accentSoft: Color(0xFFE4F0EC),
  warn: Color(0xFF9A5B0C),
  warnSoft: Color(0xFFF7EFE1),
  onAccent: Color(0xFFFFFFFF),
);

const darkPalette = Palette(
  ground: Color(0xFF0E1513),
  surface: Color(0xFF151E1B),
  sunken: Color(0xFF111917),
  ink: Color(0xFFE9EFEC),
  ink2: Color(0xFF9DACA7),
  ink3: Color(0xFF7A8984),
  line: Color(0xFF24302C),
  accent: Color(0xFF46C0A4),
  accentSoft: Color(0xFF17322B),
  warn: Color(0xFFD69A4E),
  warnSoft: Color(0xFF2C2317),
  onAccent: Color(0xFF08110F),
);

/// Platform mono face. Android ships `monospace`; falling back explicitly beats a
/// silent substitution that changes column alignment.
const monoFamily = 'monospace';

class AppTheme extends InheritedWidget {
  final Palette c;
  const AppTheme({super.key, required this.c, required super.child});

  static Palette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTheme>()!.c;

  @override
  bool updateShouldNotify(AppTheme old) => old.c != c;
}

/// `ColorScheme.fromSeed` does real colour-space maths and was being re-run on every
/// store change — every water tap, every tick, for a result that never differed.
///
/// Keyed on the palette as well as the brightness. Brightness alone happens to be
/// sufficient today because there are exactly two const palettes, but a third accent
/// would then silently serve a stale theme, and a caching bug that only appears when
/// someone adds a colour is not worth the one word it costs to prevent.
final Map<(Palette, Brightness), ThemeData> _themeCache = {};

ThemeData buildTheme(Palette c, Brightness b) =>
    _themeCache[(c, b)] ??= _buildTheme(c, b);

ThemeData _buildTheme(Palette c, Brightness b) => ThemeData(
      brightness: b,
      scaffoldBackgroundColor: c.ground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: b,
      ).copyWith(surface: c.surface, primary: c.accent),
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      textTheme: Typography.material2021().black.apply(
            bodyColor: c.ink,
            displayColor: c.ink,
          ),
    );

/// Small data and labels stay mono — that is the instrument voice.
///
/// Tabular figures everywhere digits line up, and negative tracking because Android's
/// `monospace` (Droid Sans Mono) is noticeably wider and looser than the SF Mono the
/// prototype was designed against.
TextStyle mono(Palette c,
        {double size = 13, Color? color, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      color: color ?? c.ink,
      fontWeight: weight,
      letterSpacing: -0.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Large readouts use the *sans* face with tabular figures, not mono.
///
/// The prototype's big numbers were SF Mono, which is handsome at 44px. Android's
/// monospace is not — it goes wide and clunky and drags the whole screen down with it.
/// Sans with tabular figures keeps the columns aligned while actually looking designed.
TextStyle display(Palette c,
        {double size = 44, Color? color, FontWeight weight = FontWeight.w600}) =>
    TextStyle(
      fontSize: size,
      color: color ?? c.ink,
      fontWeight: weight,
      letterSpacing: size * -0.022,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle sans(Palette c, {double size = 13, Color? color, FontWeight? weight}) =>
    TextStyle(fontSize: size, color: color ?? c.ink2, fontWeight: weight, height: 1.5);

TextStyle labelStyle(Palette c) => TextStyle(
      fontFamily: monoFamily,
      fontSize: 9.5,
      letterSpacing: 1.1,
      color: c.ink3,
      fontWeight: FontWeight.w600,
    );

/// Card titles — one step up from body, clearly below a screen heading.
TextStyle cardTitle(Palette c) =>
    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink, letterSpacing: -0.1);

TextStyle screenTitle(Palette c) =>
    TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.6);
