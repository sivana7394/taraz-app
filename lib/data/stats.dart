// محاسبات: بازهٔ زمانی، جمع‌ها، سهم‌ها و تراز.
import '../core/fa.dart';
import 'models.dart';

/// بازهٔ زمانی گزارش.
class Period {
  final String key;
  final String label;
  final DateTime? start; // شامل
  final DateTime? end; // غیرشامل
  const Period(this.key, this.label, {this.start, this.end});

  bool contains(DateTime d) =>
      (start == null || !d.isBefore(start!)) && (end == null || d.isBefore(end!));

  static Period all() => const Period('all', 'همه');

  static Period thisMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return Period('month', 'این ماه', start: startOfJMonth(n), end: startOfJMonthOffset(n, 1));
  }

  static Period lastMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return Period('lastMonth', 'ماه گذشته',
        start: startOfJMonthOffset(n, -1), end: startOfJMonth(n));
  }

  static Period last3Months([DateTime? now]) {
    final n = now ?? DateTime.now();
    return Period('3m', '۳ ماه اخیر',
        start: startOfJMonthOffset(n, -2), end: startOfJMonthOffset(n, 1));
  }

  static Period thisYear([DateTime? now]) {
    final n = now ?? DateTime.now();
    final j = toJalali(n);
    return Period('year', 'سال ${faDigits(j.year)}',
        start: startOfJYear(n), end: startOfNextJYear(n));
  }

  static Period custom(DateTime start, DateTime endInclusive) => Period(
        'custom',
        '${fmtDate(start, withYear: false)} تا ${fmtDate(endInclusive, withYear: false)}',
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(endInclusive.year, endInclusive.month, endInclusive.day).add(const Duration(days: 1)),
      );

  static List<Period> presets([DateTime? now]) => [
        thisMonth(now),
        lastMonth(now),
        last3Months(now),
        thisYear(now),
        all(),
      ];
}

class CategoryStat {
  final String key;
  final int amount;
  final int count;
  final int a;
  final int b;
  const CategoryStat(this.key, this.amount, this.count, this.a, this.b);
}

class MonthBucket {
  final String key;
  final String label;
  final DateTime start;
  final int a;
  final int b;
  const MonthBucket(this.key, this.label, this.start, this.a, this.b);
  int get total => a + b;
}

class SideStat {
  final Side side;
  final int spent;
  final int count;
  const SideStat(this.side, this.spent, this.count);
}

/// نتیجهٔ محاسبات برای یک بازه + تراز کل.
class Stats {
  final Period period;
  final int total;
  final int spentA;
  final int spentB;
  final int countA;
  final int countB;
  final List<CategoryStat> byCategory;
  final List<MonthBucket> byMonth;
  final int receiptsCount;
  final int maxEntry;

  // تراز کل (مستقل از بازه)
  final int allSpentA;
  final int allSpentB;
  final int transfersAB; // از a به b
  final int transfersBA; // از b به a
  final int fairA;
  final int fairB;
  /// مثبت: شرکا (b) باید به a بدهند. منفی: a باید به b بدهد.
  final int balanceA;

  const Stats({
    required this.period,
    required this.total,
    required this.spentA,
    required this.spentB,
    required this.countA,
    required this.countB,
    required this.byCategory,
    required this.byMonth,
    required this.receiptsCount,
    required this.maxEntry,
    required this.allSpentA,
    required this.allSpentB,
    required this.transfersAB,
    required this.transfersBA,
    required this.fairA,
    required this.fairB,
    required this.balanceA,
  });

  int get count => countA + countB;
  int get allTotal => allSpentA + allSpentB;
  int spent(Side s) => s == Side.a ? spentA : spentB;
  int countOf(Side s) => s == Side.a ? countA : countB;
  double shareOfTotal(Side s) => total == 0 ? 0 : spent(s) / total;

  /// چه کسی بدهکار است؟ null = تراز است.
  Side? get debtor => balanceA > 0 ? Side.b : (balanceA < 0 ? Side.a : null);
  Side? get creditor => debtor?.other;
  int get owed => balanceA.abs();

  /// مشارکت مؤثر هر طرف (هزینه + پرداختی به طرف دیگر − دریافتی از او).
  int contribution(Side s) => s == Side.a
      ? allSpentA + transfersAB - transfersBA
      : allSpentB + transfersBA - transfersAB;

  static Stats compute({
    required List<Entry> entries,
    required List<Settlement> settlements,
    required RoomConfig config,
    required Period period,
    DateTime? now,
    int monthCount = 6,
  }) {
    final n = now ?? DateTime.now();
    var total = 0, spentA = 0, spentB = 0, countA = 0, countB = 0, receipts = 0, maxEntry = 0;
    var allA = 0, allB = 0;
    final cat = <String, List<int>>{}; // key → [amount, count, a, b]

    // سطل‌های ماهانه: آخرین monthCount ماه شمسی تا «اکنون» (یا تا پایان بازه)
    final anchor = period.end != null && period.end!.isBefore(n)
        ? period.end!.subtract(const Duration(days: 1))
        : n;
    final buckets = <String, List<int>>{};
    final bucketOrder = <MonthBucket>[];
    for (var i = monthCount - 1; i >= 0; i--) {
      final s = startOfJMonthOffset(anchor, -i);
      final k = jMonthKey(s);
      buckets[k] = [0, 0];
      bucketOrder.add(MonthBucket(k, jMonths[toJalali(s).month - 1], s, 0, 0));
    }

    for (final e in entries) {
      if (e.deleted) continue;
      if (e.side == Side.a) {
        allA += e.amount;
      } else {
        allB += e.amount;
      }
      final mk = jMonthKey(e.paidAt);
      final bk = buckets[mk];
      if (bk != null) bk[e.side == Side.a ? 0 : 1] += e.amount;

      if (!period.contains(e.paidAt)) continue;
      total += e.amount;
      if (e.amount > maxEntry) maxEntry = e.amount;
      if (e.hasReceipt) receipts++;
      if (e.side == Side.a) {
        spentA += e.amount;
        countA++;
      } else {
        spentB += e.amount;
        countB++;
      }
      final c = cat.putIfAbsent(e.category, () => [0, 0, 0, 0]);
      c[0] += e.amount;
      c[1] += 1;
      c[e.side == Side.a ? 2 : 3] += e.amount;
    }

    var ab = 0, ba = 0;
    for (final s in settlements) {
      if (s.deleted) continue;
      if (s.from == Side.a && s.to == Side.b) ab += s.amount;
      if (s.from == Side.b && s.to == Side.a) ba += s.amount;
    }

    final allTotal = allA + allB;
    final fairA = (allTotal * config.ratioA).round();
    final fairB = allTotal - fairA;
    final contribA = allA + ab - ba;
    final balanceA = contribA - fairA;

    final byCategory = cat.entries
        .map((e) => CategoryStat(e.key, e.value[0], e.value[1], e.value[2], e.value[3]))
        .toList()
      ..sort((x, y) => y.amount.compareTo(x.amount));

    final byMonth = bucketOrder
        .map((b) => MonthBucket(b.key, b.label, b.start, buckets[b.key]![0], buckets[b.key]![1]))
        .toList();

    return Stats(
      period: period,
      total: total,
      spentA: spentA,
      spentB: spentB,
      countA: countA,
      countB: countB,
      byCategory: byCategory,
      byMonth: byMonth,
      receiptsCount: receipts,
      maxEntry: maxEntry,
      allSpentA: allA,
      allSpentB: allB,
      transfersAB: ab,
      transfersBA: ba,
      fairA: fairA,
      fairB: fairB,
      balanceA: balanceA,
    );
  }

  /// چند نکتهٔ خودکار برای داشبورد.
  List<String> insights(RoomConfig config, {MoneyUnit unit = MoneyUnit.toman}) {
    final out = <String>[];
    if (byCategory.isNotEmpty && total > 0) {
      final top = byCategory.first;
      out.add('بیشترین هزینهٔ این بازه «${categoryOf(top.key).label}» با ${fmtPercent(top.amount / total)} از کل است.');
    }
    if (byMonth.length >= 2) {
      final cur = byMonth[byMonth.length - 1].total;
      final prev = byMonth[byMonth.length - 2].total;
      if (prev > 0 && cur > 0) {
        final ch = (cur - prev) / prev;
        final dir = ch >= 0 ? 'بیشتر' : 'کمتر';
        out.add('هزینهٔ ${byMonth.last.label} نسبت به ${byMonth[byMonth.length - 2].label} ${fmtPercent(ch.abs())} $dir بوده است.');
      }
    }
    if (count > 0) {
      final uncovered = count - receiptsCount;
      if (uncovered > 0) {
        out.add('${faDigits(uncovered)} هزینه بدون رسید ثبت شده است.');
      } else {
        out.add('همهٔ ${faDigits(count)} هزینهٔ این بازه رسید دارند.');
      }
    }
    if (allTotal > 0) {
      final rA = allSpentA / allTotal;
      out.add('${config.sideAName} ${fmtPercent(rA)} و ${config.sideBName} ${fmtPercent(1 - rA)} از کل هزینه‌ها را پرداخت کرده‌اند (سهم قراردادی: ${fmtPercent(config.ratioA)} / ${fmtPercent(config.ratioB)}).');
    }
    return out;
  }
}
