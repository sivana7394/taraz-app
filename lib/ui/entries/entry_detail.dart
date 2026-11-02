// جزئیات یک هزینه + نمایش رسیدها و اسناد.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/receipt_view.dart';
import 'entry_editor.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.entryId});
  final String entryId;

  static Future<void> open(BuildContext context, String id) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryDetailPage(entryId: id)));

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = s.entries.where((x) => x.id == widget.entryId).firstOrNull;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.delete_outline, title: 'این هزینه حذف شده است'),
      );
    }
    final cat = categoryOf(e.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات هزینه'),
        actions: [
          IconButton(
            tooltip: 'ویرایش',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => EntryEditorPage.open(context, entry: e),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline, color: scheme.error),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'حذف هزینه', message: 'هزینهٔ «${e.title}» به مبلغ ${fmtMoney(e.amount, unit: s.unit)} حذف شود؟');
              if (!ok || !context.mounted) return;
              await s.deleteEntry(e);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryAvatar(e.category, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text(cat.label, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    SideBadge(e.side, 'پرداخت: ${s.nameOf(e.side)}'),
                    if (e.isProxy) SideBadge(e.buyer, 'خرید توسط ${s.nameOf(e.buyer)} (به نیابت)'),
                  ],
                ),
                const SizedBox(height: 14),
                if (e.isAdjusted) ...[
                  Text('معادل امروز — منظورشده در حساب', style: text.labelMedium?.copyWith(color: Palette.amber)),
                  AnimatedAmount(e.effectiveAmount, unit: s.unit, size: 30, color: Palette.amber),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('پرداختی واقعی: ', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(fmtMoney(e.amount, unit: s.unit), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text(
                        '(${e.adjustedAmount! >= e.amount ? '+' : '−'}${fmtPercent((e.adjustedAmount! - e.amount).abs() / (e.amount == 0 ? 1 : e.amount))})',
                        style: text.bodySmall?.copyWith(color: Palette.amber),
                      ),
                    ],
                  ),
                ] else ...[
                  AnimatedAmount(e.amount, unit: s.unit, size: 32),
                  const SizedBox(height: 4),
                  Text(moneyToWords(e.amount, unit: s.unit), style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _row(context, Icons.calendar_month_outlined, 'تاریخ', fmtDateWithWeekday(e.paidAt)),
                _row(context, Icons.schedule_outlined, 'ساعت', fmtTime(e.paidAt)),
                _row(context, e.method.icon, 'روش پرداخت', e.method.label),
                if (e.note.isNotEmpty) _row(context, Icons.notes_outlined, 'توضیح', e.note),
                _row(context, Icons.history_outlined, 'ثبت در اپ', '${fmtDateTime(e.createdAt)}${e.updatedAt != null ? ' (ویرایش: ${timeAgo(e.updatedAt!)})' : ''}'),
                if (e.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 16, color: Palette.amber),
                        const SizedBox(width: 6),
                        Text('هنوز به سرور ارسال نشده (آفلاین)', style: text.labelMedium?.copyWith(color: Palette.amber)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (e.attachments.isNotEmpty) ...[
            SectionTitle('رسیدها و اسناد (${faDigits(e.attachments.length)})'),
            for (final a in e.attachments) ...[
              _AttachmentCard(entry: e, attachment: a),
              const SizedBox(height: 10),
            ],
          ] else
            Panel(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text('این هزینه رسید ندارد.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
                  TextButton(
                    onPressed: () => EntryEditorPage.open(context, entry: e),
                    child: const Text('افزودن رسید'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(label, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  const _AttachmentCard({required this.entry, required this.attachment});
  final Entry entry;
  final Attachment attachment;
  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  Future<Uint8List?>? _full;

  @override
  void initState() {
    super.initState();
    _full = context.read<AppState>().getReceipt(widget.attachment.id);
  }

  Future<void> _share() async {
    final bytes = await _full;
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/receipt-${widget.attachment.id}.jpg');
    await f.writeAsBytes(bytes, flush: true);
    final s = context.read<AppState>();
    final e = widget.entry;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'image/jpeg')],
      text: '${widget.attachment.label} — ${e.title} — ${fmtMoney(e.amount, unit: s.unit)} — ${fmtDate(e.paidAt)}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = widget.attachment;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(a.label, style: text.titleSmall)),
                IconButton(tooltip: 'اشتراک‌گذاری', icon: const Icon(Icons.ios_share, size: 20), onPressed: _share),
              ],
            ),
          ),
          FullReceiptImage(
            receiptId: a.id,
            thumb: a.thumb,
            fit: BoxFit.fitWidth,
            onTap: () async {
              final bytes = await _full;
              if (bytes != null && context.mounted) _openViewer(context, bytes, a.id);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(child: Text('کیفیت کامل · برای زوم بیشتر روی تصویر بزنید', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant))),
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, Uint8List bytes, String id) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => ReceiptViewer(bytes: bytes, tag: 'receipt-$id'),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}

/// نمایش تمام‌صفحهٔ یک تصویر با بزرگ‌نمایی.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({super.key, required this.bytes, required this.tag, this.title = 'رسید'});
  final Uint8List bytes;
  final String tag;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 6,
            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }
}
