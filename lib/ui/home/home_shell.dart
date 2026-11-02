// پوستهٔ اصلی: نوار پایین + دکمهٔ ثبت هزینه.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../data/app_state.dart';
import '../dashboard/dashboard_page.dart';
import '../entries/entries_page.dart';
import '../entries/entry_editor.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  EntriesFilter? _entriesFilter;
  int _entriesKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<AppState>();
      if (s.pendingInvite) {
        s.pendingInvite = false;
        showInviteSheet(context);
      }
    });
  }

  void _openEntries(EntriesFilter? f) => setState(() {
        _entriesFilter = f;
        _entriesKey++;
        _index = 1;
      });

  @override
  Widget build(BuildContext context) {
    final unseen = context.select<AppState, int>((s) => s.unseenFromOther);
    final pages = [
      DashboardPage(onOpenEntries: _openEntries, onOpenReports: () => setState(() => _index = 2)),
      EntriesPage(key: ValueKey('entries-$_entriesKey'), initialFilter: _entriesFilter),
      ReportsPage(onOpenEntries: (f) => _openEntries(f)),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => EntryEditorPage.open(context),
              icon: const Icon(Icons.add),
              label: const Text('ثبت هزینه'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          if (i == 1 && _index != 1) _entriesFilter = null;
          _index = i;
        }),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'داشبورد'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unseen > 0, label: Text(faDigits(unseen)), child: const Icon(Icons.receipt_long_outlined)),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'هزینه‌ها',
          ),
          const NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'گزارش'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
      ),
    );
  }
}
