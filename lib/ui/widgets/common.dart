// ویجت‌های مشترک.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// عنوان بخش با دکمهٔ اختیاری.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.padding});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// نشان طرف (شما / شرکا) با رنگ خودش.
class SideBadge extends StatelessWidget {
  const SideBadge(this.side, this.label, {super.key, this.compact = false});
  final Side side;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Palette.side(side);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: Palette.sideSoft(side, Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? Color.lerp(c, Colors.white, 0.45) : Color.lerp(c, Colors.black, 0.25),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// آیکون دسته در دایرهٔ رنگی.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.categoryKey, {super.key, this.size = 44, this.selected = false});
  final String categoryKey;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(categoryKey);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? c.color : c.color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(c.icon, size: size * 0.5, color: selected ? Colors.white : (dark ? Color.lerp(c.color, Colors.white, 0.35) : c.color)),
    );
  }
}

/// مبلغ با انیمیشن تغییر عدد.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(this.toman, {super.key, required this.unit, this.size = 30, this.color, this.withUnit = true, this.compact = false});
  final int toman;
  final MoneyUnit unit;
  final double size;
  final Color? color;
  final bool withUnit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: toman.toDouble(), end: toman.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        final text = compact ? fmtCompact(n, unit: unit) : fmtMoney(n, unit: unit, withUnit: false);
        return Text.rich(
          TextSpan(
            text: text,
            style: amountStyle(context, size: size, color: color),
            children: [
              if (withUnit && !compact)
                TextSpan(
                  text: ' ${unit.label}',
                  style: amountStyle(context, size: size * 0.5, color: (color ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.7), weight: FontWeight.w600),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// چیپ وضعیت همگام‌سازی.
class SyncChip extends StatelessWidget {
  const SyncChip(this.status, {super.key});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (status.state) {
      SyncState.online => (Palette.positive, Icons.cloud_done_outlined),
      SyncState.offline => (scheme.onSurfaceVariant, Icons.cloud_off_outlined),
      SyncState.pending => (Palette.amber, Icons.cloud_upload_outlined),
      SyncState.connecting => (scheme.onSurfaceVariant, Icons.sync),
      SyncState.demo => (scheme.tertiary, Icons.science_outlined),
    };
    final label = status.state == SyncState.pending
        ? '${status.label} (${faDigits(status.pendingCount)})'
        : status.label;
    return Tooltip(
      message: status.lastSynced == null ? label : 'آخرین همگام‌سازی: ${timeAgo(status.lastSynced!)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// حالت خالی.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(28)),
              alignment: Alignment.center,
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// کارت ساده با پدینگ یکنواخت.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// نوار درصدی دو رنگ (سهم طرف‌ها).
class DualBar extends StatelessWidget {
  const DualBar({super.key, required this.ratioA, this.height = 12, this.marker});
  final double ratioA;
  final double height;
  /// نشانگر سهم قراردادی (۰..۱).
  final double? marker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: height + 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(height),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: (w * ratioA.clamp(0, 1)).clamp(0, w).toDouble(),
                    height: height,
                    color: Palette.sideA,
                  ),
                  Expanded(child: Container(height: height, color: Palette.sideB)),
                ],
              ),
            ),
            if (marker != null)
              PositionedDirectional(
                start: w * marker!.clamp(0, 1) - 1.5,
                child: Container(
                  width: 3,
                  height: height + 10,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// کپی متن با بازخورد.
Future<void> copyWithToast(BuildContext context, String text, {String message = 'کپی شد'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}

void toast(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 3)));
}

/// تأیید حذف.
Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String okLabel = 'حذف', bool destructive = true}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// فرمت‌کنندهٔ ورودی مبلغ: ارقام فارسی با جداکنندهٔ هزارگان.
class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = enDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final n = int.tryParse(digits.length > 15 ? digits.substring(0, 15) : digits) ?? 0;
    final text = groupDigits(n);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
