// خروجی CSV (اکسل) و PDF.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/fa.dart';
import 'models.dart';
import 'stats.dart';

class Exporter {
  Exporter({required this.config, required this.unit});
  final RoomConfig config;
  final MoneyUnit unit;

  int _v(int toman) => unit == MoneyUnit.rial ? toman * 10 : toman;

  /// CSV سازگار با اکسل (UTF-8 با BOM). مبالغ با ارقام لاتین برای محاسبه.
  String csv(List<Entry> entries, {List<Settlement> settlements = const []}) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final sb = StringBuffer('﻿');
    sb.writeln(['ردیف', 'تاریخ', 'ساعت', 'طرف', 'موضوع', 'دسته', 'مبلغ (${unit.label})', 'روش پرداخت', 'رسید', 'توضیح'].map(q).join(','));
    var i = 1;
    for (final e in entries) {
      sb.writeln([
        q('${i++}'),
        q(enDigits(fmtDateNumeric(e.paidAt))),
        q(enDigits(fmtTime(e.paidAt))),
        q(config.sideName(e.side)),
        q(e.title),
        q(categoryOf(e.category).label),
        _v(e.amount).toString(),
        q(e.method.label),
        q(e.hasReceipt ? 'دارد' : 'ندارد'),
        q(e.note),
      ].join(','));
    }
    if (settlements.isNotEmpty) {
      sb.writeln();
      sb.writeln(['تسویه‌ها', 'تاریخ', 'از', 'به', 'مبلغ (${unit.label})', 'توضیح'].map(q).join(','));
      for (final s in settlements) {
        sb.writeln([q(''), q(enDigits(fmtDateNumeric(s.paidAt))), q(config.sideName(s.from)), q(config.sideName(s.to)), _v(s.amount).toString(), q(s.note)].join(','));
      }
    }
    return sb.toString();
  }

  Future<File> writeCsv(String content, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name.csv');
    await f.writeAsString(content, flush: true);
    return f;
  }

  /// صورت‌حساب PDF راست‌به‌چپ.
  Future<Uint8List> pdf({
    required List<Entry> entries,
    required Stats stats,
    required String periodLabel,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final doc = pw.Document(title: 'صورت‌حساب ${config.name}', author: 'تراز');
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final grey = PdfColor.fromHex('#6B7280');
    final teal = PdfColor.fromHex('#0F766E');
    final aColor = PdfColor.fromHex('#2563EB');
    final bColor = PdfColor.fromHex('#EA580C');

    pw.Widget cell(String t, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.right, double size = 9}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t, textAlign: align, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        );

    pw.Widget kv(String k, String v, {PdfColor? color}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(fontSize: 10, color: grey)),
            pw.Text(v, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        );

    doc.addPage(pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('صورت‌حساب ${config.name}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: teal)),
            pw.Text('بازه: $periodLabel · ${fmtDate(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: grey)),
          ],
        ),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('تراز — صفحهٔ ${faDigits(ctx.pageNumber)} از ${faDigits(ctx.pagesCount)}', style: pw.TextStyle(fontSize: 8, color: grey)),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            children: [
              kv('جمع هزینه‌های این بازه', fmtMoney(stats.total, unit: unit)),
              pw.SizedBox(height: 3),
              kv('پرداختی ${config.sideAName} (این بازه)', fmtMoney(stats.spentA, unit: unit), color: aColor),
              pw.SizedBox(height: 3),
              kv('پرداختی ${config.sideBName} (این بازه)', fmtMoney(stats.spentB, unit: unit), color: bColor),
              pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
              kv('کل هزینه‌های پروژه (از ابتدا)', fmtMoney(stats.allTotal, unit: unit)),
              pw.SizedBox(height: 3),
              kv('سهم ${config.sideAName} (${faDigits(config.shareA)} دانگ) / سهم ${config.sideBName} (${faDigits(config.shareB)} دانگ)', '${fmtMoney(stats.fairA, unit: unit)} / ${fmtMoney(stats.fairB, unit: unit)}'),
              pw.SizedBox(height: 3),
              kv(
                'تراز',
                stats.debtor == null
                    ? 'حساب‌ها تراز است'
                    : '${config.sideName(stats.debtor!)} باید ${fmtMoney(stats.owed, unit: unit)} به ${config.sideName(stats.creditor!)} بپردازد',
                color: teal,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('ریز هزینه‌ها (${faDigits(entries.length)} مورد)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),
            1: const pw.FixedColumnWidth(62),
            2: const pw.FixedColumnWidth(44),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FixedColumnWidth(78),
            6: const pw.FixedColumnWidth(34),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3F4F6')),
              children: [
                cell('#', bold: true),
                cell('تاریخ', bold: true),
                cell('طرف', bold: true),
                cell('موضوع', bold: true),
                cell('دسته', bold: true),
                cell('مبلغ (${unit.label})', bold: true),
                cell('رسید', bold: true),
              ],
            ),
            for (var i = 0; i < entries.length; i++)
              pw.TableRow(
                children: [
                  cell(faDigits(i + 1)),
                  cell(fmtDateNumeric(entries[i].paidAt)),
                  cell(config.sideName(entries[i].side), color: entries[i].side == Side.a ? aColor : bColor, bold: true),
                  cell(entries[i].title),
                  cell(categoryOf(entries[i].category).label, color: grey),
                  cell(fmtMoney(entries[i].amount, unit: unit, withUnit: false), bold: true),
                  cell(entries[i].hasReceipt ? 'دارد' : 'ندارد', align: pw.TextAlign.center, size: 8),
                ],
              ),
          ],
        ),
        if (stats.byCategory.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('جمع بر اساس دسته', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3F4F6')),
                children: [cell('دسته', bold: true), cell('مبلغ', bold: true), cell('درصد', bold: true), cell('تعداد', bold: true)],
              ),
              for (final c in stats.byCategory)
                pw.TableRow(children: [
                  cell(categoryOf(c.key).label),
                  cell(fmtMoney(c.amount, unit: unit, withUnit: false), bold: true),
                  cell(fmtPercent(stats.total == 0 ? 0 : c.amount / stats.total)),
                  cell(faDigits(c.count)),
                ]),
            ],
          ),
        ],
      ],
    ));
    return doc.save();
  }

  Future<File> writePdf(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name.pdf');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }
}
