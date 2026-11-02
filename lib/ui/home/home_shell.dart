// پوستهٔ اصلی: نوار پایین + دکمهٔ ثبت هزینه + پاسخ به Share و میانبرها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../data/app_state.dart';
import '../dashboard/dashboard_page.dart';
import '../entries/entries_page.dart';
import '../entries/entry_editor.dart';
import '../inbox/inbox_page.dart';
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
  int _handledSeq = -1;
  AppState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _state = context.read<AppState>();
      _state!.addListener(_onStateChanged);
      _onStateChanged();
    });
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    super.dispose();
  }

  /// درخواست‌های بیرونی (Share از گالری، میانبر آیکون، نمایش کد دعوت) را اجرا می‌کند.
  void _onStateChanged() {
    final s = _state;
    if (s == null || !mounted) return;
    if (s.pendingActionSeq == _handledSeq || s.pendingAction == PendingAction.none) return;
    _handledSeq = s.pendingActionSeq;
    final action = s.takePendingAction();
    // روت‌های باز روی خانه را می‌بندیم تا صفحهٔ درست باز شود
    Navigator.of(context).popUntil((r) => r.isFirst);
    switch (action) {
      case PendingAction.openInbox:
        InboxPage.open(context);
      case PendingAction.addExpense:
        EntryEditorPage.open(context);
      case PendingAction.addReceipt:
        EntryEditorPage.open(context, autoCamera: true);
      case PendingAction.showInvite:
        showInviteSheet(context);
      case PendingAction.none:
        break;
    }
  }

  void _openEntries(EntriesFilter? f) => setState(() {
        _entriesFilter = f;
        _entriesKey++;
        _index = 1;
      });

  @override
  Widget build(BuildContext context) {
    final unseen = context.select<AppState, int>((s) => s.unseenFromOther);
    final inboxCount = context.select<AppState, int>((s) => s.inbox.length);
    final pages = [
      DashboardPage(onOpenEntries: _openEntries, onOpenReports: () => setState(() => _index = 2)),
      EntriesPage(key: ValueKey('entries-$_entriesKey'), initialFilter: _entriesFilter),
      ReportsPage(onOpenEntries: (f) => _openEntries(f)),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index <= 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (inboxCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FloatingActionButton.small(
                      heroTag: 'fab-inbox',
                      tooltip: 'صندوق رسیدها',
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                      onPressed: () => InboxPage.open(context),
                      child: Badge(label: Text(faDigits(inboxCount)), child: const Icon(Icons.inbox_outlined)),
                    ),
                  ),
                FloatingActionButton.extended(
                  heroTag: 'fab-add',
                  onPressed: () => EntryEditorPage.open(context),
                  icon: const Icon(Icons.add),
                  label: const Text('ثبت هزینه'),
                ),
              ],
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
