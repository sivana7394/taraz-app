// وضعیت کلی اپ: اتصال، نقش، داده‌های زنده و تنظیمات ظاهر.
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/fa.dart';
import 'firebase_config.dart';
import 'local_store.dart';
import 'models.dart';
import 'repo.dart';
import 'stats.dart';

enum AppPhase { setup, connecting, ready, error }

class AppState extends ChangeNotifier {
  AppState(this.store, {Repo? repoOverride}) : _repoOverride = repoOverride {
    _themeMode = store.themeMode;
    _unit = store.unit;
    _side = store.side ?? Side.a;
    _lastSeenOther = store.lastSeenOther;
  }

  final LocalStore store;
  final Repo? _repoOverride;

  // ---------------------------------------------------------------- وضعیت
  AppPhase _phase = AppPhase.setup;
  AppPhase get phase => _phase;
  String? _error;
  String? get error => _error;

  Repo? _repo;
  Repo? get repo => _repo;
  bool get isDemo => _repo?.isDemo ?? false;

  /// پس از ساخت پروژهٔ جدید، صفحهٔ خانه یک بار برگهٔ کد دعوت را نشان می‌دهد.
  bool pendingInvite = false;

  FirebaseConn? get conn => store.conn;

  Side _side = Side.a;
  Side get side => _side;
  Side get otherSide => _side.other;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  MoneyUnit _unit = MoneyUnit.toman;
  MoneyUnit get unit => _unit;

  RoomConfig _config = const RoomConfig();
  RoomConfig get config => _config;
  bool _roomExists = false;

  List<Entry> _entries = const [];
  List<Entry> get entries => _entries;
  List<Settlement> _settlements = const [];
  List<Settlement> get settlements => _settlements;

  SyncStatus _sync = const SyncStatus(SyncState.connecting);
  SyncStatus get sync => _sync;
  bool _entriesLoaded = false;
  bool get loaded => _entriesLoaded;

  DateTime? _lastSeenOther;

  StreamSubscription? _subRoom, _subEntries, _subSettlements;

  Period _period = Period.thisMonth();
  Period get period => _period;
  set period(Period p) {
    _period = p;
    _stats = null;
    notifyListeners();
  }

  Stats? _stats;
  Stats get stats => _stats ??= Stats.compute(
        entries: _entries,
        settlements: _settlements,
        config: _config,
        period: _period,
      );

  /// نام کوتاه طرف‌ها برای نمایش.
  String nameOf(Side s) => _config.sideName(s);
  String get myName => nameOf(_side);
  String get otherName => nameOf(otherSide);

  /// هزینه‌های تازهٔ طرف مقابل که هنوز دیده نشده‌اند.
  int get unseenFromOther {
    final since = _lastSeenOther;
    if (since == null) return 0;
    return _entries.where((e) => e.side == otherSide && e.createdAt.isAfter(since)).length;
  }

  Future<void> markSeen() async {
    _lastSeenOther = DateTime.now();
    await store.setLastSeenOther(_lastSeenOther!);
    notifyListeners();
  }

  // ------------------------------------------------------------- راه‌اندازی
  /// در شروع اپ: اگر اتصال یا حالت نمایشی ذخیره شده بود، وصل می‌شود.
  Future<void> boot() async {
    if (_repoOverride != null) {
      _attach(_repoOverride);
      return;
    }
    if (store.demo) {
      _attach(DemoRepo());
      return;
    }
    final c = store.conn;
    if (c != null && c.roomId.isNotEmpty) {
      await connectWith(c, side: store.side ?? Side.a, probe: false);
    } else {
      _phase = AppPhase.setup;
      notifyListeners();
    }
  }

  Future<void> startDemo(Side side) async {
    await store.setDemo(true);
    await store.setSide(side);
    await store.setOnboarded(true);
    _side = side;
    _attach(DemoRepo());
  }

  /// اتصال به Firebase. اگر probe=true، اتصال واقعی به سرور آزمایش می‌شود و
  /// در صورت خطا ConnError پرتاب می‌شود (اتصال ذخیره نمی‌شود).
  Future<void> connectWith(
    FirebaseConn c, {
    required Side side,
    bool probe = true,
    RoomConfig? createRoom,
  }) async {
    _phase = AppPhase.connecting;
    _error = null;
    notifyListeners();
    try {
      final db = await _initFirebase(c);
      final repo = FirestoreRepo(db, c.roomId);
      if (probe) {
        final existing = await repo.probe();
        if (existing == null) {
          if (createRoom == null) {
            throw const ConnError('اتاقی با این کد پیدا نشد. کد دعوت را دوباره از مدیر پروژه بگیرید.');
          }
          await repo.saveRoom(createRoom, create: true);
        }
      }
      await store.setConn(c);
      await store.setDemo(false);
      await store.setSide(side);
      await store.setOnboarded(true);
      _side = side;
      if (createRoom != null) pendingInvite = true;
      _attach(repo);
    } on ConnError {
      _phase = store.conn == null ? AppPhase.setup : AppPhase.error;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'خطای غیرمنتظره: $e';
      _phase = store.conn == null ? AppPhase.setup : AppPhase.error;
      notifyListeners();
      throw ConnError(_error!);
    }
  }

  Future<FirebaseFirestore> _initFirebase(FirebaseConn c) async {
    final opts = FirebaseOptions(
      apiKey: c.apiKey,
      appId: c.appId,
      messagingSenderId: c.messagingSenderId,
      projectId: c.projectId,
    );
    // افزونهٔ Firestore همیشه به وجود اپ پیش‌فرض ([DEFAULT]) نیاز دارد؛ پس اول آن را می‌سازیم.
    FirebaseApp app;
    final hasDefault = Firebase.apps.any((a) => a.name == defaultFirebaseAppName);
    if (!hasDefault) {
      app = await Firebase.initializeApp(options: opts);
    } else {
      final def = Firebase.app();
      if (def.options.projectId == c.projectId && def.options.apiKey == c.apiKey) {
        app = def;
      } else {
        // اتصال به پروژه‌ای دیگر در همین اجرا: اپ نام‌دار جداگانه
        final name = 'taraz-${c.projectId}';
        final existing = Firebase.apps.where((a) => a.name == name).toList();
        app = existing.isNotEmpty ? existing.first : await Firebase.initializeApp(name: name, options: opts);
      }
    }
    final db = FirebaseFirestore.instanceFor(app: app);
    try {
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // تنظیمات فقط پیش از اولین استفاده قابل تغییرند؛ در اتصال مجدد نادیده می‌گیریم.
    }
    return db;
  }

  void _attach(Repo repo) {
    _detach();
    _repo = repo;
    _entriesLoaded = false;
    _sync = SyncStatus(repo.isDemo ? SyncState.demo : SyncState.connecting);
    _phase = AppPhase.ready;
    notifyListeners();

    _subRoom = repo.room().listen((c) {
      _roomExists = c != null;
      if (c != null) _config = c;
      _stats = null;
      notifyListeners();
    }, onError: _onStreamError);

    _subEntries = repo.entries().listen((snap) {
      _entries = snap.items;
      _entriesLoaded = true;
      _stats = null;
      _updateSync(snap.fromCache, snap.pendingCount);
      notifyListeners();
    }, onError: _onStreamError);

    _subSettlements = repo.settlements().listen((snap) {
      _settlements = snap.items;
      _stats = null;
      notifyListeners();
    }, onError: _onStreamError);
  }

  void _onStreamError(Object e) {
    debugPrint('stream error: $e');
    _error = e is FirebaseException ? FirestoreRepoErrors.describe(e) : e.toString();
    _sync = const SyncStatus(SyncState.offline);
    notifyListeners();
  }

  void _updateSync(bool fromCache, int pending) {
    if (_repo?.isDemo ?? false) {
      _sync = const SyncStatus(SyncState.demo);
      return;
    }
    if (pending > 0) {
      _sync = SyncStatus(SyncState.pending, pendingCount: pending, lastSynced: _sync.lastSynced);
    } else if (fromCache) {
      _sync = SyncStatus(SyncState.offline, lastSynced: _sync.lastSynced);
    } else {
      _sync = SyncStatus(SyncState.online, lastSynced: DateTime.now());
    }
  }

  void _detach() {
    _subRoom?.cancel();
    _subEntries?.cancel();
    _subSettlements?.cancel();
    _subRoom = _subEntries = _subSettlements = null;
    _repo?.dispose();
    _repo = null;
  }

  /// خروج از پروژه (اتصال و نقش محلی پاک می‌شود؛ داده‌های سرور دست‌نخورده می‌ماند).
  Future<void> disconnect() async {
    _detach();
    await store.disconnect();
    _entries = const [];
    _settlements = const [];
    _config = const RoomConfig();
    _stats = null;
    _phase = AppPhase.setup;
    notifyListeners();
  }

  // ------------------------------------------------------------------ اعمال
  Future<void> saveEntry(Entry e, {Uint8List? receipt, bool receiptChanged = false}) async {
    final r = _repo;
    if (r == null) return;
    if (!_roomExists && !r.isDemo) {
      await r.saveRoom(_config, create: true);
      _roomExists = true;
    }
    await r.upsertEntry(e, receipt: receipt, receiptChanged: receiptChanged);
  }

  Future<void> deleteEntry(String id) async {
    await _repo?.deleteEntry(id);
  }

  Future<Uint8List?> getReceipt(String id) async {
    final r = _repo;
    if (r == null) return null;
    return r.getReceipt(id);
  }

  Future<void> saveSettlement(Settlement s) async {
    await _repo?.upsertSettlement(s);
  }

  Future<void> deleteSettlement(String id) async {
    await _repo?.deleteSettlement(id);
  }

  Future<void> saveConfig(RoomConfig c) async {
    _config = c;
    _stats = null;
    notifyListeners();
    await _repo?.saveRoom(c, create: !_roomExists);
    _roomExists = true;
  }

  String newId() => _repo?.newId() ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool canEdit(Entry e) => e.side == _side;

  // -------------------------------------------------------------- تنظیمات
  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    notifyListeners();
    await store.setThemeMode(m);
  }

  Future<void> setUnit(MoneyUnit u) async {
    _unit = u;
    notifyListeners();
    await store.setUnit(u);
  }

  Future<void> setSide(Side s) async {
    _side = s;
    notifyListeners();
    await store.setSide(s);
  }

  bool get hasPin => store.hasPin;
  Future<void> setPin(String? pin) async {
    await store.setPin(pin);
    notifyListeners();
  }

  /// کد دعوت برای شرکا (شامل تنظیمات Firebase و شناسهٔ اتاق).
  String? inviteCode() => store.conn?.toInviteCode();

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}

/// پیام فارسی برای خطاهای Firestore (برای نمایش در نوار وضعیت).
class FirestoreRepoErrors {
  static String describe(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'دسترسی به پایگاه‌داده رد شد؛ قوانین Firestore را بررسی کنید.';
      case 'unavailable':
        return 'سرور در دسترس نیست؛ از دادهٔ محلی استفاده می‌شود.';
      default:
        return 'خطای پایگاه‌داده: ${e.code}';
    }
  }
}
