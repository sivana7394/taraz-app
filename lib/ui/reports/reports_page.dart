// گزارش‌ها: دسته‌ها، ماه‌ها، طرف‌ها + خروجی اکسل/PDF.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/export.dart';
import '../../data/models.dart';
import '../../data/stats.dart';
import '../entries/entries_page.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/jalali_picker.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.onOpenEntries});
  final void Function(EntriesFilter filter) onOpenEntries;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _tab = 0;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.stats;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش‌ها'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'خروجی',
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share),
            onSelected: (v) => v == 'csv' ? _exportCsv() : _exportPdf(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('صورت‌حساب PDF'))),
              PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('فایل اکسل (CSV)'))),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          _PeriodPicker(selected: s.period, onChanged: (p) => s.period = p),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatTile(label: 'جمع بازه', value: fmtCompact(st.total, unit: s.unit), icon: Icons.functions, caption: '${faDigits(st.count)} هزینه')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'میانگین هر هزینه', value: st.count == 0 ? '—' : fmtCompact(st.total ~/ st.count, unit: s.unit), icon: Icons.stacked_line_chart, color: Palette.amber)),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'بزرگ‌ترین هزینه', value: fmtCompact(st.maxEntry, unit: s.unit), icon: Icons.north_east, color: Palette.negative)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('دسته‌ها'), icon: Icon(Icons.pie_chart_outline, size: 18)),
                ButtonSegment(value: 1, label: Text('ماه‌ها'), icon: Icon(Icons.bar_chart, size: 18)),
                ButtonSegment(value: 2, label: Text('طرف‌ها'), icon: Icon(Icons.people_outline, size: 18)),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_tab) {
              0 => _CategoriesReport(key: const ValueKey(0), stats: st, onTapCategory: (k) => widget.onOpenEntries(EntriesFilter(categories: {k}, range: _rangeOf(st.period)))),
              1 => _MonthsReport(key: const ValueKey(1), stats: st, onTapMonth: (b) => widget.onOpenEntries(EntriesFilter(range: DateTimeRange(start: b.start, end: startOfJMonthOffset(b.start, 1).subtract(const Duration(days: 1)))))),
              _ => _SidesReport(key: const ValueKey(2), stats: st),
            },
          ),
          if (st.count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text('در این بازه هزینه‌ای ثبت نشده است.', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  DateTimeRange? _rangeOf(Period p) {
    if (p.start == null && p.end == null) return null;
    final start = p.start ?? DateTime(2015);
    final end = (p.end ?? DateTime.now().add(const Duration(days: 1))).subtract(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }

  List<Entry> _periodEntries(AppState s) => s.entries.where((e) => s.period.contains(e.paidAt)).toList();

  Future<void> _exportCsv() async {
    final s = context.read<AppState>();
    setState(() => _exporting = true);
    try {
      final ex = Exporter(config: s.config, unit: s.unit);
      final f = await ex.writeCsv(ex.csv(_periodEntries(s), settlements: s.settlements), 'taraz-${enDigits(fmtDateNumeric(DateTime.now())).replaceAll('/', '-')}');
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'text/csv')], text: 'هزینه‌های ${s.config.name} — ${s.period.label}'));
    } catch (e) {
      if (mounted) toast(context, 'خروجی ساخته نشد: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final s = context.read<AppState>();
    setState(() => _exporting = true);
    try {
      final ex = Exporter(config: s.config, unit: s.unit);
      final bytes = await ex.pdf(entries: _periodEntries(s), stats: s.stats, periodLabel: s.period.label);
      final f = await ex.writePdf(bytes, 'taraz-${enDigits(fmtDateNumeric(DateTime.now())).replaceAll('/', '-')}');
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/pdf')], text: 'صورت‌حساب ${s.config.name} — ${s.period.label}'));
    } catch (e) {
      if (mounted) toast(context, 'خروجی ساخته نشد: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.selected, required this.onChanged});
  final Period selected;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final presets = Period.presets();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in presets)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(p.label),
                selected: selected.key == p.key,
                onSelected: (_) => onChanged(p),
                selectedColor: scheme.primary,
                labelStyle: TextStyle(color: selected.key == p.key ? scheme.onPrimary : scheme.onSurface, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ChoiceChip(
            label: Text(selected.key == 'custom' ? selected.label : 'بازهٔ دلخواه'),
            avatar: Icon(Icons.date_range_outlined, size: 16, color: selected.key == 'custom' ? scheme.onPrimary : scheme.primary),
            selected: selected.key == 'custom',
            selectedColor: scheme.primary,
            labelStyle: TextStyle(color: selected.key == 'custom' ? scheme.onPrimary : scheme.onSurface, fontWeight: FontWeight.w600),
            visualDensity: VisualDensity.compact,
            onSelected: (_) async {
              final r = await showJalaliRangePicker(context);
              if (r != null) onChanged(Period.custom(r.start, r.end));
            },
          ),
        ],
      ),
    );
  }
}

class _CategoriesReport extends StatelessWidget {
  const _CategoriesReport({super.key, required this.stats, required this.onTapCategory});
  final Stats stats;
  final ValueChanged<String> onTapCategory;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (stats.byCategory.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Panel(
          child: Center(
            child: DonutChart(
              size: 200,
              thickness: 26,
              slices: [for (final c in stats.byCategory) DonutSlice(c.key, categoryOf(c.key).label, c.amount, categoryOf(c.key).color)],
              centerTop: 'جمع',
              centerBottom: fmtCompact(stats.total, unit: s.unit),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              for (final c in stats.byCategory)
                InkWell(
                  onTap: () => onTapCategory(c.key),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        CategoryAvatar(c.key, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(categoryOf(c.key).label, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                                  Text(fmtMoney(c.amount, unit: s.unit, withUnit: false), style: amountStyle(context, size: 14)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ShareBar(ratio: stats.total == 0 ? 0 : c.amount / stats.total, color: categoryOf(c.key).color),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${fmtPercent(stats.total == 0 ? 0 : c.amount / stats.total)} · ${faDigits(c.count)} مورد', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                  const Spacer(),
                                  SizedBox(width: 90, child: SideSplitBar(a: c.a, b: c.b)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthsReport extends StatelessWidget {
  const _MonthsReport({super.key, required this.stats, required this.onTapMonth});
  final Stats stats;
  final ValueChanged<MonthBucket> onTapMonth;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final months = stats.byMonth.reversed.toList();
    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هزینهٔ ماهانه (۶ ماه اخیر)', style: text.titleMedium),
              const SizedBox(height: 12),
              MonthBarChart(buckets: stats.byMonth, unit: s.unit, height: 180),
              const SizedBox(height: 8),
              Legend([(Palette.sideA, s.config.sideAName), (Palette.sideB, s.config.sideBName)]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              for (final b in months)
                ListTile(
                  onTap: b.total == 0 ? null : () => onTapMonth(b),
                  title: Text(fmtMonthYear(b.start)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SideSplitBar(a: b.a, b: b.b),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmtMoney(b.total, unit: s.unit, withUnit: false), style: amountStyle(context, size: 15)),
                      Text('${fmtCompact(b.a, unit: s.unit)} / ${fmtCompact(b.b, unit: s.unit)}', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidesReport extends StatelessWidget {
  const _SidesReport({super.key, required this.stats});
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cfg = s.config;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget side(Side sd) {
      final color = Palette.side(sd);
      final spent = stats.spent(sd);
      final cats = stats.byCategory.where((c) => (sd == Side.a ? c.a : c.b) > 0).toList()
        ..sort((x, y) => (sd == Side.a ? y.a : y.b).compareTo(sd == Side.a ? x.a : x.b));
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SideBadge(sd, cfg.sideName(sd)),
                const Spacer(),
                Text('${faDigits(cfg.share(sd))} دانگ · سهم ${fmtPercent(sd == Side.a ? cfg.ratioA : cfg.ratioB)}', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedAmount(spent, unit: s.unit, size: 26, color: color),
            Text('${faDigits(stats.countOf(sd))} هزینه در این بازه · ${fmtPercent(stats.shareOfTotal(sd))} از کل', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            for (final c in cats.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(categoryOf(c.key).icon, size: 16, color: categoryOf(c.key).color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(categoryOf(c.key).label, style: text.bodySmall)),
                    Text(fmtCompact(sd == Side.a ? c.a : c.b, unit: s.unit), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Divider(height: 20),
            Text('از ابتدای پروژه', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('پرداختی: ${fmtMoney(sd == Side.a ? stats.allSpentA : stats.allSpentB, unit: s.unit)}', style: text.bodySmall)),
              ],
            ),
            Text('مشارکت مؤثر (با تسویه‌ها): ${fmtMoney(stats.contribution(sd), unit: s.unit)}', style: text.bodySmall),
            Text('سهم عادلانه: ${fmtMoney(sd == Side.a ? stats.fairA : stats.fairB, unit: s.unit)}', style: text.bodySmall),
          ],
        ),
      );
    }

    return Column(
      children: [
        side(Side.a),
        const SizedBox(height: 12),
        side(Side.b),
      ],
    );
  }
}
