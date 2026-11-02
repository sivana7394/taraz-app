// اسکرین‌شات صفحات در حالت نمایشی → ci/screens/*.png (برای بازبینی بصری در CI).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taraz/data/app_state.dart';
import 'package:taraz/data/local_store.dart';
import 'package:taraz/data/models.dart';
import 'package:taraz/data/repo.dart';
import 'package:taraz/main.dart';
import 'package:taraz/ui/entries/entry_detail.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Vazirmatn');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Vazirmatn-$w.ttf'));
  }
  await loader.load();
  // آیکون‌های متریال از SDK
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final l = FontLoader('MaterialIcons');
      l.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      await l.load();
    }
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('ci/screens/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  Future<void> boot(WidgetTester tester, {bool demo = true, Brightness brightness = Brightness.light}) async {
    SharedPreferences.setMockInitialValues(demo
        ? {'demo': true, 'side': 'a', 'onboarded': true, 'theme': brightness == Brightness.dark ? 'dark' : 'light'}
        : {'theme': 'light'});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = await LocalStore.load();
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('shot'),
      child: TarazApp(store: store, repoOverride: demo ? DemoRepo() : null, skipLock: true),
    ));
    await _settle(tester, 1500);
  }

  testWidgets('setup screens', (tester) async {
    await boot(tester, demo: false);
    await _snap(tester, '01-welcome');
    await tester.tap(find.text('شروع'));
    await _settle(tester, 600);
    await _snap(tester, '02-role');
    await tester.tap(find.text('ادامه'));
    await _settle(tester, 600);
    await _snap(tester, '03-connect');
    await tester.tap(find.text('ساخت پروژهٔ جدید'));
    await _settle(tester, 400);
    await _snap(tester, '04-guide');
  });

  testWidgets('dashboard & entries', (tester) async {
    await boot(tester);
    await _snap(tester, '10-dashboard');
    // اسکرول پایین داشبورد
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await _settle(tester, 800);
    await _snap(tester, '11-dashboard-scrolled');
    await tester.tap(find.text('هزینه‌ها').last);
    await _settle(tester, 800);
    await _snap(tester, '12-entries');
  });

  testWidgets('entry editor & detail', (tester) async {
    await boot(tester);
    await tester.tap(find.text('ثبت هزینه').first);
    await _settle(tester, 800);
    await tester.enterText(find.byType(TextFormField).first, '2500000');
    await _settle(tester, 300);
    await _snap(tester, '20-editor');
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await _settle(tester, 600);
    // باز کردن اولین هزینهٔ دارای رسید
    final s = tester.element(find.byType(Scaffold).first).read<AppState>();
    final first = s.entries.firstWhere((e) => e.hasReceipt, orElse: () => s.entries.first);
    nav.push(MaterialPageRoute<void>(builder: (_) => EntryDetailPage(entryId: first.id)));
    await _settle(tester, 1200);
    await _snap(tester, '21-detail');
  });

  testWidgets('reports & settings', (tester) async {
    await boot(tester);
    await tester.tap(find.text('گزارش').last);
    await _settle(tester, 900);
    await _snap(tester, '30-reports-categories');
    await tester.tap(find.text('ماه‌ها'));
    await _settle(tester, 900);
    await _snap(tester, '31-reports-months');
    await tester.tap(find.text('طرف‌ها'));
    await _settle(tester, 900);
    await _snap(tester, '32-reports-sides');
    await tester.tap(find.text('تنظیمات').last);
    await _settle(tester, 600);
    await _snap(tester, '40-settings');
  });

  testWidgets('settlement sheet', (tester) async {
    await boot(tester);
    await tester.scrollUntilVisible(find.text('ثبت تسویه').first, 150, scrollable: find.byType(Scrollable).first);
    await _settle(tester, 400);
    await tester.tap(find.text('ثبت تسویه').first, warnIfMissed: false);
    await _settle(tester, 800);
    await _snap(tester, '50-settlement');
  });

  testWidgets('dark dashboard', (tester) async {
    await boot(tester, brightness: Brightness.dark);
    await _snap(tester, '60-dashboard-dark');
  });

  test('side sanity', () {
    expect(Side.a.other, Side.b);
  });
}
