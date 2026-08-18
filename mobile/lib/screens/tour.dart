/// First-launch tour.
///
/// It exists for one reason: TrueBurn's central idea is not visible from the UI. Every
/// other tracker asks you to declare an activity level and then shows you a number from
/// a population formula. This one *measures* your expenditure from your own weight and
/// intake — and if nobody says so, the app looks like a plainer version of what people
/// already have.
///
/// Four pages, and it earns each one:
///   1. what makes the number different
///   2. what you actually have to do
///   3. why it says "Estimated" for the first three weeks — the single most likely
///      source of "is this broken?" in week one
///   4. reminders, including the part people do not expect (Done from the lock screen)
///
/// Skip is on every page and is a real control, not a greyed-out afterthought. Anyone
/// who wants to get on with it should be one tap from the app. Deliberately not a
/// carousel of feature screenshots: §6 rule 4's spirit is that this app does not sell
/// itself back to the user.
library;

import 'package:flutter/material.dart';

import '../splash.dart';
import '../theme.dart';
import '../widgets/primitives.dart';

class TourPage {
  final String eyebrow;
  final String title;
  final String body;

  /// Drawn, never a screenshot — a screenshot goes stale the moment the UI moves, and
  /// these have to explain an idea rather than show a layout.
  final Widget Function(Palette c) art;

  const TourPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.art,
  });
}

final tourPages = <TourPage>[
  const TourPage(
    eyebrow: 'WHY THIS ONE',
    title: 'Your burn, measured.\nNot guessed.',
    body:
        'Every other tracker asks how active you are and feeds a population formula '
        'that is 10–15% off for any given person. TrueBurn works backwards from what '
        'actually happened to you: what you ate, and what the scale did.',
    art: _equationArt,
  ),
  const TourPage(
    eyebrow: 'WHAT YOU DO',
    title: 'Three things,\nroughly.',
    body:
        'Weigh yourself most mornings. Log food approximately — a rough number you '
        'record every day beats an exact one you abandon. Tap water as you drink it. '
        'Consistency is what the maths needs, not precision.',
    art: _logArt,
  ),
  const TourPage(
    eyebrow: 'THE FIRST THREE WEEKS',
    title: 'It says Estimated\nuntil it can do better.',
    body:
        'At the start there is nothing to measure, so TrueBurn uses a formula and '
        'says so. As your weigh-ins accumulate it blends in the real measurement and '
        'takes over completely. The label always tells you which you are looking at.',
    art: _confidenceArt,
  ),
  const TourPage(
    eyebrow: 'STAYING WITH IT',
    title: 'Reminders you can\nanswer from the lock screen.',
    body:
        'Set routines for water, meals or the gym. When one arrives you can mark it '
        'done without opening the app — the tick still lands, and water still counts '
        'towards your day.',
    art: _reminderArt,
  ),
];

// ------------------------------------------------------------------------ art

Widget _equationArt(Palette c) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    LogoMark(size: 64, color: c.accent),
    const SizedBox(height: 26),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('what you ate  −  what you lost', style: sans(c, size: 12.5, color: c.ink2)),
          const SizedBox(height: 7),
          Container(height: 1, width: 190, color: c.line),
          const SizedBox(height: 7),
          Num('your real daily burn', size: 12.5, color: c.accent),
        ],
      ),
    ),
  ],
);

Widget _logArt(Palette c) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (final t in const [
      (Icons.monitor_weight_outlined, 'weight'),
      (Icons.restaurant_outlined, 'food'),
      (Icons.water_drop_outlined, 'water'),
    ]) ...[
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(t.$1, size: 27, color: c.accent),
          ),
          const SizedBox(height: 9),
          Text(t.$2.toUpperCase(), style: labelStyle(c)),
        ],
      ),
      if (t.$2 != 'water') const SizedBox(width: 16),
    ],
  ],
);

/// The three modes as a filling bar — the same idea the Today chip reports, so the tour
/// is teaching the actual UI rather than a metaphor for it.
Widget _confidenceArt(Palette c) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final step in const [
            ('Estimated', 0.0),
            ('Part measured', 0.55),
            ('Measured', 1.0),
          ]) ...[
            Expanded(
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: step.$2 == 0
                      ? c.sunken
                      : c.accent.withValues(alpha: 0.22 + 0.78 * step.$2),
                  borderRadius: BorderRadius.circular(9),
                  border: step.$2 == 0 ? Border.all(color: c.line) : null,
                ),
                child: Text(
                  step.$1,
                  style: sans(
                    c,
                    size: 10.5,
                    color: step.$2 > 0.5 ? c.onAccent : c.ink2,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (step.$2 != 1.0) const SizedBox(width: 6),
          ],
        ],
      ),
    ),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('day 1', style: mono(c, size: 10, color: c.ink3)),
        Text('about week 3', style: mono(c, size: 10, color: c.ink3)),
      ],
    ),
  ],
);

Widget _reminderArt(Palette c) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: c.line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          LogoMark(size: 17, color: c.accent),
          const SizedBox(width: 8),
          Text('TrueBurn', style: sans(c, size: 11.5, color: c.ink3)),
          const Spacer(),
          Text('now', style: sans(c, size: 11.5, color: c.ink3)),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Drink water',
        style: sans(c, size: 14, color: c.ink, weight: FontWeight.w700),
      ),
      Text('Time for a glass.', style: sans(c, size: 12.5, color: c.ink2)),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final a in const ['Done', 'In 30 min', 'Skip']) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: a == 'Done' ? c.accent : c.sunken,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                a,
                style: sans(
                  c,
                  size: 11.5,
                  color: a == 'Done' ? c.onAccent : c.ink2,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            if (a != 'Skip') const SizedBox(width: 7),
          ],
        ],
      ),
    ],
  ),
);

// ----------------------------------------------------------------------- tour

class TourScreen extends StatefulWidget {
  final VoidCallback onDone;
  const TourScreen({super.key, required this.onDone});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _isLast => _page == tourPages.length - 1;

  void _next() {
    if (_isLast) return widget.onDone();
    _pager.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip sits top-right on every page, full contrast. A tour you cannot leave
            // is a wall, and the people most likely to want out are the ones who already
            // know what they are doing.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
                child: TextButton(
                  onPressed: widget.onDone,
                  style: TextButton.styleFrom(
                    foregroundColor: c.ink2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: Text(
                    'Skip',
                    style: sans(c, size: 13.5, color: c.ink2, weight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: tourPages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _Page(tourPages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < tourPages.length; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? c.accent : c.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (i != tourPages.length - 1) const SizedBox(width: 5),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(_isLast ? 'Start tracking' : 'Next', onTap: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final TourPage page;
  const _Page(this.page);

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Centred when there is room, scrollable when there is not — a fixed top alignment
    // left a hand's width of dead space under the text on a tall phone, and a plain
    // Center would overflow on a short one at large text sizes.
    return LayoutBuilder(
      builder: (ctx, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The art gets a fixed block so the headline lands at the same height on
              // every page — otherwise paging reads as the text jumping around.
              SizedBox(height: 200, child: Center(child: page.art(c))),
              const SizedBox(height: 30),
              Text(page.eyebrow, style: labelStyle(c).copyWith(color: c.accent)),
              const SizedBox(height: 10),
              Text(
                page.title,
                style: TextStyle(
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                page.body,
                style: sans(c, size: 14.5, color: c.ink2).copyWith(height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
