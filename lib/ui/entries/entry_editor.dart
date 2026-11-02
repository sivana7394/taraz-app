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
import '../widgets/receipt_view.dart';
import 'entry_detail.dart';

/// پیوست در حال ویرایش (ممکن است هنوز بارگذاری نشده باشد).
class _Draft {
  _Draft({required this.id, required this.label, this.thumb, this.full, this.uploaded = false});
  final String id;
  String label;
  Uint8List? thumb;
  Uint8List? full;
  /// تصویر کامل همین حالا روی سرور هست (پیوست قدیمی یا رسیدِ صندوق).
  final bool uploaded;
}

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, this.entry, this.inboxItem, this.autoCamera = false});
  final Entry? entry;
  /// اگر از صندوق رسیدها آمده باشد، این رسید به‌عنوان پیوست اول قرار می‌گیرد.
  final InboxItem? inboxItem;
  /// بلافاصله دوربین را باز کند (میانبر «عکس رسید»).
  final bool autoCamera;

  static Future<bool?> open(BuildContext context, {Entry? entry, InboxItem? inboxItem, bool autoCamera = false}) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EntryEditorPage(entry: entry, inboxItem: inboxItem, autoCamera: autoCamera),
          fullscreenDialog: true,
        ),
      );

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  final _amountCtl = TextEditingController();
  final _adjCtl = TextEditingController();
  final _titleCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  final _amountFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  String _category = 'materials';
  PayMethod _method = PayMethod.card;
  late DateTime _paidAt;
  late Side _payer;
  bool _proxy = false; // خرید توسط طرف دیگر
  bool _useAdjusted = false;
  final List<_Draft> _attachments = [];
  final List<String> _removedIds = [];
  bool _processing = false;
  bool _saving = false;
  /// پنل رسید بالای فرم
  double _paneFrac = 0.40;
  bool _paneCollapsed = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final e = widget.entry;
    _paidAt = e?.paidAt ?? DateTime.now();
    _payer = e?.side ?? s.defaultPayer;
    if (e != null) {
      _amountCtl.text = groupDigits(e.amount);
      _titleCtl.text = e.title;
      _noteCtl.text = e.note;
      _category = e.category;
      _method = e.method;
      _proxy = e.isProxy;
      if (e.adjustedAmount != null) {
        _useAdjusted = true;
        _adjCtl.text = groupDigits(e.adjustedAmount!);
      }
      for (final a in e.attachments) {
        _attachments.add(_Draft(id: a.id, label: a.label, thumb: a.thumb, uploaded: true));
      }
    } else {
      final ib = widget.inboxItem;
      if (ib != null) {
        _attachments.add(_Draft(id: ib.id, label: 'رسید خرید', thumb: ib.thumb, uploaded: true));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.autoCamera) {
          _pick(ImageSource.camera);
        } else {
          _amountFocus.requestFocus();
        }
      });
    }
    _amountCtl.addListener(() => setState(() {}));
    _adjCtl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _adjCtl.dispose();
    _titleCtl.dispose();
    _noteCtl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double _paneHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 80;
    final frac = keyboard ? (_paneFrac < 0.3 ? _paneFrac : 0.3) : _paneFrac;
    return (mq.size.height * frac).clamp(120.0, mq.size.height * 0.75);
  }

  int get _amount => parseAmount(_amountCtl.text) ?? 0;
  int? get _adjusted => _useAdjusted ? parseAmount(_adjCtl.text) : null;

  void _bump(TextEditingController c, int add) {
    final v = (parseAmount(c.text) ?? 0) + add;
    c.text = groupDigits(v);
    HapticFeedback.selectionClick();
  }

  Future<void> _pick(ImageSource src) async {
    if (_attachments.length >= 5) {
      toast(context, 'حداکثر ۵ پیوست برای هر هزینه');
      return;
    }
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
      if (x == null) return;
      setState(() => _processing = true);
      final bytes = await x.readAsBytes();
      final p = await processReceipt(bytes);
      if (!mounted) return;
      final s = context.read<AppState>();
      setState(() {
        _attachments.add(_Draft(
          id: s.newId(),
          label: _attachments.isEmpty ? 'رسید خرید' : (_proxy ? 'رسید واریز' : 'سایر'),
          thumb: p.thumb,
          full: p.full,
        ));
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      toast(context, 'عکس گرفته نشد: $e');
    }
  }

  Future<void> _pickMultiFromGallery() async {
    try {
      final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 88, limit: 5);
      if (xs.isEmpty) return;
      setState(() => _processing = true);
      final s = context.read<AppState>();
      for (final x in xs) {
        if (_attachments.length >= 5) break;
        final p = await processReceipt(await x.readAsBytes());
        _attachments.add(_Draft(id: s.newId(), label: _attachments.isEmpty ? 'رسید خرید' : 'سایر', thumb: p.thumb, full: p.full));
      }
      if (mounted) setState(() => _processing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      toast(context, 'انتخاب عکس انجام نشد: $e');
    }
  }

  void _removeAttachment(_Draft d) => setState(() {
        _attachments.remove(d);
        if (d.uploaded && d.id != widget.inboxItem?.id) _removedIds.add(d.id);
      });

  Future<void> _save({bool andNew = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_amount <= 0) {
      _amountFocus.requestFocus();
      return;
    }
    if (_useAdjusted && (_adjusted == null || _adjusted! <= 0)) {
      toast(context, 'مبلغ «معادل امروز» را وارد کنید یا آن را خاموش کنید');
      return;
    }
    final s = context.read<AppState>();
    setState(() => _saving = true);
    final now = DateTime.now();
    final newReceipts = <String, Uint8List>{};
    final attachments = <Attachment>[];
    for (final d in _attachments) {
      attachments.add(Attachment(id: d.id, label: d.label, thumb: d.thumb));
      if (!d.uploaded && d.full != null) newReceipts[d.id] = d.full!;
    }
    final e = Entry(
      id: widget.entry?.id ?? s.newId(),
      side: _payer,
      buyer: _proxy ? _payer.other : _payer,
      amount: _amount,
      adjustedAmount: _adjusted,
      title: _titleCtl.text.trim(),
      category: _category,
      paidAt: _paidAt,
      note: _noteCtl.text.trim(),
      method: _method,
      attachments: attachments,
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: _isEdit ? now : null,
      createdBy: widget.entry?.createdBy.isNotEmpty == true ? widget.entry!.createdBy : s.deviceId,
    );
    final inboxId = widget.inboxItem?.id;
    final consumed = inboxId != null && _attachments.any((d) => d.id == inboxId) ? inboxId : null;
    await s.saveEntry(e, newReceipts: newReceipts, removedReceiptIds: _removedIds, consumeInboxId: consumed);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (andNew) {
      toast(context, 'ثبت شد: ${fmtMoney(e.effectiveAmount, unit: s.unit)}');
      setState(() {
        _amountCtl.clear();
        _adjCtl.clear();
        _useAdjusted = false;
        _titleCtl.clear();
        _noteCtl.clear();
        _attachments.clear();
        _removedIds.clear();
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
    final buyer = _proxy ? _payer.other : _payer;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'ویرایش هزینه' : (widget.inboxItem != null ? 'ثبت هزینه از رسید' : 'هزینهٔ جدید')),
      ),
      body: Column(
        children: [
          if (_attachments.isNotEmpty)
            ReceiptPane(
              items: [for (final d in _attachments) ReceiptPaneItem(id: d.id, label: d.label, bytes: d.full, thumb: d.thumb)],
              height: _paneHeight(context),
              onHeightChanged: (h) => setState(() => _paneFrac = (h / MediaQuery.of(context).size.height).clamp(0.18, 0.75)),
              collapsed: _paneCollapsed,
              onToggle: () => setState(() => _paneCollapsed = !_paneCollapsed),
              onFullscreen: (item) async {
                final bytes = item.bytes ?? await context.read<AppState>().getReceipt(item.id);
                if (bytes != null && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptViewer(bytes: bytes, tag: 'pane-${item.id}', title: item.label)));
                }
              },
            ),
          Expanded(
            child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            // ------------------------------------------------------ پرداخت‌کننده
            Text('پول از جیب چه کسی رفته؟', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _SideButton(side: Side.a, label: s.nameOf(Side.a), selected: _payer == Side.a, onTap: () => setState(() => _payer = Side.a))),
                const SizedBox(width: 10),
                Expanded(child: _SideButton(side: Side.b, label: s.nameOf(Side.b), selected: _payer == Side.b, onTap: () => setState(() => _payer = Side.b))),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              value: _proxy,
              onChanged: (v) => setState(() => _proxy = v),
              title: Text('خرید به نیابت — خرید را ${s.nameOf(_payer.other)} انجام داده', style: text.bodyMedium),
              subtitle: Text(
                _proxy
                    ? 'پول از ${s.nameOf(_payer)} و خرید توسط ${s.nameOf(buyer)}. رسید واریز پول را هم پیوست کنید.'
                    : 'مثلاً ${s.nameOf(_payer.other)} خرید کرده ولی پولش را ${s.nameOf(_payer)} داده است.',
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 6),

            // ---------------------------------------------------------- مبلغ
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مبلغ پرداختی', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
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
                  _QuickAdd(onAdd: (v) => _bump(_amountCtl, v), onClear: _amount > 0 ? () => _amountCtl.clear() : null),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ---------------------------------------------------- معادل امروز
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              color: _useAdjusted ? Palette.amber.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.07) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _useAdjusted,
                    onChanged: (v) => setState(() => _useAdjusted = v),
                    title: Text('معادل امروز (قیمت روز)', style: text.titleSmall),
                    subtitle: Text(
                      'برای خریدهای قدیمی: مبلغی که امروز باید برای همین خرید داد. در حساب‌وکتاب و تراز، همین مبلغ منظور می‌شود؛ رسید اصلی سر جایش می‌ماند.',
                      style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (_useAdjusted) ...[
                    TextFormField(
                      controller: _adjCtl,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      inputFormatters: [AmountInputFormatter()],
                      style: amountStyle(context, size: 28, color: Palette.amber),
                      decoration: InputDecoration(
                        hintText: '۰',
                        hintStyle: amountStyle(context, size: 28, color: scheme.onSurface.withValues(alpha: 0.25)),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        suffixText: s.unit.label,
                        suffixStyle: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if ((_adjusted ?? 0) > 0)
                      Text(
                        '${moneyToWords(_adjusted!, unit: s.unit)}${_amount > 0 ? ' — ${_adjusted! >= _amount ? '+' : '−'}${fmtPercent(((_adjusted! - _amount).abs()) / _amount)} نسبت به پرداختی' : ''}',
                        style: text.bodySmall?.copyWith(color: Palette.amber, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 8),
                    _QuickAdd(onAdd: (v) => _bump(_adjCtl, v), onClear: (_adjusted ?? 0) > 0 ? () => _adjCtl.clear() : null, extra: [
                      if (_amount > 0) ('= پرداختی', () => _adjCtl.text = groupDigits(_amount)),
                      if (_amount > 0) ('+۲۰٪', () => _adjCtl.text = groupDigits((_amount * 1.2).round())),
                      if (_amount > 0) ('+۵۰٪', () => _adjCtl.text = groupDigits((_amount * 1.5).round())),
                    ]),
                  ],
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

            // ---------------------------------------------------------- پیوست‌ها
            Row(
              children: [
                Expanded(child: Text('رسیدها و اسناد', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant))),
                Text('${faDigits(_attachments.length)} از ۵', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            _AttachmentsEditor(
              items: _attachments,
              processing: _processing,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: _pickMultiFromGallery,
              onRemove: _removeAttachment,
              onLabel: (d, label) => setState(() => d.label = label),
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
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (!_isEdit && widget.inboxItem == null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _processing ? null : () => _save(andNew: true),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('ثبت و بعدی'),
                  ),
                ),
              if (!_isEdit && widget.inboxItem == null) const SizedBox(width: 10),
              Expanded(
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

class _SideButton extends StatelessWidget {
  const _SideButton({required this.side, required this.label, required this.selected, required this.onTap});
  final Side side;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Palette.side(side);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? c : c.withValues(alpha: dark ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? c : c.withValues(alpha: 0.4), width: selected ? 0 : 1)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18, color: selected ? Colors.white : c),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.onAdd, this.onClear, this.extra = const []});
  final ValueChanged<int> onAdd;
  final VoidCallback? onClear;
  final List<(String, VoidCallback)> extra;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, cb) in extra)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(label: Text(label), onPressed: cb, visualDensity: VisualDensity.compact),
            ),
          for (final (label, v) in [('+۱۰۰ هزار', 100000), ('+۵۰۰ هزار', 500000), ('+۱ میلیون', 1000000), ('+۵ میلیون', 5000000), ('+۱۰ میلیون', 10000000)])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(label: Text(label), onPressed: () => onAdd(v), visualDensity: VisualDensity.compact),
            ),
          if (onClear != null)
            ActionChip(label: const Icon(Icons.backspace_outlined, size: 16), onPressed: onClear, visualDensity: VisualDensity.compact),
        ],
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

class _AttachmentsEditor extends StatelessWidget {
  const _AttachmentsEditor({
    required this.items,
    required this.processing,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onLabel,
  });
  final List<_Draft> items;
  final bool processing;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<_Draft> onRemove;
  final void Function(_Draft, String) onLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = items[i];
                return SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 120,
                              height: 96,
                              child: d.thumb != null
                                  ? Image.memory(d.thumb!, fit: BoxFit.cover, gaplessPlayback: true)
                                  : Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.receipt_long_outlined)),
                            ),
                          ),
                          PositionedDirectional(
                            top: 4,
                            start: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onRemove(d),
                                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'برچسب',
                          onSelected: (v) => onLabel(d, v),
                          itemBuilder: (_) => [for (final l in attachmentLabels) PopupMenuItem(value: l, child: Text(l))],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(child: Text(d.label, style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.expand_more, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (items.isNotEmpty) const SizedBox(height: 10),
        if (processing)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: const [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                SizedBox(width: 10),
                Text('آماده‌سازی عکس…'),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(child: _BigAction(icon: Icons.photo_camera_outlined, label: 'عکس بگیر', onTap: onCamera)),
            const SizedBox(width: 10),
            Expanded(child: _BigAction(icon: Icons.photo_library_outlined, label: 'از گالری', onTap: onGallery)),
          ],
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
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
