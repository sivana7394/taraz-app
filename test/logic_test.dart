import 'package:flutter_test/flutter_test.dart';
import 'package:taraz/core/fa.dart';
import 'package:taraz/data/firebase_config.dart';
import 'package:taraz/data/models.dart';
import 'package:taraz/data/stats.dart';

void main() {
  group('فرمت فارسی', () {
    test('ارقام و جداکننده', () {
      expect(faDigits(1234), '۱۲۳۴');
      expect(groupDigits(1234567), '۱٬۲۳۴٬۵۶۷');
      expect(groupDigits(0), '۰');
      expect(groupDigits(999), '۹۹۹');
      expect(parseAmount('۱۲٬۵۰۰ تومان'), 12500);
      expect(parseAmount('abc'), isNull);
      expect(enDigits('۱۲۳'), '123');
    });

    test('عدد به حروف', () {
      expect(numToWords(0), 'صفر');
      expect(numToWords(15), 'پانزده');
      expect(numToWords(2500000), 'دو میلیون و پانصد هزار');
      expect(numToWords(1000), 'یک هزار');
      expect(numToWords(1001), 'یک هزار و یک');
      expect(numToWords(123456789), 'صد و بیست و سه میلیون و چهارصد و پنجاه و شش هزار و هفتصد و هشتاد و نه');
      expect(moneyToWords(1500, unit: MoneyUnit.rial), 'پانزده هزار ریال');
    });

    test('خلاصهٔ مبلغ', () {
      expect(fmtCompact(450000), '۴۵۰ هزار');
      expect(fmtCompact(12300000), '۱۲.۳ میلیون');
      expect(fmtCompact(2000000000), '۲ میلیارد');
      expect(fmtPercent(0.4567), '۴۶٪');
    });

    test('تاریخ شمسی', () {
      final d = DateTime(2026, 11, 2, 14, 5);
      expect(fmtDate(d), '۱۱ آبان ۱۴۰۵');
      expect(fmtDateNumeric(d), '۱۴۰۵/۰۸/۱۱');
      expect(fmtTime(d), '۱۴:۰۵');
      expect(jMonthKey(d), '1405-08');
      expect(relativeDay(d, now: d), 'امروز');
      expect(relativeDay(d.subtract(const Duration(days: 1)), now: d), 'دیروز');
    });
  });

  group('تنظیمات Firebase', () {
    const web = '''
const firebaseConfig = {
  apiKey: "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ012345",
  authDomain: "taraz-demo.firebaseapp.com",
  projectId: "taraz-demo",
  storageBucket: "taraz-demo.firebasestorage.app",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdef1234567890"
};''';

    test('خواندن firebaseConfig وب', () {
      final c = FirebaseConn.parseConsoleText(web)!;
      expect(c.apiKey, startsWith('AIza'));
      expect(c.projectId, 'taraz-demo');
      expect(c.messagingSenderId, '123456789012');
      expect(c.appId, contains(':web:'));
    });

    test('خواندن google-services.json', () {
      const gs = '''{
  "project_info": {"project_number": "123456789012", "project_id": "taraz-demo", "storage_bucket": "x"},
  "client": [{"client_info": {"mobilesdk_app_id": "1:123456789012:android:abcd", "android_client_info": {"package_name": "ir.sivan.taraz"}},
             "api_key": [{"current_key": "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ012345"}]}],
  "configuration_version": "1"
}''';
      final c = FirebaseConn.parseConsoleText(gs)!;
      expect(c.appId, '1:123456789012:android:abcd');
      expect(c.projectId, 'taraz-demo');
    });

    test('کد دعوت رفت‌وبرگشت', () {
      final c = FirebaseConn.parseConsoleText(web)!.copyWith(roomId: FirebaseConn.newRoomId());
      final code = c.toInviteCode();
      expect(code, startsWith('TARAZ1-'));
      final back = FirebaseConn.fromInviteCode('  متن اضافه $code\n')!;
      expect(back.roomId, c.roomId);
      expect(back.apiKey, c.apiKey);
      expect(FirebaseConn.fromInviteCode('TARAZ1-xxxx'), isNull);
    });
  });

  group('محاسبهٔ تراز', () {
    Entry e(Side s, int amount, {DateTime? at, String cat = 'materials'}) => Entry(
          id: '${s.name}-$amount-${at?.millisecondsSinceEpoch ?? 0}',
          side: s,
          amount: amount,
          title: 't',
          category: cat,
          paidAt: at ?? DateTime(2026, 10, 20),
          createdAt: DateTime(2026, 10, 20),
        );

    test('۵۰/۵۰ بدون تسویه', () {
      final st = Stats.compute(
        entries: [e(Side.a, 100), e(Side.b, 40)],
        settlements: const [],
        config: const RoomConfig(),
        period: Period.all(),
        now: DateTime(2026, 11, 2),
      );
      expect(st.allTotal, 140);
      expect(st.fairA, 70);
      expect(st.balanceA, 30); // b باید ۳۰ به a بدهد
      expect(st.debtor, Side.b);
      expect(st.owed, 30);
    });

    test('با تسویه', () {
      final st = Stats.compute(
        entries: [e(Side.a, 100), e(Side.b, 40)],
        settlements: [Settlement(id: 's', from: Side.b, to: Side.a, amount: 30, paidAt: DateTime(2026, 10, 25), createdAt: DateTime(2026, 10, 25))],
        config: const RoomConfig(),
        period: Period.all(),
        now: DateTime(2026, 11, 2),
      );
      expect(st.balanceA, 0);
      expect(st.debtor, isNull);
    });

    test('سهم نابرابر ۴/۲ دانگ', () {
      final st = Stats.compute(
        entries: [e(Side.a, 60), e(Side.b, 60)],
        settlements: const [],
        config: const RoomConfig(shareA: 4, shareB: 2),
        period: Period.all(),
        now: DateTime(2026, 11, 2),
      );
      expect(st.fairA, 80);
      expect(st.balanceA, -20); // a باید ۲۰ به b بدهد
      expect(st.debtor, Side.a);
    });

    test('بازهٔ ماه و سطل‌های ماهانه', () {
      final now = DateTime(2026, 11, 2);
      final st = Stats.compute(
        entries: [
          e(Side.a, 10, at: DateTime(2026, 10, 25)), // آبان ۱۴۰۵
          e(Side.b, 20, at: DateTime(2026, 9, 25)), // مهر ۱۴۰۵
          e(Side.a, 5, at: DateTime(2026, 3, 1)), // اسفند ۱۴۰۴
        ],
        settlements: const [],
        config: const RoomConfig(),
        period: Period.thisMonth(now),
        now: now,
      );
      expect(st.total, 10);
      expect(st.allTotal, 35);
      expect(st.byMonth.length, 6);
      expect(st.byMonth.last.label, 'آبان');
      expect(st.byMonth.last.a, 10);
      expect(st.byMonth[4].b, 20);
      expect(st.byCategory.single.key, 'materials');
    });
  });
}
