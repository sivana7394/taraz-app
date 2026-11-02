// ابزارهای فارسی‌سازی: اعداد، مبالغ، تاریخ شمسی، عدد به حروف.
import 'package:shamsi_date/shamsi_date.dart';

const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// تبدیل همهٔ ارقام لاتین (و عربی) به فارسی.
String faDigits(Object value) {
  final s = value.toString();
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x30 && r <= 0x39) {
      sb.write(_faDigits[r - 0x30]);
    } else if (r >= 0x660 && r <= 0x669) {
      sb.write(_faDigits[r - 0x660]);
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

/// تبدیل ارقام فارسی/عربی به لاتین (برای پردازش ورودی کاربر).
String enDigits(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x6F0 && r <= 0x6F9) {
      sb.writeCharCode(0x30 + (r - 0x6F0));
    } else if (r >= 0x660 && r <= 0x669) {
      sb.writeCharCode(0x30 + (r - 0x660));
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

/// فقط ارقام یک متن را به عدد صحیح تبدیل می‌کند (جداکننده‌ها نادیده گرفته می‌شوند).
int? parseAmount(String s) {
  final digits = enDigits(s).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.length > 15) return null;
  return int.tryParse(digits);
}

/// جداکنندهٔ هزارگان فارسی (U+066C).
const thousandsSep = '٬';

/// عدد با جداکنندهٔ هزارگان و ارقام فارسی. مثال: ۱۲٬۳۴۵٬۰۰۰
String groupDigits(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    sb.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) sb.write(thousandsSep);
  }
  return (neg ? '−' : '') + faDigits(sb.toString());
}

/// واحد نمایش مبالغ.
enum MoneyUnit { toman, rial }

extension MoneyUnitX on MoneyUnit {
  String get label => this == MoneyUnit.toman ? 'تومان' : 'ریال';
  String get key => name;
  static MoneyUnit fromKey(String? k) =>
      k == 'rial' ? MoneyUnit.rial : MoneyUnit.toman;
}

/// مبلغ (ذخیره‌شده به تومان) با واحد انتخابی.
String fmtMoney(int toman, {MoneyUnit unit = MoneyUnit.toman, bool withUnit = true}) {
  final v = unit == MoneyUnit.rial ? toman * 10 : toman;
  final s = groupDigits(v);
  return withUnit ? '$s ${unit.label}' : s;
}

/// مبلغ خلاصه: ۱۲.۳ میلیون / ۴۵۰ هزار / ۲.۱ میلیارد
String fmtCompact(int toman, {MoneyUnit unit = MoneyUnit.toman}) {
  final v = (unit == MoneyUnit.rial ? toman * 10 : toman).abs();
  final sign = toman < 0 ? '−' : '';
  String one(double x, String suffix) {
    String r;
    if (x >= 100) {
      r = x.round().toString();
    } else {
      final t = (x * 10).round() / 10;
      r = t == t.roundToDouble() ? t.round().toString() : t.toStringAsFixed(1);
    }
    return '$sign${faDigits(r)} $suffix';
  }

  if (v >= 1000000000000) return one(v / 1000000000000, 'هزار میلیارد');
  if (v >= 1000000000) return one(v / 1000000000, 'میلیارد');
  if (v >= 1000000) return one(v / 1000000, 'میلیون');
  if (v >= 1000) return one(v / 1000, 'هزار');
  return '$sign${faDigits(v)}';
}

/// درصد با یک رقم اعشار و ارقام فارسی.
String fmtPercent(double ratio, {int decimals = 0}) {
  final p = ratio * 100;
  final s = decimals == 0 ? p.round().toString() : p.toStringAsFixed(decimals);
  return '${faDigits(s)}٪';
}

// ---------------------------------------------------------------------------
// عدد به حروف
// ---------------------------------------------------------------------------
const _ones = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
const _teens = ['ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'];
const _tens = ['', '', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'];
const _hundreds = ['', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'];
const _scales = ['', 'هزار', 'میلیون', 'میلیارد', 'هزار میلیارد', 'میلیون میلیارد'];

String _threeDigits(int n) {
  final parts = <String>[];
  final h = n ~/ 100, t = (n % 100) ~/ 10, o = n % 10;
  if (h > 0) parts.add(_hundreds[h]);
  if (t == 1) {
    parts.add(_teens[o]);
  } else {
    if (t > 1) parts.add(_tens[t]);
    if (o > 0) parts.add(_ones[o]);
  }
  return parts.join(' و ');
}

/// عدد صحیح به حروف فارسی. مثال: ۲٬۵۰۰٬۰۰۰ → «دو میلیون و پانصد هزار»
String numToWords(int n) {
  if (n == 0) return 'صفر';
  final neg = n < 0;
  var v = n.abs();
  final groups = <String>[];
  var scale = 0;
  while (v > 0 && scale < _scales.length) {
    final g = v % 1000;
    if (g > 0) {
      final words = (g == 1 && scale > 0) ? 'یک' : _threeDigits(g);
      groups.insert(0, scale == 0 ? words : '$words ${_scales[scale]}');
    }
    v ~/= 1000;
    scale++;
  }
  return (neg ? 'منفی ' : '') + groups.join(' و ');
}

/// مبلغ به حروف با واحد.
String moneyToWords(int toman, {MoneyUnit unit = MoneyUnit.toman}) {
  final v = unit == MoneyUnit.rial ? toman * 10 : toman;
  return '${numToWords(v)} ${unit.label}';
}

// ---------------------------------------------------------------------------
// تاریخ شمسی
// ---------------------------------------------------------------------------
const jMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];
const jWeekdays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];
const jWeekdaysShort = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

Jalali toJalali(DateTime d) => Jalali.fromDateTime(d);

/// شروع ماه شمسیِ شامل تاریخ داده‌شده.
DateTime startOfJMonth(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return Jalali(j.year, j.month, 1).toDateTime();
}

/// شروع ماه شمسی با افست (0 = این ماه، -1 = ماه گذشته، …).
DateTime startOfJMonthOffset(DateTime d, int offset) {
  final j = Jalali.fromDateTime(d);
  final m = Jalali(j.year, j.month, 1).addMonths(offset);
  return m.toDateTime();
}

/// شروع سال شمسی شامل تاریخ داده‌شده.
DateTime startOfJYear(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return Jalali(j.year, 1, 1).toDateTime();
}

/// شروع سال شمسی بعدی.
DateTime startOfNextJYear(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return Jalali(j.year + 1, 1, 1).toDateTime();
}

/// «۱۲ آبان ۱۴۰۵»
String fmtDate(DateTime d, {bool withYear = true}) {
  final j = Jalali.fromDateTime(d);
  final day = faDigits(j.day);
  final m = jMonths[j.month - 1];
  return withYear ? '$day $m ${faDigits(j.year)}' : '$day $m';
}

/// «۱۴۰۵/۰۸/۱۲»
String fmtDateNumeric(DateTime d) {
  final j = Jalali.fromDateTime(d);
  String two(int n) => n < 10 ? '0$n' : '$n';
  return faDigits('${j.year}/${two(j.month)}/${two(j.day)}');
}

/// «چهارشنبه ۱۲ آبان ۱۴۰۵»
String fmtDateWithWeekday(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${jWeekdays[j.weekDay - 1]} ${fmtDate(d)}';
}

/// «۱۴:۰۵»
String fmtTime(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return faDigits('${two(d.hour)}:${two(d.minute)}');
}

/// «۱۲ آبان ۱۴۰۵ — ۱۴:۰۵»
String fmtDateTime(DateTime d) => '${fmtDate(d)} — ${fmtTime(d)}';

/// «آبان ۱۴۰۵»
String fmtMonthYear(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${jMonths[j.month - 1]} ${faDigits(j.year)}';
}

/// برچسب روز نسبی: امروز / دیروز / چهارشنبه ۱۲ آبان
String relativeDay(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(n.year, n.month, n.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'امروز';
  if (diff == 1) return 'دیروز';
  final j = Jalali.fromDateTime(d);
  final sameYear = j.year == Jalali.fromDateTime(n).year;
  return '${jWeekdays[j.weekDay - 1]} ${fmtDate(d, withYear: !sameYear)}';
}

/// «۳ دقیقه پیش»، «۲ ساعت پیش»، «دیروز»، «۵ روز پیش»
String timeAgo(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inSeconds < 60) return 'هم‌اکنون';
  if (diff.inMinutes < 60) return '${faDigits(diff.inMinutes)} دقیقه پیش';
  if (diff.inHours < 24) return '${faDigits(diff.inHours)} ساعت پیش';
  if (diff.inDays == 1) return 'دیروز';
  if (diff.inDays < 30) return '${faDigits(diff.inDays)} روز پیش';
  return fmtDate(d);
}

/// کلید ماه شمسی به شکل «1405-08» برای گروه‌بندی.
String jMonthKey(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${j.year}-${j.month.toString().padLeft(2, '0')}';
}
