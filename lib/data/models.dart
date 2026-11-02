// مدل‌های دادهٔ اپ «تراز».
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// دو طرف مشارکت: a = سیوان، b = شرکا.
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

/// برچسب‌های پیشنهادی برای پیوست‌ها.
const attachmentLabels = <String>['رسید خرید', 'فاکتور', 'رسید واریز', 'سند قیمت روز', 'سایر'];

/// نام‌های پیش‌فرض طرف‌ها.
const defaultSideAName = 'سیوان';
const defaultSideBName = 'شرکا (طرف نوری)';

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
    this.sideAName = defaultSideAName,
    this.sideBName = defaultSideBName,
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
    String name(String? v, String fallback) {
      final t = v?.trim() ?? '';
      // نام‌های پیش‌فرض نسخهٔ قبلی به نام‌های جدید تبدیل می‌شوند
      if (t.isEmpty || t == 'من' || t == 'شرکا') return fallback;
      return t;
    }

    return RoomConfig(
      name: (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : 'پروژهٔ ساخت',
      sideAName: name(m['sideAName'] as String?, defaultSideAName),
      sideBName: name(m['sideBName'] as String?, defaultSideBName),
      shareA: ((m['shareA'] as num?)?.toInt() ?? 3).clamp(1, 6).toInt(),
      shareB: ((m['shareB'] as num?)?.toInt() ?? 3).clamp(1, 6).toInt(),
      createdAt: createdAt,
    );
  }
}

/// پیوست (رسید/سند) یک هزینه. تصویر کامل در receipts/{id} ذخیره می‌شود.
class Attachment {
  final String id;
  final String label;
  final Uint8List? thumb;
  const Attachment({required this.id, this.label = 'رسید خرید', this.thumb});

  Attachment copyWith({String? label, Uint8List? thumb}) =>
      Attachment(id: id, label: label ?? this.label, thumb: thumb ?? this.thumb);
}

/// یک هزینهٔ ثبت‌شده.
class Entry {
  final String id;
  /// پول از جیب چه کسی رفته (برای محاسبهٔ سهم‌ها).
  final Side side;
  /// چه کسی خرید را انجام داده (پیش‌فرض: همان پرداخت‌کننده).
  final Side buyer;
  /// مبلغ واقعاً پرداخت‌شده (تومان).
  final int amount;
  /// معادل امروز (قیمت روز) — اگر تعیین شده باشد، در حساب‌وکتاب همین منظور می‌شود.
  final int? adjustedAmount;
  final String title;
  final String category;
  final DateTime paidAt;
  final String note;
  final PayMethod method;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  /// شناسهٔ دستگاهی که این مورد را ثبت کرده.
  final String createdBy;
  final bool deleted;
  /// هنوز به سرور نرسیده (نوشتهٔ محلی در انتظار).
  final bool pending;

  const Entry({
    required this.id,
    required this.side,
    Side? buyer,
    required this.amount,
    this.adjustedAmount,
    required this.title,
    required this.category,
    required this.paidAt,
    this.note = '',
    this.method = PayMethod.card,
    this.attachments = const [],
    required this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.deleted = false,
    this.pending = false,
  }) : buyer = buyer ?? side;

  /// مبلغی که در حساب‌وکتاب منظور می‌شود.
  int get effectiveAmount => adjustedAmount ?? amount;
  bool get isAdjusted => adjustedAmount != null && adjustedAmount != amount;
  bool get hasReceipt => attachments.isNotEmpty;
  Uint8List? get thumb => attachments.isEmpty ? null : attachments.first.thumb;
  /// خرید به نیابت: پول از یک طرف، خرید توسط طرف دیگر.
  bool get isProxy => buyer != side;

  Entry copyWith({
    Side? side,
    Side? buyer,
    int? amount,
    int? adjustedAmount,
    bool clearAdjusted = false,
    String? title,
    String? category,
    DateTime? paidAt,
    String? note,
    PayMethod? method,
    List<Attachment>? attachments,
    DateTime? updatedAt,
    String? createdBy,
    bool? deleted,
    bool? pending,
  }) =>
      Entry(
        id: id,
        side: side ?? this.side,
        buyer: buyer ?? this.buyer,
        amount: amount ?? this.amount,
        adjustedAmount: clearAdjusted ? null : (adjustedAmount ?? this.adjustedAmount),
        title: title ?? this.title,
        category: category ?? this.category,
        paidAt: paidAt ?? this.paidAt,
        note: note ?? this.note,
        method: method ?? this.method,
        attachments: attachments ?? this.attachments,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
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

/// رسیدِ دریافتی که هنوز به هزینه تبدیل نشده (صندوق رسیدها).
class InboxItem {
  final String id;
  final Uint8List? thumb;
  final DateTime createdAt;
  final String createdBy;
  final String note;
  final bool pending;
  const InboxItem({
    required this.id,
    this.thumb,
    required this.createdAt,
    this.createdBy = '',
    this.note = '',
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
