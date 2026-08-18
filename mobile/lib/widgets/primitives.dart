/// Shared UI primitives. Deliberately small and flat — this app is scanned and
/// operated, not read, so the craft goes into information density rather than chrome.
library;

import 'package:flutter/material.dart';
import '../theme.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: borderColor ?? c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  final Color? color;
  const Label(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Text(text.toUpperCase(),
        style: labelStyle(c).copyWith(color: color ?? c.ink3));
  }
}

class Num extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;
  const Num(this.text,
      {super.key, this.size = 13, this.color, this.weight = FontWeight.w500});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Small figures read as instrument output and stay mono; large ones switch to the
    // sans face, where Android's monospace would look clumsy rather than precise.
    return Text(
      text,
      style: size >= 18
          ? display(c, size: size, color: color)
          : mono(c, size: size, color: color, weight: weight),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? tone;
  final bool monoFont;

  /// Spoken label. Required in spirit for symbol-only buttons — "−", "+", "×" announce
  /// as punctuation or as nothing at all otherwise.
  final String? semanticLabel;
  const Pill(this.label,
      {super.key, this.onTap, this.tone, this.monoFont = false, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final col = tone ?? c.ink;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: tone ?? c.line),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: monoFont
                ? mono(c, size: 12, color: col)
                : TextStyle(fontSize: 13, color: col, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  const PrimaryButton(this.label, {super.key, this.onTap, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: ghost ? c.surface : (onTap == null ? c.line : c.accent),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: ghost
              ? BoxDecoration(
                  border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12))
              : null,
          child: Text(label,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: ghost ? c.ink : c.onAccent)),
        ),
      ),
    );
  }
}

/// Same geometry as [PrimaryButton] so a Cancel/Save pair matches in height and
/// corner radius. Pairing a pill with a rounded rectangle looked like an accident.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const SecondaryButton(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(12)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
        ),
      ),
    );
  }
}

class StateChip extends StatelessWidget {
  final String label;
  final bool measured;
  const StateChip(this.label, {super.key, required this.measured});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final fg = measured ? c.accent : c.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: measured ? c.accentSoft : c.warnSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class Meter extends StatelessWidget {
  final double pct;
  final bool over;
  final bool thin;
  final double? markAt;
  const Meter(this.pct, {super.key, this.over = false, this.thin = false, this.markAt});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final h = thin ? 4.0 : 5.0;
    return LayoutBuilder(builder: (_, box) {
      return SizedBox(
        height: h,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration:
                BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(3)),
          ),
          // Eased rather than snapped: a bar that jumps on every tap reads as a
          // redraw, one that moves reads as a change.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (pct.clamp(0, 100)) / 100),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                    color: over ? c.warn : c.accent,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          if (markAt != null)
            Positioned(
              left: box.maxWidth * (markAt!.clamp(0, 100) / 100),
              top: -2,
              bottom: -2,
              child: Container(width: 2, color: c.ink.withValues(alpha: 0.45)),
            ),
        ]),
      );
    });
  }
}

class Notice extends StatelessWidget {
  final String text;
  final String tone; // plain | warn | accent
  const Notice(this.text, {super.key, this.tone = 'plain'});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final bg = tone == 'warn' ? c.warnSoft : (tone == 'accent' ? c.accentSoft : c.sunken);
    final fg = tone == 'warn' ? c.warn : (tone == 'accent' ? c.accent : c.ink2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: fg, height: 1.45)),
    );
  }
}

class SegControl<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;
  const SegControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Row(
      children: options.map((o) {
        final on = o.$1 == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: o == options.last ? 0 : (compact ? 5 : 6)),
            child: Material(
              color: on ? c.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
              child: InkWell(
                onTap: () => onChanged(o.$1),
                borderRadius: BorderRadius.circular(compact ? 8 : 10),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: compact ? 6 : 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: on ? c.accent : c.line),
                    borderRadius: BorderRadius.circular(compact ? 8 : 10),
                  ),
                  child: Text(o.$2,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: on ? c.accent : c.ink2,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bottom sheet with the app's own chrome rather than Material's default.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder,
    {WidgetBuilder? footer}) {
  final c = AppTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => AppTheme(
      c: c,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.line, borderRadius: BorderRadius.circular(2))),
              Flexible(child: SingleChildScrollView(child: builder(ctx))),
              // Pinned: "Add your own food" sat below seventy list items, so reaching it
              // meant scrolling the entire catalogue.
              if (footer != null)
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: footer(ctx),
                ),
            ]),
          ),
        ),
      ),
    ),
  );
}
