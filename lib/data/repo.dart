// لایهٔ داده: پیاده‌سازی Firestore (واقعی) و حالت نمایشی (در حافظه).
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/images.dart';
import 'models.dart';

/// یک «عکس لحظه‌ای» از فهرست همراه با وضعیت همگام‌سازی.
class ListSnap<T> {
  final List<T> items;
  final bool fromCache;
  final int pendingCount;
  const ListSnap(this.items, {this.fromCache = false, this.pendingCount = 0});
}

abstract class Repo {
  Stream<RoomConfig?> room();
  Stream<ListSnap<Entry>> entries();
  Stream<ListSnap<Settlement>> settlements();
  Stream<ListSnap<InboxItem>> inbox();

  String newId();

  /// ذخیرهٔ هزینه. [newReceipts] تصویر کامل پیوست‌های تازه (کلید = شناسهٔ پیوست)؛
  /// [removedReceiptIds] پیوست‌های حذف‌شده؛ [consumeInboxId] رسیدِ صندوق که به این هزینه تبدیل شده.
  Future<void> upsertEntry(
    Entry e, {
    Map<String, Uint8List> newReceipts = const {},
    List<String> removedReceiptIds = const [],
    String? consumeInboxId,
  });
  Future<void> deleteEntry(Entry e);
  Future<Uint8List?> getReceipt(String attachmentId);
  Future<void> upsertSettlement(Settlement s);
  Future<void> deleteSettlement(String id);
  Future<void> saveRoom(RoomConfig c, {bool create = false});

  Future<void> addInbox(InboxItem item, Uint8List full);
  Future<void> deleteInbox(String id);

  bool get isDemo;
  void dispose();
}

// ===========================================================================
// Firestore
// ===========================================================================
class FirestoreRepo implements Repo {
  FirestoreRepo(this.db, this.roomId);
  final FirebaseFirestore db;
  final String roomId;

  final _receiptCache = <String, Uint8List>{};

  DocumentReference<Map<String, dynamic>> get _room =>
      db.collection('rooms').doc(roomId);

  @override
  bool get isDemo => false;

  @override
  String newId() => _room.collection('entries').doc().id;

  @override
  Stream<RoomConfig?> room() => _room.snapshots(includeMetadataChanges: true).map((s) {
        if (!s.exists) return null;
        final m = s.data();
        return RoomConfig.fromMap(m, createdAt: (m?['createdAt'] as Timestamp?)?.toDate());
      });

  @override
  Stream<ListSnap<Entry>> entries() => _room
          .collection('entries')
          .orderBy('paidAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .map((q) {
        var pending = 0;
        final items = <Entry>[];
        for (final d in q.docs) {
          final m = d.data();
          if ((m['deleted'] as bool?) ?? false) continue;
          if (d.metadata.hasPendingWrites) pending++;
          items.add(_entryFrom(d.id, m, d.metadata.hasPendingWrites));
        }
        return ListSnap(items, fromCache: q.metadata.isFromCache, pendingCount: pending);
      });

  @override
  Stream<ListSnap<Settlement>> settlements() => _room
          .collection('settlements')
          .orderBy('paidAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .map((q) {
        var pending = 0;
        final items = <Settlement>[];
        for (final d in q.docs) {
          final m = d.data();
          if ((m['deleted'] as bool?) ?? false) continue;
          if (d.metadata.hasPendingWrites) pending++;
          items.add(Settlement(
            id: d.id,
            from: SideX.fromKey(m['from'] as String?),
            to: SideX.fromKey(m['to'] as String?),
            amount: (m['amount'] as num?)?.toInt() ?? 0,
            paidAt: _dt(m['paidAt']) ?? DateTime.now(),
            note: (m['note'] as String?) ?? '',
            createdAt: _dt(m['createdAt']) ?? DateTime.now(),
            pending: d.metadata.hasPendingWrites,
          ));
        }
        return ListSnap(items, fromCache: q.metadata.isFromCache, pendingCount: pending);
      });

  @override
  Stream<ListSnap<InboxItem>> inbox() => _room
          .collection('inbox')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .map((q) {
        var pending = 0;
        final items = <InboxItem>[];
        for (final d in q.docs) {
          final m = d.data();
          if (d.metadata.hasPendingWrites) pending++;
          items.add(InboxItem(
            id: d.id,
            thumb: (m['thumb'] as Blob?)?.bytes,
            createdAt: _dt(m['createdAt']) ?? DateTime.now(),
            createdBy: (m['createdBy'] as String?) ?? '',
            note: (m['note'] as String?) ?? '',
            pending: d.metadata.hasPendingWrites,
          ));
        }
        return ListSnap(items, fromCache: q.metadata.isFromCache, pendingCount: pending);
      });

  static DateTime? _dt(Object? v) => v is Timestamp ? v.toDate() : null;

  Entry _entryFrom(String id, Map<String, dynamic> m, bool pending) {
    var attachments = <Attachment>[];
    final raw = m['attachments'];
    if (raw is List) {
      for (final a in raw) {
        if (a is Map) {
          attachments.add(Attachment(
            id: (a['id'] as String?) ?? id,
            label: (a['label'] as String?) ?? 'رسید خرید',
            thumb: (a['thumb'] as Blob?)?.bytes,
          ));
        }
      }
    } else if ((m['hasReceipt'] as bool?) ?? false) {
      // سازگاری با نسخهٔ قبل: یک رسید با شناسهٔ خودِ هزینه
      attachments = [Attachment(id: id, label: 'رسید خرید', thumb: (m['thumb'] as Blob?)?.bytes)];
    }
    final side = SideX.fromKey(m['side'] as String?);
    return Entry(
      id: id,
      side: side,
      buyer: m['buyer'] == null ? side : SideX.fromKey(m['buyer'] as String?),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      adjustedAmount: (m['adjustedAmount'] as num?)?.toInt(),
      title: (m['title'] as String?) ?? '',
      category: (m['category'] as String?) ?? 'misc',
      paidAt: _dt(m['paidAt']) ?? DateTime.now(),
      note: (m['note'] as String?) ?? '',
      method: PayMethodX.fromKey(m['method'] as String?),
      attachments: attachments,
      createdAt: _dt(m['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(m['updatedAt']),
      createdBy: (m['createdBy'] as String?) ?? '',
      pending: pending,
    );
  }

  @override
  Future<void> upsertEntry(
    Entry e, {
    Map<String, Uint8List> newReceipts = const {},
    List<String> removedReceiptIds = const [],
    String? consumeInboxId,
  }) async {
    final batch = db.batch();
    final data = <String, dynamic>{
      'side': e.side.key,
      'buyer': e.buyer.key,
      'amount': e.amount,
      'adjustedAmount': e.adjustedAmount,
      'title': e.title,
      'category': e.category,
      'paidAt': Timestamp.fromDate(e.paidAt),
      'note': e.note,
      'method': e.method.key,
      'attachments': [
        for (final a in e.attachments)
          {'id': a.id, 'label': a.label, 'thumb': a.thumb == null ? null : Blob(a.thumb!)},
      ],
      // سازگاری با نسخهٔ قبل
      'hasReceipt': e.attachments.isNotEmpty,
      'thumb': e.thumb == null ? null : Blob(e.thumb!),
      'createdAt': Timestamp.fromDate(e.createdAt),
      'createdBy': e.createdBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'deleted': false,
    };
    batch.set(_room.collection('entries').doc(e.id), data, SetOptions(merge: true));
    for (final kv in newReceipts.entries) {
      _receiptCache[kv.key] = kv.value;
      batch.set(_room.collection('receipts').doc(kv.key), {
        'data': Blob(kv.value),
        'size': kv.value.length,
        'entryId': e.id,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    for (final id in removedReceiptIds) {
      _receiptCache.remove(id);
      batch.delete(_room.collection('receipts').doc(id));
    }
    if (consumeInboxId != null) {
      batch.delete(_room.collection('inbox').doc(consumeInboxId));
    }
    // منتظر تأیید سرور نمی‌مانیم: در حالت آفلاین در صف می‌ماند و بعداً ارسال می‌شود.
    unawaited(batch.commit().catchError((Object err) {
      debugPrint('upsertEntry failed: $err');
    }));
  }

  @override
  Future<void> deleteEntry(Entry e) async {
    final batch = db.batch();
    batch.set(_room.collection('entries').doc(e.id), {
      'deleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    for (final a in e.attachments) {
      batch.delete(_room.collection('receipts').doc(a.id));
      _receiptCache.remove(a.id);
    }
    unawaited(batch.commit().catchError((Object err) {
      debugPrint('deleteEntry failed: $err');
    }));
  }

  @override
  Future<Uint8List?> getReceipt(String attachmentId) async {
    final cached = _receiptCache[attachmentId];
    if (cached != null) return cached;
    final ref = _room.collection('receipts').doc(attachmentId);
    Uint8List? bytes;
    try {
      final c = await ref.get(const GetOptions(source: Source.cache));
      bytes = (c.data()?['data'] as Blob?)?.bytes;
    } catch (_) {
      // در کش نبود
    }
    if (bytes == null) {
      final s = await ref.get();
      bytes = (s.data()?['data'] as Blob?)?.bytes;
    }
    if (bytes != null) {
      if (_receiptCache.length > 24) _receiptCache.remove(_receiptCache.keys.first);
      _receiptCache[attachmentId] = bytes;
    }
    return bytes;
  }

  @override
  Future<void> upsertSettlement(Settlement s) async {
    unawaited(_room.collection('settlements').doc(s.id).set({
      'from': s.from.key,
      'to': s.to.key,
      'amount': s.amount,
      'paidAt': Timestamp.fromDate(s.paidAt),
      'note': s.note,
      'createdAt': Timestamp.fromDate(s.createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'deleted': false,
    }, SetOptions(merge: true)).catchError((Object err) {
      debugPrint('upsertSettlement failed: $err');
    }));
  }

  @override
  Future<void> deleteSettlement(String id) async {
    unawaited(_room.collection('settlements').doc(id).set({
      'deleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true)).catchError((Object err) {
      debugPrint('deleteSettlement failed: $err');
    }));
  }

  @override
  Future<void> saveRoom(RoomConfig c, {bool create = false}) async {
    final data = c.toMap();
    if (create) data['createdAt'] = Timestamp.fromDate(DateTime.now());
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    unawaited(_room.set(data, SetOptions(merge: true)).catchError((Object err) {
      debugPrint('saveRoom failed: $err');
    }));
  }

  @override
  Future<void> addInbox(InboxItem item, Uint8List full) async {
    _receiptCache[item.id] = full;
    final batch = db.batch();
    batch.set(_room.collection('inbox').doc(item.id), {
      'thumb': item.thumb == null ? null : Blob(item.thumb!),
      'createdAt': Timestamp.fromDate(item.createdAt),
      'createdBy': item.createdBy,
      'note': item.note,
    });
    batch.set(_room.collection('receipts').doc(item.id), {
      'data': Blob(full),
      'size': full.length,
      'inbox': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    unawaited(batch.commit().catchError((Object err) {
      debugPrint('addInbox failed: $err');
    }));
  }

  @override
  Future<void> deleteInbox(String id) async {
    _receiptCache.remove(id);
    final batch = db.batch();
    batch.delete(_room.collection('inbox').doc(id));
    batch.delete(_room.collection('receipts').doc(id));
    unawaited(batch.commit().catchError((Object err) {
      debugPrint('deleteInbox failed: $err');
    }));
  }

  /// بررسی اتصال واقعی به سرور (برای مرحلهٔ راه‌اندازی). خطا → پیام فارسی.
  Future<RoomConfig?> probe({Duration timeout = const Duration(seconds: 25)}) async {
    try {
      final s = await _room
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      if (!s.exists) return null;
      return RoomConfig.fromMap(s.data());
    } on TimeoutException {
      throw const ConnError('پاسخی از سرور نرسید. اینترنت (و در صورت نیاز فیلترشکن) را بررسی کنید.');
    } on FirebaseException catch (e) {
      throw ConnError(_describe(e));
    }
  }

  static String _describe(FirebaseException e) {
    final msg = (e.message ?? '').toLowerCase();
    if (e.code == 'permission-denied') {
      return 'دسترسی رد شد. قوانین (Rules) پایگاه‌داده را از راهنما کپی و در کنسول Firebase منتشر (Publish) کنید.';
    }
    if (e.code == 'not-found' || msg.contains('does not exist') || msg.contains('database')) {
      return 'پایگاه‌دادهٔ Firestore در این پروژه ساخته نشده است. در کنسول: Build → Firestore Database → Create database.';
    }
    if (msg.contains('api key') || msg.contains('api_key') || e.code == 'invalid-argument') {
      return 'کلید API معتبر نیست. تنظیمات را دوباره از کنسول Firebase کپی کنید.';
    }
    if (e.code == 'unavailable') {
      return 'سرور در دسترس نیست. اتصال اینترنت را بررسی کنید.';
    }
    return 'خطا در اتصال: ${e.code} ${e.message ?? ''}'.trim();
  }

  @override
  void dispose() {}
}

class ConnError implements Exception {
  final String message;
  const ConnError(this.message);
  @override
  String toString() => message;
}

// ===========================================================================
// حالت نمایشی (بدون اینترنت، داده‌های نمونه)
// ===========================================================================
class _Subject<T> {
  _Subject(this._value);
  T _value;
  final _ctrl = StreamController<T>.broadcast();
  T get value => _value;
  set value(T v) {
    _value = v;
    _ctrl.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _ctrl.stream;
  }

  void close() => _ctrl.close();
}

class DemoRepo implements Repo {
  DemoRepo() {
    _seed();
  }

  late final _room = _Subject<RoomConfig?>(const RoomConfig(name: 'ساختمان نمونه — ۴ طبقه'));
  late final _entries = _Subject<ListSnap<Entry>>(const ListSnap([]));
  late final _settlements = _Subject<ListSnap<Settlement>>(const ListSnap([]));
  late final _inbox = _Subject<ListSnap<InboxItem>>(const ListSnap([]));
  final _receipts = <String, Uint8List>{};
  int _counter = 0;

  @override
  bool get isDemo => true;

  @override
  String newId() => 'demo-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  void _seed() {
    final rnd = Random(7);
    final now = DateTime.now();
    final titles = <String, List<String>>{
      'materials': ['سیمان تیپ ۲ — ۲۰۰ پاکت', 'آجر سفال', 'میلگرد ۱۶ و ۱۸', 'شن و ماسه', 'بلوک سقفی', 'گچ و خاک', 'کاشی و سرامیک', 'ایزوگام'],
      'labor': ['دستمزد آرماتوربند', 'دستمزد بنا و کارگر', 'قالب‌بند', 'جوشکار اسکلت', 'دستمزد گچ‌کار', 'نصاب کاشی'],
      'transport': ['کرایهٔ کامیون مصالح', 'حمل نخاله', 'کرایهٔ خاور آجر'],
      'machinery': ['اجارهٔ بیل مکانیکی', 'پمپ بتن', 'اجارهٔ جرثقیل', 'اجارهٔ داربست'],
      'permits': ['عوارض شهرداری', 'بیمهٔ کارگران', 'نقشه‌کشی و پروانه'],
      'utilities': ['انشعاب برق کارگاهی', 'لوله‌کشی آب', 'سیم‌کشی طبقات'],
      'design': ['حق‌الزحمهٔ مهندس ناظر', 'نقشهٔ سازه'],
      'finishing': ['رنگ و پوشش', 'سنگ نما', 'درب و پنجره'],
      'misc': ['خرید ابزار', 'پذیرایی کارگران', 'متفرقه'],
    };
    final weights = <String, int>{
      'materials': 30, 'labor': 24, 'transport': 7, 'machinery': 9, 'permits': 6,
      'utilities': 7, 'design': 4, 'finishing': 8, 'misc': 5,
    };
    final keys = weights.keys.toList();
    final cum = <int>[];
    var acc = 0;
    for (final k in keys) {
      acc += weights[k]!;
      cum.add(acc);
    }
    String pickCat() {
      final r = rnd.nextInt(acc);
      for (var i = 0; i < cum.length; i++) {
        if (r < cum[i]) return keys[i];
      }
      return 'misc';
    }

    final list = <Entry>[];
    for (var i = 0; i < 48; i++) {
      final cat = pickCat();
      final t = titles[cat]!;
      final daysAgo = (pow(rnd.nextDouble(), 1.4) * 125).round();
      final paidAt = now.subtract(Duration(days: daysAgo, hours: rnd.nextInt(10) + 8, minutes: rnd.nextInt(60)));
      final base = switch (cat) {
        'materials' => 3000000 + rnd.nextInt(45000000),
        'labor' => 2500000 + rnd.nextInt(30000000),
        'machinery' => 4000000 + rnd.nextInt(26000000),
        'permits' => 10000000 + rnd.nextInt(90000000),
        'design' => 8000000 + rnd.nextInt(40000000),
        'finishing' => 5000000 + rnd.nextInt(60000000),
        _ => 800000 + rnd.nextInt(9000000),
      };
      final amount = (base / 100000).round() * 100000;
      final side = rnd.nextDouble() < 0.52 ? Side.a : Side.b;
      final proxy = rnd.nextDouble() < 0.15;
      final adjusted = daysAgo > 90 && rnd.nextDouble() < 0.5 ? (amount * (1.15 + rnd.nextDouble() * 0.3) / 100000).round() * 100000 : null;
      final hasReceipt = rnd.nextDouble() < 0.55;
      final id = 'seed-$i';
      final attachments = <Attachment>[];
      if (hasReceipt) {
        final full = demoReceipt(i);
        _receipts[id] = full;
        attachments.add(Attachment(id: id, label: 'رسید خرید', thumb: full));
        if (proxy) {
          final full2 = demoReceipt(i + 100);
          _receipts['$id-2'] = full2;
          attachments.add(Attachment(id: '$id-2', label: 'رسید واریز', thumb: full2));
        }
      }
      list.add(Entry(
        id: id,
        side: side,
        buyer: proxy ? side.other : side,
        amount: amount,
        adjustedAmount: adjusted,
        title: t[rnd.nextInt(t.length)],
        category: cat,
        paidAt: paidAt,
        note: rnd.nextDouble() < 0.3 ? 'پرداخت به ${side == Side.a ? 'فروشنده' : 'پیمانکار'} — فاکتور شمارهٔ ${1000 + rnd.nextInt(9000)}' : '',
        method: PayMethod.values[rnd.nextInt(PayMethod.values.length)],
        attachments: attachments,
        createdAt: paidAt.add(Duration(minutes: rnd.nextInt(90))),
        createdBy: 'demo-${side.name}',
      ));
    }
    list.sort((x, y) => y.paidAt.compareTo(x.paidAt));
    _entries.value = ListSnap(list);
    _settlements.value = ListSnap([
      Settlement(
        id: 'seed-s1',
        from: Side.b,
        to: Side.a,
        amount: 50000000,
        paidAt: now.subtract(const Duration(days: 40)),
        note: 'تسویهٔ مرحلهٔ اول',
        createdAt: now.subtract(const Duration(days: 40)),
      ),
    ]);
    final inboxItems = <InboxItem>[];
    for (var i = 0; i < 2; i++) {
      final full = demoReceipt(300 + i);
      _receipts['inbox-$i'] = full;
      inboxItems.add(InboxItem(id: 'inbox-$i', thumb: full, createdAt: now.subtract(Duration(hours: 3 * (i + 1))), createdBy: 'demo-a'));
    }
    _inbox.value = ListSnap(inboxItems);
  }

  @override
  Stream<RoomConfig?> room() => _room.stream;
  @override
  Stream<ListSnap<Entry>> entries() => _entries.stream;
  @override
  Stream<ListSnap<Settlement>> settlements() => _settlements.stream;
  @override
  Stream<ListSnap<InboxItem>> inbox() => _inbox.stream;

  @override
  Future<void> upsertEntry(
    Entry e, {
    Map<String, Uint8List> newReceipts = const {},
    List<String> removedReceiptIds = const [],
    String? consumeInboxId,
  }) async {
    final items = [..._entries.value.items.where((x) => x.id != e.id), e.copyWith(updatedAt: DateTime.now())];
    items.sort((x, y) => y.paidAt.compareTo(x.paidAt));
    _receipts.addAll(newReceipts);
    for (final id in removedReceiptIds) {
      _receipts.remove(id);
    }
    if (consumeInboxId != null) {
      _inbox.value = ListSnap(_inbox.value.items.where((x) => x.id != consumeInboxId).toList());
    }
    _entries.value = ListSnap(items);
  }

  @override
  Future<void> deleteEntry(Entry e) async {
    for (final a in e.attachments) {
      _receipts.remove(a.id);
    }
    _entries.value = ListSnap(_entries.value.items.where((x) => x.id != e.id).toList());
  }

  @override
  Future<Uint8List?> getReceipt(String attachmentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _receipts[attachmentId];
  }

  @override
  Future<void> upsertSettlement(Settlement s) async {
    final items = [..._settlements.value.items.where((x) => x.id != s.id), s];
    items.sort((x, y) => y.paidAt.compareTo(x.paidAt));
    _settlements.value = ListSnap(items);
  }

  @override
  Future<void> deleteSettlement(String id) async {
    _settlements.value = ListSnap(_settlements.value.items.where((x) => x.id != id).toList());
  }

  @override
  Future<void> saveRoom(RoomConfig c, {bool create = false}) async {
    _room.value = c;
  }

  @override
  Future<void> addInbox(InboxItem item, Uint8List full) async {
    _receipts[item.id] = full;
    _inbox.value = ListSnap([item, ..._inbox.value.items]);
  }

  @override
  Future<void> deleteInbox(String id) async {
    _receipts.remove(id);
    _inbox.value = ListSnap(_inbox.value.items.where((x) => x.id != id).toList());
  }

  @override
  void dispose() {
    _room.close();
    _entries.close();
    _settlements.close();
    _inbox.close();
  }
}
