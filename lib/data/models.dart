// مدل‌های دادهٔ اپ «تراز».
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// دو طرف مشارکت: a = مالک اپ (شما)، b = شرکا.
enum Side { a, b }

extension SideX on Side {
  String get key => name;
  Side get other => this == Side.a ? Side.b : Side.a;
  static Side fromKey(String? k) => k == 'b' ? Side.b : Side.a;
}

/// روش پرداخت.
enum PayMethod { cash, card, transfer, cheque }

extension PayMethodX on PayMethod {
  String get label => switch (this) {
        PayMethod.cash => 'نقد',
        PayMethod.card => 'کارت‌به‌کارت',
        PayMethod.transfer => 'انتقال بانکی',
        PayMethod.cheque => 'چک',
      };
  IconData get icon => switch (this) {
        PayMethod.cash => Icons.payments_outlined,
        PayMethod.card => Icons.credit_card,
        PayMethod.transfer => Icons.account_balance_outlined,
        PayMethod.cheque => Icons.receipt_long_outlined,
      };
  String get key => name;
  static PayMethod fromKey(String? k) =>
      PayMethod.values.firstWhere((m) => m.name == k, orElse: () => PayMethod.card);
}

/// دسته‌بندی هزینه.
class Category {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const Category(this.key, this.label, this.icon, this.color);
}

const categories = <Category>[
  Category('materials', 'مصالح ساختمانی', Icons.foundation, Color(0xFF0E7490)),
  Category('labor', 'دستمزد و اجرا', Icons.engineering_outlined, Color(0xFFB45309)),
  Category('transport', 'حمل‌ونقل', Icons.local_shipping_outlined, Color(0xFF4D7C0F)),
  Category('machinery', 'ماشین‌آلات و اجاره', Icons.precision_manufacturing_outlined, Color(0xFF6D28D9)),
  Category('permits', 'مجوز، عوارض و بیمه', Icons.account_balance_outlined, Color(0xFFBE185D)),
  Category('utilities', 'تأسیسات (برق، آب، گاز)', Icons.electrical_services_outlined, Color(0xFF0369A1)),
  Category('design', 'طراحی و نظارت', Icons.architecture_outlined, Color(0xFF15803D)),
  Category('finishing', 'نازک‌کاری و نما', Icons.format_paint_outlined, Color(0xFFC2410C)),
  Category('misc', 'متفرقه', Icons.more_horiz, Color(0xFF52525B)),
];

Category categoryOf(String key) =>
    categories.firstWhere((c) => c.key == key, orElse: () => categories.last);

/// تنظیمات مشترک پروژه (در Firestore: rooms/{roomId}).
class RoomConfig {
  final String name;
  final String sideAName;
  final String sideBName;
  final int shareA; // دانگ
  final int shareB; // دانگ
  final DateTime? createdAt;

  const RoomConfig({
    this.name = 'پروژهٔ ساخت',
    this.sideAName = 'من',
    this.sideBName = 'شرکا',
    this.shareA = 3,
    this.shareB = 3,
    this.createdAt,
  });

  double get ratioA => shareA / (shareA + shareB);
  double get ratioB => shareB / (shareA + shareB);

  String sideName(Side s) => s == Side.a ? sideAName : sideBName;
  int share(Side s) => s == Side.a ? shareA : shareB;

  RoomConfig copyWith({
    String? name,
    String? sideAName,
    String? sideBName,
    int? shareA,
    int? shareB,
  }) =>
      RoomConfig(
        name: name ?? this.name,
        sideAName: sideAName ?? this.sideAName,
        sideBName: sideBName ?? this.sideBName,
        shareA: shareA ?? this.shareA,
        shareB: shareB ?? this.shareB,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sideAName': sideAName,
        'sideBName': sideBName,
        'shareA': shareA,
        'shareB': shareB,
      };

  static RoomConfig fromMap(Map<String, dynamic>? m, {DateTime? createdAt}) {
    if (m == null) return const RoomConfig();
    return RoomConfig(
      name: (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : 'پروژهٔ ساخت',
      sideAName: (m['sideAName'] as String?) ?? 'من',
      sideBName: (m['sideBName'] as String?) ?? 'شرکا',
      shareA: ((m['shareA'] as num?)?.toInt() ?? 3).clamp(1, 6).toInt(),
      shareB: ((m['shareB'] as num?)?.toInt() ?? 3).clamp(1, 6).toInt(),
      createdAt: createdAt,
    );
  }
}

/// یک هزینهٔ ثبت‌شده.
class Entry {
  final String id;
  final Side side;
  final int amount; // تومان
  final String title;
  final String category;
  final DateTime paidAt;
  final String note;
  final PayMethod method;
  final bool hasReceipt;
  final Uint8List? thumb;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool deleted;
  /// هنوز به سرور نرسیده (نوشتهٔ محلی در انتظار).
  final bool pending;

  const Entry({
    required this.id,
    required this.side,
    required this.amount,
    required this.title,
    required this.category,
    required this.paidAt,
    this.note = '',
    this.method = PayMethod.card,
    this.hasReceipt = false,
    this.thumb,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
    this.pending = false,
  });

  Entry copyWith({
    Side? side,
    int? amount,
    String? title,
    String? category,
    DateTime? paidAt,
    String? note,
    PayMethod? method,
    bool? hasReceipt,
    Uint8List? thumb,
    bool clearThumb = false,
    DateTime? updatedAt,
    bool? deleted,
    bool? pending,
  }) =>
      Entry(
        id: id,
        side: side ?? this.side,
        amount: amount ?? this.amount,
        title: title ?? this.title,
        category: category ?? this.category,
        paidAt: paidAt ?? this.paidAt,
        note: note ?? this.note,
        method: method ?? this.method,
        hasReceipt: hasReceipt ?? this.hasReceipt,
        thumb: clearThumb ? null : (thumb ?? this.thumb),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        pending: pending ?? this.pending,
      );
}

/// پرداخت تسویه بین دو طرف.
class Settlement {
  final String id;
  final Side from;
  final Side to;
  final int amount;
  final DateTime paidAt;
  final String note;
  final DateTime createdAt;
  final bool deleted;
  final bool pending;

  const Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.paidAt,
    this.note = '',
    required this.createdAt,
    this.deleted = false,
    this.pending = false,
  });
}

/// وضعیت همگام‌سازی.
enum SyncState { connecting, online, offline, pending, demo }

class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final DateTime? lastSynced;
  const SyncStatus(this.state, {this.pendingCount = 0, this.lastSynced});

  String get label => switch (state) {
        SyncState.connecting => 'در حال اتصال…',
        SyncState.online => 'همگام',
        SyncState.offline => 'آفلاین — ذخیرهٔ محلی',
        SyncState.pending => 'در انتظار ارسال',
        SyncState.demo => 'حالت نمایشی',
      };
}
