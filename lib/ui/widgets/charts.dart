// نمودارهای سبک با CustomPaint (بدون وابستگی خارجی).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/stats.dart';

class DonutSlice {
  final String key;
  final String label;
  final int value;
  final Color color;
  const DonutSlice(this.key, this.label, this.value, this.color);
}

/// نمودار حلقه‌ای با انیمیشن و برچسب مرکزی.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 180,
    this.thickness = 22,
    this.centerTop,
    this.centerBottom,
    this.selectedKey,
    this.onSelect,
  });
  final List<DonutSlice> slices;
  final double size;
  final double thickness;
  final String? centerTop;
  final String? centerBottom;
  final String? selectedKey;
  final ValueChanged<String?>? onSelect;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();

  @override
  void didUpdateWidget(covariant DonutChart old) {
    super.didUpdateWidget(old);
    if (old.slices.length != widget.slices.length ||
        old.slices.fold<int>(0, (a, s) => a + s.value) != widget.slices.fold<int>(0, (a, s) => a + s.value)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final v = local - center;
    final r = v.distance;
    if (r < widget.size / 2 - widget.thickness - 6 || r > widget.size / 2 + 6) {
      widget.onSelect?.call(null);
      return;
    }
    var angle = math.atan2(v.dy, v.dx) + math.pi / 2; // از بالا
    if (angle < 0) angle += 2 * math.pi;
    final total = widget.slices.fold<int>(0, (a, s) => a + s.value);
    if (total == 0) return;
    var acc = 0.0;
    for (final s in widget.slices) {
      final sweep = s.value / total * 2 * math.pi;
      if (angle >= acc && angle < acc + sweep) {
        widget.onSelect?.call(widget.selectedKey == s.key ? null : s.key);
        return;
      }
      acc += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapUp: (d) => _tap(d.localPosition),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _DonutPainter(
              slices: widget.slices,
              progress: Curves.easeOutCubic.transform(_c.value),
              thickness: widget.thickness,
              track: scheme.surfaceContainerHighest,
              selectedKey: widget.selectedKey,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.centerTop != null)
                    Text(widget.centerTop!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                  if (widget.centerBottom != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        widget.centerBottom!,
                        style: amountStyle(context, size: 17),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.progress, required this.thickness, required this.track, this.selectedKey});
  final List<DonutSlice> slices;
  final double progress;
  final double thickness;
  final Color track;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - thickness / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = slices.fold<int>(0, (a, s) => a + s.value);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    if (total == 0) return;

    var start = -math.pi / 2;
    const gap = 0.035;
    for (final s in slices) {
      final sweep = s.value / total * 2 * math.pi * progress;
      if (sweep <= 0) continue;
      final selected = selectedKey == null || selectedKey == s.key;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = selectedKey == s.key ? thickness + 6 : thickness
        ..color = selected ? s.color : s.color.withValues(alpha: 0.25);
      final g = slices.length > 1 ? math.min(gap, sweep / 3) : 0.0;
      canvas.drawArc(rect, start + g / 2, math.max(sweep - g, 0.001), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.slices != slices || old.selectedKey != selectedKey || old.track != track;
}

/// نمودار ستونی ماهانه، هر ستون دو بخش (طرف الف/ب) روی هم.
class MonthBarChart extends StatefulWidget {
  const MonthBarChart({super.key, required this.buckets, required this.unit, this.height = 170, this.onTapMonth, this.selectedIndex});
  final List<MonthBucket> buckets;
  final MoneyUnit unit;
  final double height;
  final ValueChanged<int?>? onTapMonth;
  final int? selectedIndex;

  @override
  State<MonthBarChart> createState() => _MonthBarChartState();
}

class _MonthBarChartState extends State<MonthBarChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void didUpdateWidget(covariant MonthBarChart old) {
    super.didUpdateWidget(old);
    final a = old.buckets.fold<int>(0, (x, b) => x + b.total);
    final b = widget.buckets.fold<int>(0, (x, b) => x + b.total);
    if (a != b || old.buckets.length != widget.buckets.length) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxV = widget.buckets.fold<int>(0, (m, b) => math.max(m, b.total));
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, c) {
        final n = widget.buckets.length;
        final colW = c.maxWidth / n;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final p = Curves.easeOutCubic.transform(_c.value);
            return Row(
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: colW,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onTapMonth?.call(widget.selectedIndex == i ? null : i),
                      child: _Column(
                        bucket: widget.buckets[i],
                        maxV: maxV,
                        progress: p,
                        height: widget.height,
                        dim: widget.selectedIndex != null && widget.selectedIndex != i,
                        selected: widget.selectedIndex == i,
                        unit: widget.unit,
                        labelStyle: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        valueStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                        track: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.bucket,
    required this.maxV,
    required this.progress,
    required this.height,
    required this.dim,
    required this.selected,
    required this.unit,
    required this.labelStyle,
    required this.valueStyle,
    required this.track,
  });
  final MonthBucket bucket;
  final int maxV;
  final double progress;
  final double height;
  final bool dim;
  final bool selected;
  final MoneyUnit unit;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color track;

  @override
  Widget build(BuildContext context) {
    const labelH = 20.0, valueH = 18.0;
    final barArea = height - labelH - valueH - 6;
    final total = bucket.total;
    final frac = maxV == 0 ? 0.0 : total / maxV;
    final h = barArea * frac * progress;
    final hA = total == 0 ? 0.0 : h * bucket.a / total;
    final hB = h - hA;
    return Column(
      children: [
        SizedBox(
          height: valueH,
          child: total > 0 && (selected || maxV == total)
              ? FittedBox(fit: BoxFit.scaleDown, child: Text(fmtCompact(total, unit: unit), style: valueStyle))
              : null,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Opacity(
                opacity: dim ? 0.35 : 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (total == 0)
                        Container(height: 4, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(2)))
                      else ...[
                        Container(height: hB, color: Palette.sideB),
                        if (hA > 0 && hB > 0) const SizedBox(height: 2),
                        Container(height: hA, color: Palette.sideA),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(height: labelH, child: Text(bucket.label, style: labelStyle?.copyWith(fontWeight: selected ? FontWeight.w800 : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// راهنمای رنگ‌ها.
class Legend extends StatelessWidget {
  const Legend(this.items, {super.key});
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (c, l) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text(l, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}

/// نوار افقی سهم با برچسب (برای فهرست دسته‌ها در گزارش).
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.ratio, required this.color, this.height = 8});
  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              alignment: AlignmentDirectional.centerStart,
              child: Container(height: height, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// نشان مقدار کوچک با توضیح.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.color, this.caption});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: c), const SizedBox(width: 6)],
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: amountStyle(context, size: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) Text(caption!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// برچسب کوچک «جدید» برای شمارنده.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(999)),
      child: Text(faDigits(count), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onError, fontWeight: FontWeight.w800)),
    );
  }
}

/// نوار دو رنگ برای مقایسهٔ یک دسته بین دو طرف.
class SideSplitBar extends StatelessWidget {
  const SideSplitBar({super.key, required this.a, required this.b, this.height = 6});
  final int a;
  final int b;
  final double height;
  @override
  Widget build(BuildContext context) {
    final t = a + b;
    if (t == 0) return SizedBox(height: height);
    final fa = (a / t * 1000).round().clamp(0, 1000);
    final fb = 1000 - fa;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Row(
        children: [
          if (fa > 0) Expanded(flex: fa, child: Container(height: height, color: Palette.sideA)),
          if (fb > 0) Expanded(flex: fb, child: Container(height: height, color: Palette.sideB)),
        ],
      ),
    );
  }
}

/// نمای فهرست‌شده برای Side.
String sideLabel(Side s, {required String aName, required String bName}) => s == Side.a ? aName : bName;
