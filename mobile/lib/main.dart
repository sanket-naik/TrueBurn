import 'package:flutter/material.dart';

import 'screens/routines.dart';
import 'screens/today.dart';
import 'screens/tour.dart';
import 'notifications.dart';
import 'splash.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Paint the splash immediately and do the slow work behind it, rather than awaiting
  // before runApp — that ordering leaves a blank frame on cold start.
  runApp(const TrueBurnApp());
}

class TrueBurnApp extends StatefulWidget {
  const TrueBurnApp({super.key});

  @override
  State<TrueBurnApp> createState() => _TrueBurnAppState();
}

class _TrueBurnAppState extends State<TrueBurnApp> {
  final Store store = Store();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    await Notifications.init();
    await store.hydrate();
    // Long enough to actually read the tagline. At 1100ms the text faded in and was
    // gone again inside a blink, which is worse than not showing it — but this still
    // never pads a slow boot, only a fast one.
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1900);
    if (elapsed < minimum) await Future.delayed(minimum - elapsed);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        // `auto` must keep *following* the device rather than reading it once — the OS
        // flips at dusk and the app has to flip with it.
        final device = MediaQuery.platformBrightnessOf(context);
        final isDark = switch (store.theme) {
          ThemeChoice.auto => device == Brightness.dark,
          ThemeChoice.dark => true,
          ThemeChoice.light => false,
        };
        final palette = isDark ? darkPalette : lightPalette;

        return MaterialApp(
          title: 'TrueBurn',
          debugShowCheckedModeBanner: false,
          // Android's default stretch overscroll warps the whole page at the ends,
          // which on a card layout reads as the UI breaking rather than as feedback.
          scrollBehavior: const _NoStretchScrollBehavior(),
          theme: buildTheme(palette, isDark ? Brightness.dark : Brightness.light),
          home: AppTheme(
            c: palette,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: !_ready
                  ? const SplashScreen()
                  // The tour sits between the splash and the app rather than over it:
                  // a modal on top of a screen the user cannot read yet explains
                  // nothing, and dismissing it would drop them somewhere unexplained.
                  : store.tourSeen
                      ? Shell(store)
                      : TourScreen(onDone: store.markTourSeen),
            ),
          ),
        );
      },
    );
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class Shell extends StatefulWidget {
  final Store store;
  const Shell(this.store, {super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The permission ask lives here rather than at boot, so it lands after the tour has
    // explained what reminders are — and, for anyone who has already seen the tour, on
    // the first frame of the app they actually recognise. Both platforms treat a denial
    // as near-permanent, so the question is only worth asking once it makes sense.
    WidgetsBinding.instance.addPostFrameCallback((_) => Notifications.requestPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after midnight has to roll yesterday's ticks over before anything is
    // drawn, or Today shows yesterday's completions as if they were today's.
    if (state == AppLifecycleState.resumed) {
      widget.store.rolloverDay();
      // A Done tapped on the lock screen was banked by a background isolate; this is
      // where it lands in state.
      widget.store.applyPendingTicks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        bottom: false,
        // Cross-fade rather than a hard swap; a tab change that blinks reads as a
        // reload rather than as navigation.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          child: _tab == 0
              ? TodayScreen(widget.store, key: const ValueKey('today'))
              : RoutinesScreen(widget.store, key: const ValueKey('routines')),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _tabButton(c, 0, Icons.today_outlined, 'Today'),
              _tabButton(c, 1, Icons.notifications_none, 'Routines'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(Palette c, int i, IconData icon, String label) => Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: _tab == i ? c.accent : c.ink3),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _tab == i ? c.accent : c.ink3)),
            ]),
          ),
        ),
      );
}
