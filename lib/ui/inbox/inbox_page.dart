// صندوق رسیدها: عکس‌هایی که Share شده یا گرفته شده‌اند و هنوز به هزینه تبدیل نشده‌اند.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../entries/entry_detail.dart';
import '../entries/entry_editor.dart';
import '../widgets/common.dart';
import '../widgets/receipt_view.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxPage()));

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  bool _busy = false;

  Future<void> _add(ImageSource src) async {
    final s = context.read<AppState>();
    try {
      setState(() => _busy = true);
      if (src == ImageSource.gallery) {
        final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 88, limit: 10);
        for (final x in xs) {
          await s.addInboxImage(await x.readAsBytes());
        }
      } else {
        final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
        if (x != null) await s.addInboxImage(await x.readAsBytes());
      }
    } catch (e) {
      if (mounted) toast(context, 'افزودن عکس انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = s.inbox;

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق رسیدها'),
        actions: [
          if (_busy || s.ingesting)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'عکس رسید را از گالری یا هر برنامه‌ای «Share ← تراز» کنید تا این‌جا بنشیند. رسیدها با کیفیت کامل نمایش داده می‌شوند؛ هنگام ثبت هزینه هم بالای فرم می‌مانند تا تاریخ و مبلغ را از رویشان بخوانید.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'صندوق خالی است',
                    subtitle: 'عکس رسیدها را از گالری Share کنید یا همین‌جا عکس بگیرید.',
                    action: FilledButton.icon(onPressed: () => _add(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('عکس رسید')),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _InboxCard(item: items[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'inbox-gallery',
            tooltip: 'از گالری',
            onPressed: _busy ? null : () => _add(ImageSource.gallery),
            child: const Icon(Icons.photo_library_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'inbox-camera',
            onPressed: _busy ? null : () => _add(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('عکس رسید'),
          ),
        ],
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxH = MediaQuery.of(context).size.height * 0.72;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // تصویر با کیفیت کامل، تمام‌عرض (لمس = تمام‌صفحه با زوم)
          FullReceiptImage(
            receiptId: item.id,
            thumb: item.thumb,
            maxHeight: maxH,
            fit: BoxFit.contain,
            onTap: () async {
              final bytes = await s.getReceipt(item.id);
              if (bytes != null && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptViewer(bytes: bytes, tag: 'inbox-${item.id}')));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(timeAgo(item.createdAt), style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (item.pending) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.cloud_upload_outlined, size: 14, color: scheme.onSurfaceVariant),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'حذف از صندوق',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: 'حذف رسید', message: 'این رسید از صندوق حذف شود؟');
                    if (ok) await s.deleteInbox(item.id);
                  },
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => EntryEditorPage.open(context, inboxItem: item),
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('ثبت هزینه'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بندانگشتی کوچک برای کارت صندوق در داشبورد.
class InboxThumbStrip extends StatelessWidget {
  const InboxThumbStrip({super.key, required this.items});
  final List<InboxItem> items;
  @override
  Widget build(BuildContext context) {
    final show = items.take(4).toList();
    return Row(
      children: [
        for (final it in show)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: it.thumb != null ? Image.memory(it.thumb!, fit: BoxFit.cover) : const Icon(Icons.receipt_long_outlined),
              ),
            ),
          ),
        if (items.length > 4) Text('+${faDigits(items.length - 4)}', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
