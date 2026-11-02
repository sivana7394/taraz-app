// جزئیات یک هزینه + نمایش رسید.
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
  Future<Uint8List?>? _receipt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<AppState>();
    final e = s.entries.where((x) => x.id == widget.entryId).firstOrNull;
    if (e != null && e.hasReceipt && _receipt == null) {
      _receipt = s.getReceipt(e.id);
    }
  }

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
    final canEdit = s.canEdit(e);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات هزینه'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'ویرایش',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await EntryEditorPage.open(context, entry: e);
                if (changed == true && mounted) setState(() => _receipt = null);
              },
            ),
          if (canEdit)
            IconButton(
              tooltip: 'حذف',
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'حذف هزینه', message: 'هزینهٔ «${e.title}» به مبلغ ${fmtMoney(e.amount, unit: s.unit)} حذف شود؟');
                if (!ok || !context.mounted) return;
                await s.deleteEntry(e.id);
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
                    SideBadge(e.side, s.nameOf(e.side)),
                  ],
                ),
                const SizedBox(height: 18),
                AnimatedAmount(e.amount, unit: s.unit, size: 32),
                const SizedBox(height: 4),
                Text(moneyToWords(e.amount, unit: s.unit), style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
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
          if (e.hasReceipt) ...[
            SectionTitle('رسید', action: 'اشتراک‌گذاری', onAction: () => _share(e)),
            FutureBuilder<Uint8List?>(
              future: _receipt,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Panel(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 260,
                      child: Center(
                        child: e.thumb != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(e.thumb!, fit: BoxFit.cover),
                                  Container(color: Colors.black26),
                                  const Center(child: CircularProgressIndicator(color: Colors.white)),
                                ],
                              )
                            : const CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final bytes = snap.data;
                if (bytes == null) {
                  return const Panel(child: Text('رسید در دسترس نیست (شاید هنوز از دستگاه ثبت‌کننده ارسال نشده).'));
                }
                return Panel(
                  padding: EdgeInsets.zero,
                  child: GestureDetector(
                    onTap: () => _openViewer(context, bytes, e.id),
                    child: Hero(
                      tag: 'receipt-${e.id}',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, gaplessPlayback: true),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('برای بزرگ‌نمایی روی تصویر بزنید', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ] else
            Panel(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text('این هزینه رسید ندارد.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
                  if (canEdit)
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

  Future<void> _share(Entry e) async {
    final bytes = await _receipt;
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/receipt-${e.id}.jpg');
    await f.writeAsBytes(bytes, flush: true);
    final s = context.read<AppState>();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'image/jpeg')],
      text: '${e.title} — ${fmtMoney(e.amount, unit: s.unit)} — ${fmtDate(e.paidAt)}',
    ));
  }

  void _openViewer(BuildContext context, Uint8List bytes, String id) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _ReceiptViewer(bytes: bytes, tag: 'receipt-$id'),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}

class _ReceiptViewer extends StatelessWidget {
  const _ReceiptViewer({required this.bytes, required this.tag});
  final Uint8List bytes;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('رسید', style: TextStyle(color: Colors.white)),
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
