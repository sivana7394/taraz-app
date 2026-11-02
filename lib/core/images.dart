// پردازش عکس رسید: چرخش درست، کوچک‌سازی و ساخت بندانگشتی — در isolate جدا.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ProcessedImage {
  final Uint8List full;
  final Uint8List thumb;
  final int width;
  final int height;
  const ProcessedImage(this.full, this.thumb, this.width, this.height);
}

/// حداکثر حجم رسید کامل (بایت) — زیر سقف ۱ مگابایت Firestore.
const maxReceiptBytes = 640 * 1024;

Future<ProcessedImage> processReceipt(Uint8List bytes) =>
    compute(_process, bytes);

ProcessedImage _process(Uint8List bytes) {
  var im = img.decodeImage(bytes);
  if (im == null) throw const FormatException('فرمت عکس پشتیبانی نمی‌شود');
  im = img.bakeOrientation(im);

  im = _fit(im, 1400);
  var quality = 82;
  var full = img.encodeJpg(im, quality: quality);
  while (full.length > maxReceiptBytes && quality > 40) {
    quality -= 10;
    full = img.encodeJpg(im, quality: quality);
  }
  if (full.length > maxReceiptBytes) {
    im = _fit(im, 1000);
    full = img.encodeJpg(im, quality: 60);
  }

  final th = _fit(im, 192);
  final thumb = img.encodeJpg(th, quality: 62);
  return ProcessedImage(
    Uint8List.fromList(full),
    Uint8List.fromList(thumb),
    im.width,
    im.height,
  );
}

img.Image _fit(img.Image im, int maxSide) {
  final longest = im.width > im.height ? im.width : im.height;
  if (longest <= maxSide) return im;
  if (im.width >= im.height) {
    return img.copyResize(im, width: maxSide, interpolation: img.Interpolation.average);
  }
  return img.copyResize(im, height: maxSide, interpolation: img.Interpolation.average);
}

/// یک تصویر رسیدِ ساختگی برای حالت نمایشی می‌سازد.
Uint8List demoReceipt(int seed) {
  final im = img.Image(width: 480, height: 720);
  img.fill(im, color: img.ColorRgb8(250, 250, 248));
  img.fillRect(im, x1: 0, y1: 0, x2: 479, y2: 70, color: img.ColorRgb8(15, 118, 110));
  var y = 110;
  final r = seed * 2654435761 % 7;
  for (var i = 0; i < 14; i++) {
    final w = 200 + ((i * 53 + r * 17) % 220);
    img.fillRect(im, x1: 40, y1: y, x2: 40 + w, y2: y + 10, color: img.ColorRgb8(200, 200, 196));
    img.fillRect(im, x1: 360, y1: y, x2: 440, y2: y + 10, color: img.ColorRgb8(150, 150, 146));
    y += 34;
  }
  img.fillRect(im, x1: 40, y1: 620, x2: 440, y2: 624, color: img.ColorRgb8(15, 118, 110));
  img.fillRect(im, x1: 240, y1: 650, x2: 440, y2: 668, color: img.ColorRgb8(60, 60, 58));
  return Uint8List.fromList(img.encodeJpg(im, quality: 70));
}
