// ذخیرهٔ محلی تنظیمات دستگاه (نقش، اتصال، ظاهر، قفل).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fa.dart';
import 'firebase_config.dart';
import 'models.dart';

class LocalStore {
  LocalStore._(this._p);
  final SharedPreferences _p;

  static Future<LocalStore> load() async =>
      LocalStore._(await SharedPreferences.getInstance());

  static const _kConn = 'conn';
  static const _kSide = 'side';
  static const _kDemo = 'demo';
  static const _kTheme = 'theme';
  static const _kUnit = 'unit';
  static const _kPin = 'pin';
  static const _kPinSalt = 'pin_salt';
  static const _kLastSeen = 'last_seen_other';
  static const _kOnboarded = 'onboarded';
  static const _kDeviceId = 'device_id';

  // اتصال
  FirebaseConn? get conn => FirebaseConn.fromStorageString(_p.getString(_kConn));
  Future<void> setConn(FirebaseConn? c) async {
    if (c == null) {
      await _p.remove(_kConn);
    } else {
      await _p.setString(_kConn, c.toStorageString());
    }
  }

  bool get demo => _p.getBool(_kDemo) ?? false;
  Future<void> setDemo(bool v) => _p.setBool(_kDemo, v);

  /// شناسهٔ یکتای این نصب (برای تشخیص «ثبت‌شده از گوشی دیگر»).
  String get deviceId {
    var id = _p.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36) + (1000 + DateTime.now().millisecond).toString();
      _p.setString(_kDeviceId, id);
    }
    return id;
  }

  // پرداخت‌کنندهٔ پیش‌فرض در این گوشی (آخرین انتخاب)
  Side? get side {
    final s = _p.getString(_kSide);
    if (s == null) return null;
    return SideX.fromKey(s);
  }
  Future<void> setSide(Side s) => _p.setString(_kSide, s.key);

  bool get onboarded => _p.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _p.setBool(_kOnboarded, v);

  // ظاهر
  ThemeMode get themeMode => switch (_p.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode m) => _p.setString(
        _kTheme,
        switch (m) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );

  MoneyUnit get unit => MoneyUnitX.fromKey(_p.getString(_kUnit));
  Future<void> setUnit(MoneyUnit u) => _p.setString(_kUnit, u.key);

  // آخرین بازدید از فهرست (برای نشان «جدید»)
  DateTime? get lastSeenOther {
    final ms = _p.getInt(_kLastSeen);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  Future<void> setLastSeenOther(DateTime d) =>
      _p.setInt(_kLastSeen, d.millisecondsSinceEpoch);

  // قفل با رمز
  bool get hasPin => _p.getString(_kPin) != null;

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _p.remove(_kPin);
      await _p.remove(_kPinSalt);
      return;
    }
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await _p.setString(_kPinSalt, salt);
    await _p.setString(_kPin, _hash(enDigits(pin), salt));
  }

  bool checkPin(String pin) {
    final h = _p.getString(_kPin);
    final salt = _p.getString(_kPinSalt) ?? '';
    if (h == null) return true;
    return _hash(enDigits(pin), salt) == h;
  }

  /// پاک‌کردن اتصال (خروج از پروژه) — تنظیمات ظاهر می‌ماند.
  Future<void> disconnect() async {
    await _p.remove(_kConn);
    await _p.remove(_kDemo);
    await _p.remove(_kSide);
    await _p.remove(_kLastSeen);
    await _p.remove(_kOnboarded);
  }
}
