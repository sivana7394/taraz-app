// داشبورد: جمع کل، سهم‌ها، تراز، نمودارها، نکته‌ها و آخرین هزینه‌ها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/stats.dart';
import '../entries/entries_page.dart';
import '../entries/entry_editor.dart';
import '../inbox/inbox_page.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'settlement_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onOpenEntries, required this.onOpenReports});
  final void Function(EntriesFilter? filter) onOpenEntries;
  final VoidCallback onOpenReports;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _selectedCat;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.stats;
    final cfg = s.config;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unseen = s.unseenFromOther;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 500)),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              titleSpacing: 20,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cfg.name, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    fmtDateWithWeekday(DateTime.now()),
                    style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  child: Center(child: SyncChip(s.sync)),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: SliverList.list(
                children: [
                  if (s.isDemo) ...[
                    _DemoBanner(onExit: () => s.disconnect()),
                    const SizedBox(height: 12),
                  ],
                  if (s.error != null && !s.isDemo) ...[
                    _NoticeCard(icon: Icons.warning_amber_rounded, color: scheme.error, text: s.error!),
                    const SizedBox(height: 12),
                  ],
                  if (unseen > 0) ...[
                    _NoticeCard(
                      icon: Icons.notifications_active_outlined,
                      color: scheme.primary,
                      text: '${faDigits(unseen)} هزینهٔ جدید از گوشی دیگر ثبت شده است.',
                      actionLabel: 'مشاهده',
                      onAction: () => widget.onOpenEntries(null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (s.inbox.isNotEmpty) ...[
                    Panel(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      onTap: () => InboxPage.open(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 18, color: Palette.amber),
                                    const SizedBox(width: 6),
                                    Text('${faDigits(s.inbox.length)} رسید در انتظار ثبت', style: text.titleSmall),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('روی هر رسید بزنید و هزینه‌اش را ثبت کنید.', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                InboxThumbStrip(items: s.inbox),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ------------------------------------------------ بازه
                  _PeriodBar(selected: s.period, onChanged: (p) => s.period = p),
                  const SizedBox(height: 12),

                  // ------------------------------------------------ جمع کل
                  _TotalCard(stats: st, unit: s.unit),
                  const SizedBox(height: 12),

                  // ------------------------------------------------ تراز
                  _BalanceCard(
                    stats: st,
                    config: cfg,
                    unit: s.unit,
                    onSettle: () => showSettlementSheet(context),
                  ),
                  const SizedBox(height: 12),

                  // ------------------------------------------------ نمودار دسته‌ها
                  if (st.byCategory.isNotEmpty) ...[
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('هزینه‌ها بر اساس دسته', style: text.titleMedium)),
                              TextButton(onPressed: widget.onOpenReports, child: const Text('گزارش کامل')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              DonutChart(
                                size: 164,
                                thickness: 22,
                                slices: [
                                  for (final c in st.byCategory) DonutSlice(c.key, categoryOf(c.key).label, c.amount, categoryOf(c.key).color),
                                ],
                                selectedKey: _selectedCat,
                                onSelect: (k) => setState(() => _selectedCat = k),
                                centerTop: _selectedCat == null ? 'کل' : categoryOf(_selectedCat!).label,
                                centerBottom: fmtCompact(
                                  _selectedCat == null ? st.total : st.byCategory.firstWhere((c) => c.key == _selectedCat).amount,
                                  unit: s.unit,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final c in st.byCategory.take(5))
                                      _LegendRow(
                                        color: categoryOf(c.key).color,
                                        label: categoryOf(c.key).label,
                                        value: fmtPercent(st.total == 0 ? 0 : c.amount / st.total),
                                        selected: _selectedCat == c.key,
                                        onTap: () => setState(() => _selectedCat = _selectedCat == c.key ? null : c.key),
                                      ),
                                    if (st.byCategory.length > 5)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('و ${faDigits(st.byCategory.length - 5)} دستهٔ دیگر…', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ------------------------------------------------ روند ماهانه
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('روند ماهانه', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text('۶ ماه اخیر، به تفکیک طرف‌ها', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        MonthBarChart(buckets: st.byMonth, unit: s.unit, height: 160),
                        const SizedBox(height: 10),
                        Legend([(Palette.sideA, cfg.sideAName), (Palette.sideB, cfg.sideBName)]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ------------------------------------------------ نکته‌ها
                  if (st.count > 0 || st.allTotal > 0) ...[
                    _InsightsCard(insights: st.insights(cfg, unit: s.unit)),
                    const SizedBox(height: 12),
                  ],

                  // ------------------------------------------------ آخرین‌ها
                  SectionTitle('آخرین هزینه‌ها', action: 'همه', onAction: () => widget.onOpenEntries(null)),
                  if (!s.loaded)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (s.entries.isEmpty)
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'هنوز هزینه‌ای ثبت نشده',
                      subtitle: 'اولین هزینه را ثبت کنید؛ همان لحظه روی گوشی طرف مقابل هم دیده می‌شود.',
                      action: FilledButton.icon(
                        onPressed: () => EntryEditorPage.open(context),
                        icon: const Icon(Icons.add),
                        label: const Text('ثبت هزینه'),
                      ),
                    )
                  else
                    for (final e in s.entries.take(6)) ...[
                      EntryTile(entry: e, dense: true),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.selected, required this.onChanged});
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
                side: BorderSide(color: selected.key == p.key ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.7)),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.stats, required this.unit});
  final Stats stats;
  final MoneyUnit unit;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final text = Theme.of(context).textTheme;
    final cfg = s.config;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: dark
              ? [const Color(0xFF134E4A), const Color(0xFF0F2E2C)]
              : [const Color(0xFF0F766E), const Color(0xFF115E59)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.white.withValues(alpha: 0.85), size: 18),
              const SizedBox(width: 6),
              Text('جمع هزینه‌ها — ${stats.period.label}', style: text.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedAmount(stats.total, unit: unit, size: 34, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            stats.total == 0
                ? 'هزینه‌ای در این بازه ثبت نشده'
                : stats.adjustedCount > 0
                    ? 'پرداختی واقعی ${fmtCompact(stats.paidTotal, unit: unit)} · ${faDigits(stats.adjustedCount)} مورد با معادل امروز'
                    : moneyToWords(stats.total, unit: unit),
            style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SideMini(name: cfg.sideAName, amount: stats.spentA, count: stats.countA, color: Palette.sideA, unit: unit, share: stats.shareOfTotal(Side.a))),
              const SizedBox(width: 10),
              Expanded(child: _SideMini(name: cfg.sideBName, amount: stats.spentB, count: stats.countB, color: Palette.sideB, unit: unit, share: stats.shareOfTotal(Side.b))),
            ],
          ),
          const SizedBox(height: 12),
          DualBar(ratioA: stats.total == 0 ? 0.5 : stats.spentA / stats.total, height: 10, marker: cfg.ratioA),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${fmtPercent(stats.shareOfTotal(Side.a))} ${cfg.sideAName}', style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
              const Spacer(),
              Text('خط: سهم قراردادی ${fmtPercent(cfg.ratioA)}', style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
              const Spacer(),
              Text('${cfg.sideBName} ${fmtPercent(stats.shareOfTotal(Side.b))}', style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideMini extends StatelessWidget {
  const _SideMini({required this.name, required this.amount, required this.count, required this.color, required this.unit, required this.share});
  final String name;
  final int amount;
  final int count;
  final Color color;
  final MoneyUnit unit;
  final double share;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1))),
              const SizedBox(width: 6),
              Expanded(child: Text(name, style: text.labelMedium?.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmtMoney(amount, unit: unit, withUnit: false), style: amountStyle(context, size: 17, color: Colors.white)),
          Text('${faDigits(count)} مورد', style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.stats, required this.config, required this.unit, required this.onSettle});
  final Stats stats;
  final RoomConfig config;
  final MoneyUnit unit;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final debtor = stats.debtor ?? Side.b;
    final balanced = stats.debtor == null || stats.owed < 1000;
    final color = balanced ? Palette.positive : Palette.side(debtor);

    final headline = balanced
        ? 'حساب‌ها تراز است'
        : '${s.nameOf(debtor)} به ${s.nameOf(debtor.other)} بدهکار است';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
                child: Icon(balanced ? Icons.balance : Icons.swap_horiz, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تراز کل (از ابتدا تا امروز)', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(headline, style: text.titleMedium?.copyWith(color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!balanced) AnimatedAmount(stats.owed, unit: unit, size: 28, color: color),
          if (!balanced) const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _kv(context, 'کل هزینه‌های پروژه (با معادل امروز)', fmtMoney(stats.allTotal, unit: unit)),
                _kv(context, 'سهم ${config.sideAName} (${faDigits(config.shareA)} دانگ)', fmtMoney(stats.fairA, unit: unit)),
                _kv(context, 'سهم ${config.sideBName} (${faDigits(config.shareB)} دانگ)', fmtMoney(stats.fairB, unit: unit)),
                const Divider(height: 14),
                _kv(context, 'پرداختی ${config.sideAName}', fmtMoney(stats.allSpentA, unit: unit), color: Palette.sideA),
                _kv(context, 'پرداختی ${config.sideBName}', fmtMoney(stats.allSpentB, unit: unit), color: Palette.sideB),
                if (stats.transfersAB > 0 || stats.transfersBA > 0) ...[
                  const Divider(height: 14),
                  if (stats.transfersBA > 0) _kv(context, 'تسویه از ${config.sideBName} به ${config.sideAName}', fmtMoney(stats.transfersBA, unit: unit)),
                  if (stats.transfersAB > 0) _kv(context, 'تسویه از ${config.sideAName} به ${config.sideBName}', fmtMoney(stats.transfersAB, unit: unit)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSettle,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('ثبت تسویه'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Color? color}) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (color != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(k, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(v, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.value, required this.selected, required this.onTap});
  final Color color;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: text.labelMedium?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(value, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});
  final List<String> insights;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Palette.amber, size: 20),
              const SizedBox(width: 6),
              Text('نکته‌ها', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(i, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.color, required this.text, this.actionLabel, this.onAction});
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.onExit});
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(child: Text('حالت نمایشی با داده‌های نمونه. برای کار واقعی، به پروژهٔ خودتان متصل شوید.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer))),
          TextButton(onPressed: onExit, child: const Text('اتصال')),
        ],
      ),
    );
  }
}
