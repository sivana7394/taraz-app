// ثبت / ویرایش هزینه.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../core/images.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/jalali_picker.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, this.entry, this.initialReceipt});
  final Entry? entry;
  final Uint8List? initialReceipt;

  static Future<bool?> open(BuildContext context, {Entry? entry}) => Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EntryEditorPage(entry: entry), fullscreenDialog: true),
      );

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  final _amountCtl = TextEditingController();
  final _titleCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  final _amountFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  String _category = 'materials';
  PayMethod _method = PayMethod.card;
  late DateTime _paidAt;
  Uint8List? _receipt; // عکس کامل
  Uint8List? _thumb;
  bool _receiptChanged = false;
  bool _processing = false;
  bool _saving = false;
  bool _receiptExistsRemote = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _paidAt = e?.paidAt ?? DateTime.now();
    if (e != null) {
      _amountCtl.text = groupDigits(e.amount);
      _titleCtl.text = e.title;
      _noteCtl.text = e.note;
      _category = e.category;
      _method = e.method;
      _thumb = e.thumb;
      _receiptExistsRemote = e.hasReceipt;
      if (e.hasReceipt) _loadRemoteReceipt(e.id);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _amountFocus.requestFocus());
    }
    _amountCtl.addListener(() => setState(() {}));
  }

  Future<void> _loadRemoteReceipt(String id) async {
    final bytes = await context.read<AppState>().getReceipt(id);
    if (mounted && !_receiptChanged) setState(() => _receipt = bytes);
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _titleCtl.dispose();
    _noteCtl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  int get _amount => parseAmount(_amountCtl.text) ?? 0;

  void _bump(int add) {
    final v = _amount + add;
    _amountCtl.text = groupDigits(v);
    HapticFeedback.selectionClick();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
      if (x == null) return;
      setState(() => _processing = true);
      final bytes = await x.readAsBytes();
      final p = await processReceipt(bytes);
      if (!mounted) return;
      setState(() {
        _receipt = p.full;
        _thumb = p.thumb;
        _receiptChanged = true;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      toast(context, 'عکس گرفته نشد: $e');
    }
  }

  void _removeReceipt() => setState(() {
        _receipt = null;
        _thumb = null;
        _receiptChanged = true;
      });

  Future<void> _save({bool andNew = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_amount <= 0) {
      _amountFocus.requestFocus();
      return;
    }
    final s = context.read<AppState>();
    setState(() => _saving = true);
    final now = DateTime.now();
    final hasReceipt = _receiptChanged ? _receipt != null : _receiptExistsRemote;
    final e = Entry(
      id: widget.entry?.id ?? s.newId(),
      side: widget.entry?.side ?? s.side,
      amount: _amount,
      title: _titleCtl.text.trim(),
      category: _category,
      paidAt: _paidAt,
      note: _noteCtl.text.trim(),
      method: _method,
      hasReceipt: hasReceipt,
      thumb: hasReceipt ? _thumb : null,
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: _isEdit ? now : null,
    );
    await s.saveEntry(e, receipt: _receiptChanged ? _receipt : null, receiptChanged: _receiptChanged);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (andNew) {
      toast(context, 'ثبت شد: ${fmtMoney(e.amount, unit: s.unit)}');
      setState(() {
        _amountCtl.clear();
        _titleCtl.clear();
        _noteCtl.clear();
        _receipt = null;
        _thumb = null;
        _receiptChanged = false;
        _receiptExistsRemote = false;
        _paidAt = DateTime.now();
        _saving = false;
      });
      _amountFocus.requestFocus();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final side = widget.entry?.side ?? s.side;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'ویرایش هزینه' : 'هزینهٔ جدید'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(child: SideBadge(side, s.nameOf(side))),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            // ---------------------------------------------------------- مبلغ
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مبلغ', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  TextFormField(
                    controller: _amountCtl,
                    focusNode: _amountFocus,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    inputFormatters: [AmountInputFormatter()],
                    style: amountStyle(context, size: 34),
                    decoration: InputDecoration(
                      hintText: '۰',
                      hintStyle: amountStyle(context, size: 34, color: scheme.onSurface.withValues(alpha: 0.25)),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixText: s.unit.label,
                      suffixStyle: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    validator: (_) => _amount <= 0 ? 'مبلغ را وارد کنید' : null,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _amount > 0
                        ? Text(
                            moneyToWords(_amount, unit: s.unit),
                            key: ValueKey(_amount),
                            style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                          )
                        : const SizedBox(height: 18),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (label, v) in [('+۱۰۰ هزار', 100000), ('+۵۰۰ هزار', 500000), ('+۱ میلیون', 1000000), ('+۵ میلیون', 5000000), ('+۱۰ میلیون', 10000000)])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ActionChip(
                              label: Text(label),
                              onPressed: () => _bump(v),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (_amount > 0)
                          ActionChip(
                            label: const Icon(Icons.backspace_outlined, size: 16),
                            onPressed: () => _amountCtl.clear(),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --------------------------------------------------------- موضوع
            TextFormField(
              controller: _titleCtl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'موضوع هزینه',
                hintText: 'مثلاً: ۲۰۰ پاکت سیمان تیپ ۲',
                prefixIcon: Icon(Icons.subject),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'موضوع را بنویسید' : null,
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------------- دسته
            Text('دسته', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  _CategoryChip(
                    category: c,
                    selected: _category == c.key,
                    onTap: () => setState(() => _category = c.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // --------------------------------------------------- تاریخ و ساعت
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'تاریخ',
                    value: fmtDate(_paidAt),
                    onTap: () async {
                      final d = await showJalaliDatePicker(context, initial: _paidAt, title: 'تاریخ پرداخت');
                      if (d != null) setState(() => _paidAt = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: 'ساعت',
                    value: fmtTime(_paidAt),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_paidAt),
                        helpText: 'ساعت پرداخت',
                        builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
                      );
                      if (t != null) setState(() => _paidAt = DateTime(_paidAt.year, _paidAt.month, _paidAt.day, t.hour, t.minute));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---------------------------------------------------- روش پرداخت
            Text('روش پرداخت', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PayMethod>(
                segments: [
                  for (final m in PayMethod.values)
                    ButtonSegment(value: m, label: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(m.icon, size: 18)),
                ],
                selected: {_method},
                onSelectionChanged: (v) => setState(() => _method = v.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(text.labelSmall),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------------- رسید
            Text('رسید / فاکتور', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _ReceiptBox(
              receipt: _receipt,
              thumb: _thumb,
              processing: _processing,
              hasRemote: _receiptExistsRemote && !_receiptChanged,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              onRemove: _removeReceipt,
            ),
            const SizedBox(height: 16),

            // ---------------------------------------------------------- توضیح
            TextFormField(
              controller: _noteCtl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'توضیح (اختیاری)',
                hintText: 'نام فروشنده، شمارهٔ فاکتور، …',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (!_isEdit)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _processing ? null : () => _save(andNew: true),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('ثبت و بعدی'),
                  ),
                ),
              if (!_isEdit) const SizedBox(width: 10),
              Expanded(
                flex: _isEdit ? 1 : 1,
                child: FilledButton.icon(
                  onPressed: _saving || _processing ? null : () => _save(),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isEdit ? 'ذخیرهٔ تغییرات' : 'ثبت هزینه'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onTap});
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = category.color;
    return Material(
      color: selected ? c : c.withValues(alpha: dark ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? c : c.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 18, color: selected ? Colors.white : (dark ? Color.lerp(c, Colors.white, 0.35) : c)),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptBox extends StatelessWidget {
  const _ReceiptBox({
    required this.receipt,
    required this.thumb,
    required this.processing,
    required this.hasRemote,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });
  final Uint8List? receipt;
  final Uint8List? thumb;
  final bool processing;
  final bool hasRemote;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = receipt ?? thumb;
    if (processing) {
      return Container(
        height: 120,
        decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
              SizedBox(width: 12),
              Text('آماده‌سازی عکس…'),
            ],
          ),
        ),
      );
    }
    if (preview != null || hasRemote) {
      return Container(
        decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 84,
                child: preview != null
                    ? Image.memory(preview, fit: BoxFit.cover, gaplessPlayback: true)
                    : Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.receipt_long_outlined)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رسید پیوست شده', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (receipt != null)
                    Text('${faDigits((receipt!.length / 1024).round())} کیلوبایت', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(onPressed: onCamera, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('دوباره')),
                      TextButton.icon(
                        onPressed: onRemove,
                        icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                        label: Text('حذف', style: TextStyle(color: scheme.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _BigAction(icon: Icons.photo_camera_outlined, label: 'عکس بگیر', onTap: onCamera),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigAction(icon: Icons.photo_library_outlined, label: 'از گالری', onTap: onGallery),
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7), style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
