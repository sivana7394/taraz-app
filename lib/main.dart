// تراز — حسابداری مشارکت ساخت‌وساز
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/local_store.dart';
import 'data/repo.dart';
import 'ui/home/home_shell.dart';
import 'ui/setup/lock_screen.dart';
import 'ui/setup/setup_flow.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await LocalStore.load();
  runApp(TarazApp(store: store));
}

class TarazApp extends StatefulWidget {
  const TarazApp({super.key, required this.store, this.repoOverride, this.skipLock = false});
  final LocalStore store;
  final Repo? repoOverride;
  final bool skipLock;

  @override
  State<TarazApp> createState() => _TarazAppState();
}

class _TarazAppState extends State<TarazApp> {
  late final AppState _state = AppState(widget.store, repoOverride: widget.repoOverride);

  @override
  void initState() {
    super.initState();
    _state.boot();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _state,
      child: Consumer<AppState>(
        builder: (context, s, _) => MaterialApp(
          title: 'تراز',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: s.themeMode,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // اندازهٔ متن سیستم را محدود می‌کنیم تا چیدمان نشکند.
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
              child: child!,
            );
          },
          home: LockGate(
            enabled: !widget.skipLock,
            child: const _Root(),
          ),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final phase = context.select<AppState, AppPhase>((s) => s.phase);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (phase) {
        AppPhase.setup => const SetupFlow(key: ValueKey('setup')),
        AppPhase.connecting => const _Connecting(key: ValueKey('connecting')),
        AppPhase.ready => const HomeShell(key: ValueKey('home')),
        AppPhase.error => const _ConnectError(key: ValueKey('error')),
      },
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(height: 16),
              Text('در حال اتصال به پروژه…'),
            ],
          ),
        ),
      );
}

class _ConnectError extends StatelessWidget {
  const _ConnectError({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('اتصال برقرار نشد', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(s.error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => s.boot(),
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش دوباره'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => s.disconnect(), child: const Text('خروج از پروژه')),
            ],
          ),
        ),
      ),
    );
  }
}
