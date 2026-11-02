// نمایش رسید با کیفیت کامل: در فهرست‌ها (تمام‌عرض) و در پنل بالای فرم (زوم و جابه‌جایی).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';

/// تصویر کامل یک پیوست/رسید را از حافظه یا سرور می‌آورد و با کیفیت کامل، تمام‌عرض نشان می‌دهد.
/// تا رسیدن تصویر کامل، بندانگشتی (تار) نمایش داده می‌شود.
class FullReceiptImage extends StatefulWidget {
  const FullReceiptImage({
    super.key,
    required this.receiptId,
    this.bytes,
    this.thumb,
    this.maxHeight,
    this.fit = BoxFit.fitWidth,
    this.onTap,
  });
  final String receiptId;
  /// اگر تصویر کامل همین حالا در دست باشد (مثلاً عکس تازه‌گرفته‌شده).
  final Uint8List? bytes;
  final Uint8List? thumb;
  final double? maxHeight;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  State<FullReceiptImage> createState() => _FullReceiptImageState();
}

class _FullReceiptImageState extends State<FullReceiptImage> {
  Uint8List? _full;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _full = widget.bytes;
    if (_full == null) _load();
  }

  @override
  void didUpdateWidget(covariant FullReceiptImage old) {
    super.didUpdateWidget(old);
    if (old.receiptId != widget.receiptId || (widget.bytes != null && widget.bytes != _full)) {
      _full = widget.bytes;
      _failed = false;
      if (_full == null) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await context.read<AppState>().getReceipt(widget.receiptId);
      if (!mounted) return;
      setState(() {
        _full = b;
        _failed = b == null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _full ?? widget.thumb;
    Widget child;
    if (bytes == null) {
      child = Container(
        height: 180,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 6),
                  Text('تصویر هنوز نرسیده', style: Theme.of(context).textTheme.labelMedium),
                  TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
                ],
              )
            : const CircularProgressIndicator(),
      );
    } else {
      child = Stack(
        alignment: Alignment.center,
        children: [
          Image.memory(
            bytes,
            fit: widget.fit,
            width: double.infinity,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
          if (_loading && _full == null)
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('در حال آوردن کیفیت کامل…', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    if (widget.maxHeight != null) {
      child = ConstrainedBox(constraints: BoxConstraints(maxHeight: widget.maxHeight!), child: child);
    }
    if (widget.onTap != null) {
      child = GestureDetector(onTap: widget.onTap, child: child);
    }
    return child;
  }
}

/// یک آیتم برای پنل رسید.
class ReceiptPaneItem {
  final String id;
  final String label;
  final Uint8List? bytes;
  final Uint8List? thumb;
  const ReceiptPaneItem({required this.id, required this.label, this.bytes, this.thumb});
}

/// پنل رسید در بالای فرم: قابل زوم و جابه‌جایی، با دستهٔ تغییر ارتفاع و دکمهٔ جمع‌کردن.
class ReceiptPane extends StatefulWidget {
  const ReceiptPane({
    super.key,
    required this.items,
    required this.height,
    required this.onHeightChanged,
    required this.collapsed,
    required this.onToggle,
    this.onFullscreen,
  });
  final List<ReceiptPaneItem> items;
  final double height;
  final ValueChanged<double> onHeightChanged;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(ReceiptPaneItem item)? onFullscreen;

  @override
  State<ReceiptPane> createState() => _ReceiptPaneState();
}

class _ReceiptPaneState extends State<ReceiptPane> {
  int _index = 0;
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final idx = _index.clamp(0, widget.items.length - 1);
    final item = widget.items[idx];

    if (widget.collapsed) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: InkWell(
          onTap: widget.onToggle,
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.receipt_long_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('نمایش رسید (${widget.items.length == 1 ? item.label : '${widget.items.length} سند'})', style: text.labelLarge)),
                const Icon(Icons.expand_more),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF111416),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 6,
                      child: Center(
                        child: FullReceiptImage(
                          key: ValueKey(item.id),
                          receiptId: item.id,
                          bytes: item.bytes,
                          thumb: item.thumb,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  // نوار بالای تصویر: برچسب، شمارنده، تمام‌صفحه، جمع‌کردن
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    end: 6,
                    child: Row(
                      children: [
                        _Pill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              if (widget.items.length > 1) ...[
                                const SizedBox(width: 6),
                                Text('${_fa(idx + 1)}/${_fa(widget.items.length)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.items.length > 1) ...[
                          _IconPill(icon: Icons.chevron_right, onTap: () => setState(() => _index = (idx - 1 + widget.items.length) % widget.items.length)),
                          const SizedBox(width: 4),
                          _IconPill(icon: Icons.chevron_left, onTap: () => setState(() => _index = (idx + 1) % widget.items.length)),
                          const SizedBox(width: 4),
                        ],
                        _IconPill(icon: Icons.center_focus_weak, onTap: () => _transform.value = Matrix4.identity()),
                        const SizedBox(width: 4),
                        if (widget.onFullscreen != null) ...[
                          _IconPill(icon: Icons.fullscreen, onTap: () => widget.onFullscreen!(item)),
                          const SizedBox(width: 4),
                        ],
                        _IconPill(icon: Icons.expand_less, onTap: widget.onToggle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // دستهٔ تغییر ارتفاع
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => widget.onHeightChanged(widget.height + d.delta.dy),
            child: Container(
              height: 18,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ],
      ),
    );
  }

  static String _fa(int n) => n.toString().replaceAllMapped(RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
        child: child,
      );
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: Colors.white)),
        ),
      );
}
