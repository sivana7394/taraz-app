// ثبت پرداخت تسویه بین دو طرف + فهرست تسویه‌های قبلی.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/jalali_picker.dart';

Future<void> showSettlementSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SettlementSheet(),
    );

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet();
  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  Side _from = Side.b;
  DateTime _date = DateTime.now();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = context.read<AppState>();
    final st = s.stats;
    if (st.debtor != null) {
      _from = st.debtor!;
      if (st.owed >= 1000) _amountCtl.text = groupDigits(st.owed);
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final amount = parseAmount(_amountCtl.text) ?? 0;
    final to = _from.other;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ثبت تسویه', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('پولی که یک طرف به طرف دیگر می‌دهد تا حساب‌ها برابر شود. این مبلغ هزینهٔ پروژه نیست.', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Side>(
                segments: [
                  ButtonSegment(value: Side.b, label: Text('${s.nameOf(Side.b)} ← ${s.nameOf(Side.a)}')),
                  ButtonSegment(value: Side.a, label: Text('${s.nameOf(Side.a)} ← ${s.nameOf(Side.b)}')),
                ],
                selected: {_from},
                onSelectionChanged: (v) => setState(() => _from = v.first),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 6),
            Text('پرداخت از ${s.nameOf(_from)} به ${s.nameOf(to)}', style: text.labelMedium?.copyWith(color: Palette.side(_from), fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              inputFormatters: [AmountInputFormatter()],
              onChanged: (_) => setState(() {}),
              style: amountStyle(context, size: 24),
              decoration: InputDecoration(labelText: 'مبلغ', suffixText: s.unit.label, hintText: '۰'),
            ),
            if (amount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(moneyToWords(amount, unit: s.unit), style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showJalaliDatePicker(context, initial: _date, title: 'تاریخ تسویه');
                      if (d != null) setState(() => _date = d);
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(fmtDate(_date)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtl,
              decoration: const InputDecoration(labelText: 'توضیح (اختیاری)', prefixIcon: Icon(Icons.notes_outlined)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: amount <= 0
                  ? null
                  : () async {
                      final now = DateTime.now();
                      await s.saveSettlement(Settlement(
                        id: s.newId(),
                        from: _from,
                        to: to,
                        amount: amount,
                        paidAt: _date,
                        note: _noteCtl.text.trim(),
                        createdAt: now,
                      ));
                      if (context.mounted) {
                        Navigator.pop(context);
                        toast(context, 'تسویه ثبت شد');
                      }
                    },
              icon: const Icon(Icons.check),
              label: const Text('ثبت تسویه'),
            ),
            if (s.settlements.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('تسویه‌های قبلی', style: text.titleSmall),
              const SizedBox(height: 8),
              for (final t in s.settlements)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Palette.sideSoft(t.from, Theme.of(context).brightness),
                    child: Icon(Icons.swap_horiz, color: Palette.side(t.from)),
                  ),
                  title: Text('${s.nameOf(t.from)} ← ${s.nameOf(t.to)}: ${fmtMoney(t.amount, unit: s.unit)}'),
                  subtitle: Text('${fmtDate(t.paidAt)}${t.note.isNotEmpty ? ' · ${t.note}' : ''}'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: 'حذف تسویه', message: 'این تسویه حذف شود؟');
                      if (ok) await s.deleteSettlement(t.id);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
