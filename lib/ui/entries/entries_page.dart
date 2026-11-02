// فهرست هزینه‌ها با جست‌وجو و فیلتر.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/jalali_picker.dart';
import 'entry_detail.dart';
import 'entry_editor.dart';

class EntriesFilter {
  final Side? side;
  final Set<String> categories;
  final DateTimeRange? range;
  final String query;
  final bool onlyWithoutReceipt;

  const EntriesFilter({this.side, this.categories = const {}, this.range, this.query = '', this.onlyWithoutReceipt = false});

  bool get isActive => side != null || categories.isNotEmpty || range != null || query.trim().isNotEmpty || onlyWithoutReceipt;

  EntriesFilter copyWith({Side? side, bool clearSide = false, Set<String>? categories, DateTimeRange? range, bool clearRange = false, String? query, bool? onlyWithoutReceipt}) =>
      EntriesFilter(
        side: clearSide ? null : (side ?? this.side),
        categories: categories ?? this.categories,
        range: clearRange ? null : (range ?? this.range),
        query: query ?? this.query,
        onlyWithoutReceipt: onlyWithoutReceipt ?? this.onlyWithoutReceipt,
      );

  bool matches(Entry e) {
    if (side != null && e.side != side) return false;
    if (categories.isNotEmpty && !categories.contains(e.category)) return false;
    if (onlyWithoutReceipt && e.hasReceipt) return false;
    if (range != null) {
      final s = DateTime(range!.start.year, range!.start.month, range!.start.day);
      final en = DateTime(range!.end.year, range!.end.month, range!.end.day).add(const Duration(days: 1));
      if (e.paidAt.isBefore(s) || !e.paidAt.isBefore(en)) return false;
    }
    final q = enDigits(query.trim());
    if (q.isNotEmpty) {
      final hay = enDigits('${e.title} ${e.note} ${categoryOf(e.category).label} ${e.amount}');
      if (!hay.contains(q)) return false;
    }
    return true;
  }
}

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key, this.initialFilter});
  final EntriesFilter? initialFilter;

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  late EntriesFilter _filter = widget.initialFilter ?? const EntriesFilter();
  final _searchCtl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchCtl.text = _filter.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markSeen();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final all = s.entries;
    final items = all.where(_filter.matches).toList();
    final sum = items.fold<int>(0, (a, e) => a + e.amount);

    // گروه‌بندی بر اساس روز
    final groups = <String, List<Entry>>{};
    final order = <String>[];
    for (final e in items) {
      final k = '${e.paidAt.year}-${e.paidAt.month}-${e.paidAt.day}';
      if (!groups.containsKey(k)) {
        groups[k] = [];
        order.add(k);
      }
      groups[k]!.add(e);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: _searching
                ? TextField(
                    controller: _searchCtl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'جست‌وجو در موضوع، توضیح، مبلغ…',
                      isDense: true,
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _searching = false;
                          _searchCtl.clear();
                          _filter = _filter.copyWith(query: '');
                        }),
                      ),
                    ),
                    onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
                  )
                : const Text('هزینه‌ها'),
            actions: [
              if (!_searching)
                IconButton(
                  tooltip: 'جست‌وجو',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _searching = true),
                ),
              IconButton(
                tooltip: 'فیلتر',
                icon: Badge(
                  isLabelVisible: _filter.isActive,
                  child: const Icon(Icons.tune),
                ),
                onPressed: _openFilterSheet,
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('همه', _filter.side == null, () => setState(() => _filter = _filter.copyWith(clearSide: true))),
                      const SizedBox(width: 8),
                      _chip(s.nameOf(Side.a), _filter.side == Side.a, () => setState(() => _filter = _filter.copyWith(side: Side.a)), color: Palette.sideA),
                      const SizedBox(width: 8),
                      _chip(s.nameOf(Side.b), _filter.side == Side.b, () => setState(() => _filter = _filter.copyWith(side: Side.b)), color: Palette.sideB),
                      const SizedBox(width: 8),
                      _chip(
                        _filter.range == null ? 'بازهٔ تاریخ' : '${fmtDate(_filter.range!.start, withYear: false)} – ${fmtDate(_filter.range!.end, withYear: false)}',
                        _filter.range != null,
                        () async {
                          final r = await showJalaliRangePicker(context, initial: _filter.range);
                          if (r != null) setState(() => _filter = _filter.copyWith(range: r));
                        },
                        icon: Icons.date_range_outlined,
                        onClear: _filter.range == null ? null : () => setState(() => _filter = _filter.copyWith(clearRange: true)),
                      ),
                      const SizedBox(width: 8),
                      _chip('بدون رسید', _filter.onlyWithoutReceipt, () => setState(() => _filter = _filter.copyWith(onlyWithoutReceipt: !_filter.onlyWithoutReceipt)), icon: Icons.receipt_long_outlined),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!s.loaded)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: all.isEmpty ? Icons.receipt_long_outlined : Icons.search_off,
                title: all.isEmpty ? 'هنوز هزینه‌ای ثبت نشده' : 'چیزی پیدا نشد',
                subtitle: all.isEmpty ? 'اولین هزینه را با دکمهٔ «ثبت هزینه» اضافه کنید.' : 'فیلترها را تغییر دهید.',
                action: all.isEmpty
                    ? FilledButton.icon(onPressed: () => EntryEditorPage.open(context), icon: const Icon(Icons.add), label: const Text('ثبت هزینه'))
                    : OutlinedButton(onPressed: () => setState(() => _filter = const EntriesFilter()), child: const Text('حذف فیلترها')),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: Row(
                  children: [
                    Text('${faDigits(items.length)} مورد', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('جمع: ${fmtMoney(sum, unit: s.unit)}', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            for (final k in order) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Text(relativeDay(groups[k]!.first.paidAt), style: text.titleSmall?.copyWith(color: scheme.primary)),
                      const Spacer(),
                      Text(
                        fmtCompact(groups[k]!.fold<int>(0, (a, e) => a + e.amount), unit: s.unit),
                        style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: groups[k]!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => EntryTile(entry: groups[k]![i]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color, IconData? icon, VoidCallback? onClear}) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return FilterChip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 16, color: selected ? Colors.white : c) : null,
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : scheme.onSurface, fontWeight: FontWeight.w600),
      side: BorderSide(color: selected ? c : scheme.outlineVariant.withValues(alpha: 0.7)),
      deleteIcon: onClear != null ? const Icon(Icons.close, size: 16, color: Colors.white) : null,
      onDeleted: onClear,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<EntriesFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _FilterSheet(filter: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter});
  final EntriesFilter filter;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late EntriesFilter _f = widget.filter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('فیلتر هزینه‌ها', style: text.titleLarge),
          const SizedBox(height: 14),
          Text('دسته‌ها', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                FilterChip(
                  label: Text(c.label),
                  avatar: Icon(c.icon, size: 16, color: _f.categories.contains(c.key) ? Colors.white : c.color),
                  selected: _f.categories.contains(c.key),
                  selectedColor: c.color,
                  labelStyle: TextStyle(color: _f.categories.contains(c.key) ? Colors.white : null),
                  onSelected: (v) => setState(() {
                    final set = {..._f.categories};
                    if (v) {
                      set.add(c.key);
                    } else {
                      set.remove(c.key);
                    }
                    _f = _f.copyWith(categories: set);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('فقط هزینه‌های بدون رسید'),
            value: _f.onlyWithoutReceipt,
            onChanged: (v) => setState(() => _f = _f.copyWith(onlyWithoutReceipt: v)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, const EntriesFilter()),
                child: const Text('حذف همهٔ فیلترها'),
              ),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(context, _f), child: const Text('اعمال')),
            ],
          ),
        ],
      ),
    );
  }
}

/// ردیف یک هزینه در فهرست.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.dense = false});
  final Entry entry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cat = categoryOf(entry.category);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => EntryDetailPage.open(context, entry.id),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 12),
          child: Row(
            children: [
              if (entry.thumb != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(entry.thumb!, width: 46, height: 46, fit: BoxFit.cover, gaplessPlayback: true),
                )
              else
                CategoryAvatar(entry.category, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        SideBadge(entry.side, s.nameOf(entry.side), compact: true),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${cat.label} · ${fmtTime(entry.paidAt)}',
                            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtMoney(entry.amount, unit: s.unit, withUnit: false), style: amountStyle(context, size: 16)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.pending)
                        Icon(Icons.cloud_upload_outlined, size: 13, color: Palette.amber)
                      else if (entry.hasReceipt)
                        Icon(Icons.receipt_long_outlined, size: 13, color: scheme.onSurfaceVariant),
                      if (entry.pending || entry.hasReceipt) const SizedBox(width: 3),
                      Text(s.unit.label, style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
