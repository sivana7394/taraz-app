// دریافت تصاویر Share شده از برنامه‌های دیگر (گالری، اسکرین‌شات، پیام‌رسان‌ها)
// و میانبرهای آیکون اپ — از طریق کانال بومی ir.sivan.taraz/share (MainActivity.kt).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharePayload {
  /// مسیر فایل‌های تصویری کپی‌شده در حافظهٔ موقت اپ.
  final List<String> paths;
  /// میانبر: 'add' (ثبت سریع هزینه) یا 'receipt' (عکس رسید) — یا خالی.
  final String shortcut;
  const SharePayload({this.paths = const [], this.shortcut = ''});
  bool get isEmpty => paths.isEmpty && shortcut.isEmpty;
}

class ShareReceiver {
  ShareReceiver._();
  static final ShareReceiver instance = ShareReceiver._();

  static const _channel = MethodChannel('ir.sivan.taraz/share');
  final _ctrl = StreamController<SharePayload>.broadcast();
  bool _started = false;

  Stream<SharePayload> get stream => _ctrl.stream;

  /// شروع گوش‌دادن و خواندن داده‌ای که اپ با آن باز شده (cold start).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final p = _parse(call.arguments);
        if (!p.isEmpty) _ctrl.add(p);
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<dynamic>('getInitialShare');
      final p = _parse(initial);
      if (!p.isEmpty) _ctrl.add(p);
    } on MissingPluginException {
      // روی پلتفرم‌های بدون کانال بومی (تست/دسکتاپ) نادیده گرفته می‌شود
    } catch (e) {
      debugPrint('share init failed: $e');
    }
  }

  SharePayload _parse(dynamic args) {
    if (args is Map) {
      final paths = (args['paths'] as List?)?.whereType<String>().toList() ?? const <String>[];
      final shortcut = (args['shortcut'] as String?) ?? '';
      return SharePayload(paths: paths, shortcut: shortcut);
    }
    if (args is List) return SharePayload(paths: args.whereType<String>().toList());
    return const SharePayload();
  }
}
