// انتخاب‌گر تاریخ شمسی (تقویم ماهانه) — سبک و سریع.
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/fa.dart';

/// تاریخ شمسی را از کاربر می‌گیرد؛ خروجی DateTime (تاریخ، بدون تغییر ساعت).
Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
  String title = 'انتخاب تاریخ',
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: _JalaliCalendar(
        initial: initial,
        first: first ?? DateTime(2015),
        last: last ?? DateTime.now().add(const Duration(days: 366)),
        title: title,
      ),
    ),
  );
}

/// بازهٔ تاریخ (شروع و پایان شامل).
Future<DateTimeRange?> showJalaliRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
}) async {
  final now = DateTime.now();
  final start = await showJalaliDatePicker(
    context,
    initial: initial?.start ?? startOfJMonth(now),
    title: 'از تاریخ',
  );
  if (start == null || !context.mounted) return null;
  final end = await showJalaliDatePicker(
    context,
    initial: initial?.end ?? now,
    first: start,
    title: 'تا تاریخ',
  );
  if (end == null) return null;
  return DateTimeRange(start: start, end: end);
}

class _JalaliCalendar extends StatefulWidget {
  const _JalaliCalendar({required this.initial, required this.first, required this.last, required this.title});
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_JalaliCalendar> createState() => _JalaliCalendarState();
}

class _JalaliCalendarState extends State<_JalaliCalendar> {
  late Jalali _selected;
  late Jalali _month; // روز اول ماه نمایش‌داده‌شده
  bool _yearMode = false;

  @override
  void initState() {
    super.initState();
    _selected = Jalali.fromDateTime(widget.initial);
    _month = Jalali(_selected.year, _selected.month, 1);
  }

  static bool _same(Jalali a, Jalali b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(Jalali d) {
    final dt = d.toDateTime();
    final f = DateTime(widget.first.year, widget.first.month, widget.first.day);
    final l = DateTime(widget.last.year, widget.last.month, widget.last.day);
    return !dt.isBefore(f) && !dt.isAfter(l);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = Jalali.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '${jWeekdays[_selected.weekDay - 1]}، ${faDigits(_selected.day)} ${jMonths[_selected.month - 1]} ${faDigits(_selected.year)}',
                      style: text.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'امروز',
                onPressed: _inRange(today)
                    ? () => setState(() {
                          _selected = today;
                          _month = Jalali(today.year, today.month, 1);
                          _yearMode = false;
                        })
                    : null,
                icon: const Icon(Icons.today_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _month = _month.addMonths(-1)),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() => _yearMode = !_yearMode),
                  icon: Icon(_yearMode ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: Text('${jMonths[_month.month - 1]} ${faDigits(_month.year)}'),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _month = _month.addMonths(1)),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _yearMode ? _yearGrid(context) : _dayGrid(context, today),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () {
                  final d = _selected.toDateTime();
                  Navigator.pop(context, DateTime(d.year, d.month, d.day, widget.initial.hour, widget.initial.minute));
                },
                child: const Text('تأیید'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayGrid(BuildContext context, Jalali today) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final first = Jalali(_month.year, _month.month, 1);
    final offset = first.weekDay - 1; // شنبه = 0
    final days = first.monthLength;
    final cells = <Widget>[];
    for (var i = 0; i < 7; i++) {
      cells.add(Center(
        child: Text(jWeekdaysShort[i], style: text.labelMedium?.copyWith(color: i == 6 ? scheme.error : scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
      ));
    }
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= days; d++) {
      final j = Jalali(_month.year, _month.month, d);
      final selected = _same(j, _selected);
      final isToday = _same(j, today);
      final enabled = _inRange(j);
      final friday = j.weekDay == 7;
      cells.add(Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday && !selected ? BorderSide(color: scheme.primary, width: 1.4) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => setState(() => _selected = j) : null,
            child: Center(
              child: Text(
                faDigits(d),
                style: text.bodyMedium?.copyWith(
                  fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? scheme.onPrimary
                      : !enabled
                          ? scheme.onSurface.withValues(alpha: 0.3)
                          : friday
                              ? scheme.error
                              : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: cells,
    );
  }

  Widget _yearGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fy = Jalali.fromDateTime(widget.first).year;
    final ly = Jalali.fromDateTime(widget.last).year;
    final years = [for (var y = fy; y <= ly; y++) y];
    return SizedBox(
      height: 260,
      child: GridView.count(
        crossAxisCount: 4,
        childAspectRatio: 1.7,
        children: [
          for (final y in years)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: y == _month.year ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _month = Jalali(y, _month.month, 1);
                    _yearMode = false;
                  }),
                  child: Center(child: Text(faDigits(y), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// انتخاب تاریخ و ساعت پشت سر هم.
Future<DateTime?> showJalaliDateTimePicker(BuildContext context, {required DateTime initial}) async {
  final d = await showJalaliDatePicker(context, initial: initial, title: 'تاریخ پرداخت');
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: 'ساعت پرداخت',
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return DateTime(d.year, d.month, d.day, initial.hour, initial.minute);
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
